--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Units = require(Shared.Units)
local HeadlightMath = require(Shared.HeadlightMath)
local RoadBeam = require(script.Parent.RoadBeam)
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer
local projected = true
local gui = Instance.new("ScreenGui")
gui.Name = "HeadlightMode"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")
local button = Instance.new("TextButton")
button.Size = UDim2.fromOffset(228, 30)
button.Position = UDim2.new(0, 14, 1, -150)
button.BackgroundColor3 = Color3.fromRGB(18, 31, 43)
button.TextColor3 = Color3.fromRGB(125, 232, 224)
button.TextSize = 14
button.Text = "H · Headlights: road beam"
button.Parent = gui
local function toggle()
	projected = not projected
	button.Text = if projected then "H · Headlights: road beam" else "H · Headlights: native"
end
button.Activated:Connect(toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.H then
		toggle()
	end
end)
local traffic = workspace:WaitForChild("HighwayTraffic")
local elapsed = 0
type CarLights = { model: Model, body: BasePart, lights: { SpotLight } }
local carLights: { CarLights } = {}

-- Nearby traffic gets real light sources; distant cars retain visible neon lenses.
-- These local visual changes never move traffic or alter collision state.
RunService.Heartbeat:Connect(function(dt: number)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local camera = workspace.CurrentCamera
	local position = if camera then camera.CFrame.Position else Vector3.zero
	local candidates: { { light: SpotLight, distance: number } } = {}
	for _, model in traffic:GetChildren() do
		local lamp = model:FindFirstChild("TrafficHeadlight", true)
		if model:IsA("Model") and model.PrimaryPart and lamp and lamp:IsA("SpotLight") then
			table.insert(
				candidates,
				{ light = lamp, distance = (model.PrimaryPart.Position - position).Magnitude }
			)
		end
	end
	table.sort(candidates, function(a, b)
		return a.distance < b.distance
	end)
	for i, candidate in candidates do
		candidate.light.Enabled = i <= 8 and candidate.distance < 300
	end
	-- Refresh references separately from per-frame updates; never interpolate a light transform.
	table.clear(carLights)
	local vehicles = workspace:FindFirstChild("Vehicles")
	if vehicles then
		for _, model in vehicles:GetChildren() do
			if model:IsA("Model") and model.PrimaryPart then
				local lights: { SpotLight } = {}
				for _, lamp in model.PrimaryPart:GetDescendants() do
					if lamp:IsA("SpotLight") and lamp.Name == "AdaptiveHeadlight" then
						table.insert(lights, lamp)
					end
				end
				table.insert(carLights, { model = model, body = model.PrimaryPart, lights = lights })
			end
		end
	end
end)

RunService:BindToRenderStep("RedlineHeadlightRange", Enum.RenderPriority.Camera.Value + 2, function()
	RoadBeam.hide()
	for _, car in carLights do
		if not car.model.Parent or not car.body.Parent then
			continue
		end
		local speed = (car.body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local range, angle, brightness = HeadlightMath.beam(Units.kmh(speed), Config.Headlights)
		local owned = car.model:GetAttribute("OwnerId") == player.UserId
		local alive = car.model:GetAttribute("Crashed") ~= true
		if owned and alive and projected then
			RoadBeam.update(car.body, range, player.Character)
		end
		for _, light in car.lights do
			if light.Parent then
				light.Enabled = alive and not (owned and projected)
				light.Range, light.Angle, light.Brightness = range, angle, brightness
				light.Shadows = car.model:GetAttribute("OwnerId") == player.UserId
			end
		end
	end
end)
