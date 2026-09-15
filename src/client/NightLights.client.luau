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
local UI = require(script.Parent.Interface)
local function toggle()
	player:SetAttribute("HeadlightsEnabled", not player:GetAttribute("HeadlightsEnabled"))
end
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.H then
		toggle()
	end
end)
player:GetAttributeChangedSignal("HeadlightsEnabled"):Connect(function()
	UI.notify(
		if player:GetAttribute("HeadlightsEnabled")
			then "Headlights ON · speed-adaptive road visibility"
			else "Headlights OFF · press H to turn on"
	)
end)
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
	local traffic = workspace:FindFirstChild("HighwayTraffic")
	for _, model in if traffic then traffic:GetChildren() else {} do
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
		candidate.light.Enabled = player:GetAttribute("NightDriving") == true
			and i <= 6
			and candidate.distance < 300
	end
	-- Refresh references separately from per-frame updates; never interpolate a light transform.
	table.clear(carLights)
	for _, folderName in { "Vehicles", "TownTraffic", "PolicePatrols" } do
		local vehicles = workspace:FindFirstChild(folderName)
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
	end
	table.sort(carLights, function(a, b)
		return (a.body.Position - position).Magnitude < (b.body.Position - position).Magnitude
	end)
end)

RunService:BindToRenderStep("RedlineHeadlightRange", Enum.RenderPriority.Camera.Value + 2, function()
	local projected = player:GetAttribute("NativeHeadlights") ~= true
	RoadBeam.hide()
	for i, car in carLights do
		if not car.model.Parent or not car.body.Parent then
			continue
		end
		local speed = (car.body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		local range, angle, brightness = HeadlightMath.beam(Units.kmh(speed), Config.Headlights)
		local owned = car.model:GetAttribute("OwnerId") == player.UserId
		local alive = car.model:GetAttribute("Crashed") ~= true
			and (if owned
				then player:GetAttribute("HeadlightsEnabled") == true
				else player:GetAttribute("NightDriving") == true)
			and (
				owned
				or (
					i <= 5
					and workspace.CurrentCamera ~= nil
					and (car.body.Position - (workspace.CurrentCamera :: Camera).CFrame.Position).Magnitude
						< 220
				)
			)
		if
			owned
			and alive
			and projected
			and workspace.CurrentCamera
			and (car.body.Position - workspace.CurrentCamera.CFrame.Position).Magnitude < 250
		then
			RoadBeam.update(car.body, HeadlightMath.roadReach(speed, Config.Headlights), player.Character)
		end
		for _, light in car.lights do
			if light.Parent then
				light.Enabled = alive -- Native lights illuminate nearby vehicles; the overlay extends road visibility.
				light.Range, light.Angle, light.Brightness = range, angle, brightness
				light.Shadows = false
			end
		end
	end
end)
