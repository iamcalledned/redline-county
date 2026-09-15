--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Units = require(game:GetService("ReplicatedStorage").Shared.Units)
local player = Players.LocalPlayer
local UI = require(script.Parent.Interface)
local alert = UI.Alert
local elapsed = 0
local previousDistance = math.huge
local previousCar: Model? = nil
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < 0.2 then
		return
	end
	elapsed = 0
	local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		alert.Text = ""
		return
	end
	local nearest: Model? = nil
	local distance = 350
	local pursuit = false
	for _, name in { "TownTraffic", "PolicePatrols" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") and model.PrimaryPart and model:GetAttribute("Police") then
					local gap = (root.Position - model.PrimaryPart.Position).Magnitude
					local chasing = model:GetAttribute("TargetUserId") == player.UserId
					if
						gap < 350 and ((chasing and not pursuit) or (chasing == pursuit and gap < distance))
					then
						pursuit = chasing
						distance = gap
						nearest = model
					end
				end
			end
		end
	end
	if not nearest then
		alert.Text = ""
	end
	if nearest and nearest.PrimaryPart then
		local localPoint = root.CFrame:PointToObjectSpace(nearest.PrimaryPart.Position)
		local direction = if math.abs(localPoint.X) > math.abs(localPoint.Z)
			then (if localPoint.X < 0 then "LEFT" else "RIGHT")
			else (if localPoint.Z < 0 then "AHEAD" else "BEHIND")
		local chasing = nearest:GetAttribute("TargetUserId") == player.UserId
		local closing = nearest == previousCar and distance < previousDistance - 1
		alert.BackgroundColor3 = if chasing and distance < 90
			then Color3.fromRGB(163, 35, 43)
			elseif chasing then Color3.fromRGB(155, 86, 28)
			else Color3.fromRGB(27, 54, 81)
		alert.BackgroundTransparency = if chasing
				and distance < 90
				and not player:GetAttribute("ReducedFlashing")
			then (if math.floor(os.clock() * 4) % 2 == 0 then 0.05 else 0.3)
			else 0.12
		alert.Text = string.format(
			"%s · %d m · %s%s",
			if chasing
				then "HEAT " .. tostring(player:GetAttribute("Wanted") or 1) .. " · POLICE"
				else "PATROL NEARBY",
			math.floor(Units.kilometres(distance) * 1000),
			direction,
			if closing then " · CLOSING" else ""
		)
		local bust = (player:GetAttribute("MissionBusted") :: number?) or 0
		if chasing and bust > 0 then
			alert.Text ..= string.format(" · BUST IN %.1f s", math.max(0, 5 - bust))
		end
	end
	previousDistance = distance
	previousCar = nearest
end)
