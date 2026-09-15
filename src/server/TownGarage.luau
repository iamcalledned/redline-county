--!strict
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Map = require(ReplicatedStorage.Shared.TownMap)
local Rules = require(ReplicatedStorage.Shared.GarageRules)
local Finish = require(script.Parent.VehicleFinish)
local Garage = {}
Garage.Center = Map.Garage + Vector3.new(0, 0, 8 / 0.28)
local home = workspace:WaitForChild("HopedaleLandmarks"):WaitForChild("HomeBase")
local owners: { [number]: Player } = {}
local bays: { [Player]: number } = {}
local open: { [number]: boolean } = {}
local busy: { [number]: boolean } = {}
local selection: ((Player, string) -> ())? = nil
local openers: { [number]: (Player) -> () } = {}
function Garage.openFor(player: Player)
	local bay = bays[player]
	if bay and openers[bay] and not open[bay] and not busy[bay] then
		openers[bay](player)
	end
end
local offsets = { -27, 0, 27 }
local kinds = { "Pickup", "Electric", "Sport" }
for i, kind in kinds do
	local display = home:FindFirstChild("Display_" .. kind)
	if display and display:IsA("Model") then
		Finish.prepare(display, false)
		Finish.apply(
			display,
			"Paint",
			({ Color3.fromRGB(79, 100, 87), Color3.fromRGB(199, 201, 190), Color3.fromRGB(133, 44, 38) })[i]
		)
		for _, part in display:GetDescendants() do
			if part:IsA("BasePart") then
				part:SetAttribute("DisplayTransparency", part.Transparency)
			end
		end
	end
end
local function root(player: Player): BasePart?
	return if player.Character then player.Character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end
function Garage.claim(player: Player): number?
	if bays[player] then
		return bays[player]
	end
	for i = 1, 3 do
		if not owners[i] then
			owners[i], bays[player] = player, i
			player:SetAttribute("HomeBay", i)
			return i
		end
	end
	return nil
end
function Garage.spawnPoint(player: Player): CFrame
	local bay = Garage.claim(player) or 3
	return (home:WaitForChild("Arrival_" .. bay) :: BasePart).CFrame
end
function Garage.pad(player: Player, exclude: Model?): CFrame?
	local bay = Garage.claim(player)
	if not bay then
		return nil
	end
	local cf = CFrame.new(Garage.Center + Vector3.new(offsets[bay], 3, 2))
	local params = OverlapParams.new()
	local ignore: { Instance } = { home }
	if exclude then
		table.insert(ignore, exclude)
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	for _, part in workspace:GetPartBoundsInBox(cf, Vector3.new(12, 10, 24), params) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and (model:GetAttribute("OwnerId") ~= nil or Players:GetPlayerFromCharacter(model)) then
			return nil
		end
	end
	return cf
end
function Garage.hideDisplay(player: Player, hide: boolean)
	local bay = bays[player]
	if not bay then
		return
	end
	local display = home:FindFirstChild("Display_" .. kinds[bay])
	if display then
		for _, item in display:GetDescendants() do
			if item:IsA("BasePart") then
				item.Transparency = if hide
					then 1
					else (item:GetAttribute("DisplayTransparency") :: number?) or 0
				item.CanCollide = not hide and item.Name == "Body"
				item.CanQuery = item.CanCollide
			elseif item:IsA("SurfaceGui") then
				item.Enabled = not hide
			end
		end
	end
	local marker = home:FindFirstChild("Select_" .. kinds[bay])
	local prompt = if marker then marker:FindFirstChildOfClass("ProximityPrompt") else nil
	if prompt then
		prompt.Enabled = not hide
	end
end
function Garage.bind(callback: (Player, string) -> ())
	selection = callback
end
for i, x in offsets do
	local door = home:WaitForChild("Door_" .. x) :: BasePart
	local closed = door.CFrame
	local button = home:WaitForChild("DoorButton_" .. x) :: BasePart
	-- Decorative ribs follow the panel, not the stationary wall.
	local ribs: { { part: BasePart, rest: CFrame } } = {}
	for _, part in home:GetChildren() do
		if part:IsA("BasePart") and part.Name == "DoorWindow_" .. x then
			table.insert(ribs, { part = part, rest = part.CFrame })
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Open / close", "Garage door · bay " .. i
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 14
	prompt.Parent = button
	local function operate(player: Player, launch: boolean?)
		local r = root(player)
		if not r or busy[i] then
			return
		end
		local blocked = false
		if open[i] then
			local params = OverlapParams.new()
			params.FilterDescendantsInstances = { home }
			for _, part in workspace:GetPartBoundsInBox(closed, Vector3.new(25, 19, 7), params) do
				local ancestor = part:FindFirstAncestorOfClass("Model")
				if
					ancestor
					and (ancestor:GetAttribute("OwnerId") ~= nil or Players:GetPlayerFromCharacter(ancestor))
				then
					blocked = true
					break
				end
			end
		end
		local owner = owners[i]
		if
			not Rules.canUseDoor(
				if owner then owner.UserId else nil,
				player.UserId,
				if launch
						and bays[player] == i
						and (r.Position - Garage.Center).Magnitude < 85
					then 0
					else (r.Position - button.Position).Magnitude,
				blocked
			)
		then
			return
		end
		busy[i] = true
		open[i] = not open[i]
		-- Disable collision throughout motion to avoid pushing a car if it enters mid-close.
		door.CanCollide = false
		local target = if open[i] then closed + Vector3.new(0, 19, 0) else closed
		local tween = TweenService:Create(door, TweenInfo.new(1.5), { CFrame = target })
		for _, rib in ribs do
			TweenService:Create(
				rib.part,
				TweenInfo.new(1.5),
				{ CFrame = if open[i] then rib.rest + Vector3.new(0, 19, 0) else rib.rest }
			):Play()
		end
		tween:Play()
		tween.Completed:Once(function()
			if not open[i] then
				-- Recheck before making a closed door solid; reopen when anything entered during travel.
				local params = OverlapParams.new()
				params.FilterDescendantsInstances = { home }
				for _, part in workspace:GetPartBoundsInBox(closed, Vector3.new(25, 19, 7), params) do
					local a = part:FindFirstAncestorOfClass("Model")
					if a and (a:GetAttribute("OwnerId") ~= nil or Players:GetPlayerFromCharacter(a)) then
						open[i] = true
						door.CFrame = closed + Vector3.new(0, 19, 0)
						for _, rib in ribs do
							rib.part.CFrame = rib.rest + Vector3.new(0, 19, 0)
						end
						break
					end
				end
			end
			door.CanCollide = not open[i]
			busy[i] = false
		end)
	end
	openers[i] = function(player: Player)
		operate(player, true)
	end
	prompt.Triggered:Connect(function(player: Player)
		operate(player, false)
	end)
end
for _, kind in kinds do
	local marker = home:WaitForChild("Select_" .. kind) :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Select vehicle", kind .. " · free starter"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance, prompt.RequiresLineOfSight = 12, false
	prompt.Parent = marker
	prompt.Triggered:Connect(function(player: Player)
		local r = root(player)
		local callback = selection
		if r and callback and (r.Position - marker.Position).Magnitude <= 14 then
			callback(player, kind)
		end
	end)
end
Players.PlayerRemoving:Connect(function(player: Player)
	Garage.hideDisplay(player, false)
	local bay = bays[player]
	if bay then
		owners[bay] = nil
		bays[player] = nil
	end
end)
return Garage
