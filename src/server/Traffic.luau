--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local TrafficMath = require(ReplicatedStorage.Shared.TrafficMath)
local HighwayMath = require(ReplicatedStorage.Shared.HighwayMath)
local CrashMath = require(ReplicatedStorage.Shared.CrashMath)
local Traffic = {}
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "HighwayTraffic", workspace
local epoch = workspace:GetServerTimeNow()
folder:SetAttribute("Epoch", epoch)
local models: { [number]: Model } = {}
local colors = {
	Color3.fromRGB(224, 170, 77),
	Color3.fromRGB(87, 150, 192),
	Color3.fromRGB(225, 229, 215),
	Color3.fromRGB(182, 72, 76),
}

local function build(id: number, lane: number, slot: number): Model
	local model = Instance.new("Model")
	model.Name = "Traffic_" .. id
	model:SetAttribute("Lane", lane)
	model:SetAttribute("Slot", slot)
	local function part(name: string, size: Vector3, cf: CFrame, color: Color3): Part
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
		p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Parent = model
		return p
	end
	local body = part("Body", Vector3.new(5.4, 1.4, 10), CFrame.new(), colors[id % #colors + 1])
	body.Size = Vector3.new(5.8, 3, 10)
	body.Transparency = 1
	body.CanCollide, body.CanQuery = true, true
	body.CollisionGroup = "Traffic"
	part("Paint", Vector3.new(5.4, 1.4, 10), CFrame.new(), colors[id % #colors + 1])
	model.PrimaryPart = body
	part("Cabin", Vector3.new(4.4, 1.6, 4.5), CFrame.new(0, 1.5, 0.5), Color3.fromRGB(42, 61, 77))
	for _, x in { -2.8, 2.8 } do
		for _, z in { -3.2, 3.2 } do
			part("Wheel", Vector3.new(0.7, 2, 2), CFrame.new(x, -0.7, z), Color3.fromRGB(21, 25, 31)).Shape =
				Enum.PartType.Cylinder
		end
	end
	for _, x in { -1.8, 1.8 } do
		local lens =
			part("Headlamp", Vector3.new(1, 0.4, 0.2), CFrame.new(x, 0, -5.1), Color3.fromRGB(255, 236, 189))
		lens.Material = Enum.Material.Neon
		if x < 0 then
			local beam = Instance.new("SpotLight")
			beam.Name, beam.Face = "TrafficHeadlight", Enum.NormalId.Front
			beam.Range, beam.Angle, beam.Brightness = 50, 65, 1.5
			beam.Color, beam.Shadows, beam.Enabled = lens.Color, false, false
			beam.Parent = lens
		end
		part("TailLamp", Vector3.new(1, 0.4, 0.2), CFrame.new(x, 0, 5.1), Color3.fromRGB(255, 73, 86)).Material =
			Enum.Material.Neon
	end
	return model
end

function Traffic.update(needed: { [number]: boolean })
	local H = Config.Highway
	local elapsed = workspace:GetServerTimeNow() - epoch
	for lane = 1, 6 do
		for slot = 0, Config.TrafficPerLane - 1 do
			local id = (lane - 1) * Config.TrafficPerLane + slot
			local x, z, direction =
				TrafficMath.position(lane, slot, elapsed, H.HalfLength, Config.TrafficPerLane)
			local model = models[id]
			if needed[math.floor(-z / H.ChunkLength)] then
				if not model then
					model = build(id, lane, slot)
					models[id] = model
				end
				model:PivotTo(
					CFrame.new(H.X + x, H.Y + 1.8, z)
						* CFrame.Angles(0, if direction > 0 then math.pi else 0, 0)
				)
				model.Parent = folder
			elseif model then
				model:Destroy()
				models[id] = nil
			end
		end
	end
	folder:SetAttribute("ActiveCars", #folder:GetChildren())
end

function Traffic.move()
	local H = Config.Highway
	local elapsed = workspace:GetServerTimeNow() - epoch
	for _, model in models do
		local lane, slot = model:GetAttribute("Lane") :: number, model:GetAttribute("Slot") :: number
		local x, z, direction = TrafficMath.position(lane, slot, elapsed, H.HalfLength, Config.TrafficPerLane)
		model:PivotTo(
			CFrame.new(H.X + x, H.Y + 1.8, z) * CFrame.Angles(0, if direction > 0 then math.pi else 0, 0)
		)
	end
end

function Traffic.contact(body: BasePart, previous: CFrame?, previousTime: number, now: number): number?
	local current = body.CFrame
	local before = previous or current
	if (current.Position - before.Position).Magnitude > 500 then
		return nil
	end
	local H = Config.Highway
	local axes = { Vector3.xAxis, Vector3.zAxis, current.RightVector, current.LookVector, Vector3.yAxis }
	local earliest: number? = nil
	for _, model in models do
		local lane, slot = model:GetAttribute("Lane") :: number, model:GetAttribute("Slot") :: number
		local x, z =
			TrafficMath.position(lane, slot, previousTime - epoch, H.HalfLength, Config.TrafficPerLane)
		local _, endZ = TrafficMath.position(lane, slot, now - epoch, H.HalfLength, Config.TrafficPerLane)
		-- Unwrap relative movement; the space-recycling teleport is not a collision sweep.
		local trafficStartZ = before.Position.Z + HighwayMath.wrap(z - before.Position.Z, H.HalfLength)
		local trafficEndZ = trafficStartZ + HighwayMath.wrap(endZ - z, H.HalfLength)
		local start = before.Position - Vector3.new(H.X + x, H.Y + 1.8, trafficStartZ)
		local finish = current.Position - Vector3.new(H.X + x, H.Y + 1.8, trafficEndZ)
		local a, b, extents = {}, {}, {}
		for _, axis in axes do
			table.insert(a, start:Dot(axis))
			table.insert(b, finish:Dot(axis))
			local carHalf = math.abs(axis:Dot(current.RightVector)) * body.Size.X / 2
				+ math.abs(axis:Dot(current.UpVector)) * body.Size.Y / 2
				+ math.abs(axis:Dot(current.LookVector)) * body.Size.Z / 2
			local trafficHalf = math.abs(axis.X) * 2.9 + math.abs(axis.Y) * 1.5 + math.abs(axis.Z) * 5
			table.insert(extents, carHalf + trafficHalf + Config.Crash.ContactMargin)
		end
		local hit = CrashMath.sweep(a, b, extents)
		if hit and (not earliest or hit < earliest) then
			earliest = hit
		end
	end
	return earliest
end

return Traffic
