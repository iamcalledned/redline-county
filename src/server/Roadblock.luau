--!strict
-- One announced, half-width parkway barrier per heat run. No instant contact spawns.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Map = require(Shared.TownMap)
local Math = require(Shared.TownTrafficMath)
local points = {}
for _, p in Map.Course do
	table.insert(points, { x = p.X, z = p.Z })
end
local route = Math.route(points, false)
local Roadblock = {}
export type Block = { model: Model, position: Vector3, expires: number }
local function clearForAll(position: Vector3): boolean
	for _, player in Players:GetPlayers() do
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and (root.Position - position).Magnitude < 500 then
			return false
		end
	end
	local params = OverlapParams.new()
	params.RespectCanCollide = true
	return #workspace:GetPartBoundsInBox(
		CFrame.new(position + Vector3.new(0, 3, 0)),
		Vector3.new(24, 4, 24),
		params
	) == 0
end
function Roadblock.deploy(owner: Player, last: Vector3, velocity: Vector3): Block?
	local progress = Math.project(route, { x = last.X, z = last.Z })
	local here = Math.sample(route, progress)
	if Vector2.new(last.X - here.x, last.Z - here.z).Magnitude > 65 then
		return nil
	end
	local q = Math.sample(route, progress + 20)
	local sign = if Vector3.new(q.x - here.x, 0, q.z - here.z):Dot(velocity) >= 0 then 1 else -1
	local along = progress + sign * math.max(800, math.min(1500, velocity.Magnitude * 6))
	local p, ahead = Math.sample(route, along), Math.sample(route, along + sign * 10)
	local position = Vector3.new(p.x, 32, p.z)
	if not clearForAll(position) then
		return nil
	end
	-- Stay in one lane. More than 5 m of the 12 m road remains open on the opposite side.
	local cf = CFrame.lookAt(position, Vector3.new(ahead.x, 32, ahead.z))
	local model = Instance.new("Model")
	model.Name = "AnnouncedRoadblock"
	local barrier = Instance.new("Part")
	barrier.Name = "Barrier"
	barrier.Anchored = true
	barrier.Size = Vector3.new(13, 3, 2)
	barrier.CFrame = cf * CFrame.new(0, 1.5, 0)
	barrier.Material = Enum.Material.Metal
	barrier.Color = Color3.fromRGB(224, 174, 53)
	barrier.Parent = model
	for _, x in { -5, 5 } do
		local lamp = Instance.new("Part")
		lamp.Name = "Beacon"
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.CanTouch = false
		lamp.CanQuery = false
		lamp.Material = Enum.Material.Neon
		lamp.Color = Color3.fromRGB(235, 142, 40)
		lamp.Size = Vector3.new(1, 1, 1)
		lamp.CFrame = cf * CFrame.new(x, 3.5, 0)
		lamp.Parent = model
	end
	model.Parent = workspace
	owner:SetAttribute("RoadblockPosition", position)
	owner:SetAttribute(
		"MissionMessage",
		"DISPATCH · Roadblock ahead on the parkway. Opposite lane or town exit remains open."
	)
	return { model = model, position = position, expires = os.clock() + 55 }
end
function Roadblock.clear(owner: Player, block: Block?)
	if block then
		block.model:Destroy()
	end
	owner:SetAttribute("RoadblockPosition", nil)
end
return Roadblock
