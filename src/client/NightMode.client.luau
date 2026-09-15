--!strict
local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local player = Players.LocalPlayer
local night = true
local highwayLocked = false
local UI = require(script.Parent.Interface)
local function toggle()
	if not highwayLocked then
		player:SetAttribute("NightPreference", not player:GetAttribute("NightPreference"))
		UI.notify(if player:GetAttribute("NightPreference") then "Night driving ON" else "Day driving ON")
	else
		UI.notify("The Autobahn uses night driving. Return to town to switch to daylight.")
	end
end
Input.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.N then
		toggle()
	end
end)
local elapsed = 0
local previous: boolean? = nil
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
	local highway = root and root:IsA("BasePart") and math.abs(root.Position.X - Config.Highway.X) < 300
	highwayLocked = highway == true
	night = player:GetAttribute("NightPreference") == true
	local enabled = night or highwayLocked
	if previous == enabled then
		return
	end
	previous = enabled
	player:SetAttribute("NightDriving", enabled)
	Lighting.ClockTime = if enabled then 0.5 else 16
	Lighting.Ambient = if enabled then Color3.fromRGB(36, 43, 61) else Color3.fromRGB(90, 92, 94)
	Lighting.OutdoorAmbient = if enabled then Color3.fromRGB(53, 62, 80) else Color3.fromRGB(127, 130, 132)
	Lighting.ExposureCompensation = if enabled then 0.05 else 0.1
end)

local lamps: { [PointLight]: boolean } = {}
local function inspect(item: Instance)
	if item:IsA("PointLight") and item.Name == "MapLamp" then
		lamps[item] = true
	end
end
local map = workspace:WaitForChild("HopedaleGenerated")
for _, item in map:GetDescendants() do
	inspect(item)
end
map.DescendantAdded:Connect(inspect)
local lampClock = 0
RunService.Heartbeat:Connect(function(dt)
	lampClock += dt
	if lampClock < 0.5 then
		return
	end
	lampClock = 0
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local ranked: { { lamp: PointLight, distance: number } } = {}
	for lamp in lamps do
		local parent = lamp.Parent
		if not parent then
			lamps[lamp] = nil
		elseif parent:IsA("BasePart") then
			table.insert(
				ranked,
				{ lamp = lamp, distance = (parent.Position - camera.CFrame.Position).Magnitude }
			)
		end
	end
	table.sort(ranked, function(a, b)
		return a.distance < b.distance
	end)
	for i, entry in ranked do
		entry.lamp.Enabled = player:GetAttribute("NightDriving") == true and i <= 6 and entry.distance < 230
	end
end)
