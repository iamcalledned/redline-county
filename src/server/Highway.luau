--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local HighwayMath = require(ReplicatedStorage.Shared.HighwayMath)
local Driving = require(ReplicatedStorage.Shared.Driving)
local Traffic = require(script.Parent.Traffic)
local H = Config.Highway
local Highway = {}
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "Autobahn", workspace
local chunks: { [number]: Model } = {}
local clock = 0

local function part(
	model: Model,
	name: string,
	size: Vector3,
	position: Vector3,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color = name, size, position, color
	p.Anchored = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

local function downlight(lamp: BasePart)
	local light = Instance.new("SurfaceLight")
	light.Face, light.Range, light.Angle, light.Brightness = Enum.NormalId.Bottom, 60, 140, 1.8
	light.Color, light.Shadows, light.Parent = Color3.fromRGB(255, 214, 158), false, lamp
end

local function build(index: number)
	if chunks[index] then
		return
	end
	local model = Instance.new("Model")
	model.Name = "Section_" .. index
	local z = -(index + 0.5) * H.ChunkLength
	local road = Color3.fromRGB(39, 46, 57)
	local white = Color3.fromRGB(232, 233, 211)
	local variant = index % 4
	part(
		model,
		"Verge",
		Vector3.new(460, 8, H.ChunkLength),
		Vector3.new(H.X, H.Y - 4.5, z),
		if variant == 1 then Color3.fromRGB(157, 151, 116) else Color3.fromRGB(91, 120, 91),
		Enum.Material.Grass
	)
	part(
		model,
		"Road",
		Vector3.new(132, 1, H.ChunkLength),
		Vector3.new(H.X, H.Y - 0.5, z),
		road,
		Enum.Material.Asphalt
	)
	part(
		model,
		"Median",
		Vector3.new(5, 3, H.ChunkLength),
		Vector3.new(H.X, H.Y + 1.5, z),
		Color3.fromRGB(120, 137, 144)
	)
	for _, x in { -66, 66 } do
		if x == 66 and index == 0 then
			-- Real opening for the acceleration lane; all other guardrail sections remain intact.
			part(
				model,
				"Guardrail",
				Vector3.new(1, 3, 240),
				Vector3.new(H.X + x, H.Y + 1.5, -120),
				Color3.fromRGB(150, 174, 181)
			)
			part(
				model,
				"Guardrail",
				Vector3.new(1, 3, 92),
				Vector3.new(H.X + x, H.Y + 1.5, -466),
				Color3.fromRGB(150, 174, 181)
			)
		else
			part(
				model,
				"Guardrail",
				Vector3.new(1, 3, H.ChunkLength),
				Vector3.new(H.X + x, H.Y + 1.5, z),
				Color3.fromRGB(150, 174, 181)
			)
		end
	end
	for _, x in { -59, -7, 7, 59 } do
		part(
			model,
			"EdgeLine",
			Vector3.new(0.4, 0.04, H.ChunkLength),
			Vector3.new(H.X + x, H.Y + 0.025, z),
			white
		).CanCollide =
			false
	end
	for offset = 16, H.ChunkLength - 1, 64 do
		for _, x in { -60, 60 } do
			local reflector = part(
				model,
				"RoadReflector",
				Vector3.new(0.4, 0.6, 1.2),
				Vector3.new(H.X + x, H.Y + 0.4, -index * H.ChunkLength - offset),
				Color3.fromRGB(234, 222, 184),
				Enum.Material.Neon
			)
			reflector.CanCollide = false
		end
		for _, x in { -24, -42, 24, 42 } do
			part(
				model,
				"LaneDash",
				Vector3.new(0.4, 0.04, 28),
				Vector3.new(H.X + x, H.Y + 0.025, -index * H.ChunkLength - offset),
				white
			).CanCollide =
				false
		end
	end
	for _, x in { -88, if index == 0 then 148 else 88 } do
		part(
			model,
			"LampPost",
			Vector3.new(1, 26, 1),
			Vector3.new(H.X + x, H.Y + 13, z),
			Color3.fromRGB(67, 85, 99)
		)
		local lamp = part(
			model,
			"Lamp",
			Vector3.new(12, 0.4, 2),
			Vector3.new(H.X + x, H.Y + 26, z),
			Color3.fromRGB(255, 206, 133),
			Enum.Material.Neon
		)
		downlight(lamp)
		if variant == 2 then
			part(
				model,
				"Factory",
				Vector3.new(60, 35, 100),
				Vector3.new(H.X + x * 2, H.Y + 17, z),
				Color3.fromRGB(83, 102, 125)
			)
		else
			part(
				model,
				"Hill",
				Vector3.new(80, 45, 180),
				Vector3.new(H.X + x * 2, H.Y + 3, z),
				Color3.fromRGB(63, 94, 88)
			).Shape =
				Enum.PartType.Ball
		end
	end
	-- Gantries mark the repeating landscape without pretending physical coordinates are trip distance.
	local board = part(
		model,
		"AutobahnSign",
		Vector3.new(48, 9, 1),
		Vector3.new(H.X + 33, H.Y + 20, z),
		Color3.fromRGB(30, 85, 159)
	)
	part(
		model,
		"Gantry",
		Vector3.new(1, 25, 1),
		Vector3.new(H.X + 62, H.Y + 12, z),
		Color3.fromRGB(131, 152, 168)
	)
	local gui = Instance.new("SurfaceGui")
	gui.Face, gui.PixelsPerStud = Enum.NormalId.Back, 24
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	label.Text = "A1  /  REDLINE AUTOBAHN\nKEEP RIGHT  •  PASS LEFT"
	label.TextColor3, label.Font, label.TextScaled = white, Enum.Font.GothamBold, true
	label.Parent = gui
	model.Parent = folder
	chunks[index] = model
end

function Highway.prepare(z: number)
	for index in HighwayMath.needed({ z }, H.ChunkLength, H.LoadRadius, H.HalfLength) do
		build(index)
	end
end

function Highway.entry(): CFrame
	Highway.prepare(Config.Ramp.StartZ)
	if not folder:FindFirstChild("OnRamp") then
		local ramp = Instance.new("Model")
		ramp.Name = "OnRamp"
		local asphalt = Color3.fromRGB(50, 62, 72)
		part(
			ramp,
			"AccelerationLane",
			Vector3.new(30, 1, 640),
			Vector3.new(H.X + Config.Ramp.XOffset, H.Y - 0.5, 192),
			asphalt,
			Enum.Material.Asphalt
		)
		for _, x in { 78, 130 } do
			part(
				ramp,
				"RampBarrier",
				Vector3.new(1.5, 3, 640),
				Vector3.new(H.X + x, H.Y + 1.5, 192),
				Color3.fromRGB(150, 174, 181)
			)
		end
		local from = Vector3.new(H.X + Config.Ramp.XOffset, H.Y - 0.5, -120)
		local to = Vector3.new(H.X + 59, H.Y - 0.5, -352)
		local merge = part(
			ramp,
			"MergeLane",
			Vector3.new(26, 1, (to - from).Magnitude + 12),
			(from + to) / 2,
			asphalt,
			Enum.Material.Asphalt
		)
		merge.CFrame = CFrame.lookAt((from + to) / 2, to)
		for z = -80, 460, 60 do
			part(
				ramp,
				"RampCenterDash",
				Vector3.new(0.5, 0.04, 20),
				Vector3.new(H.X + Config.Ramp.XOffset, H.Y + 0.025, z),
				Color3.fromRGB(255, 217, 121)
			).CanCollide =
				false
		end
		for _, z in { 0, 192, 384 } do
			part(
				ramp,
				"RampLightPost",
				Vector3.new(1, 24, 1),
				Vector3.new(H.X + 132, H.Y + 12, z),
				Color3.fromRGB(98, 121, 138)
			)
			local lamp = part(
				ramp,
				"RampLamp",
				Vector3.new(12, 0.5, 3),
				Vector3.new(H.X + 124, H.Y + 24, z),
				Color3.fromRGB(255, 214, 158),
				Enum.Material.Neon
			)
			downlight(lamp)
		end
		local board = part(
			ramp,
			"MergeSign",
			Vector3.new(30, 7, 1),
			Vector3.new(H.X + Config.Ramp.XOffset, H.Y + 13, -80),
			Color3.fromRGB(32, 96, 160)
		)
		local gui = Instance.new("SurfaceGui")
		gui.Face, gui.Parent = Enum.NormalId.Back, board
		local label = Instance.new("TextLabel")
		label.Size, label.BackgroundTransparency = UDim2.fromScale(1, 1), 1
		label.Text, label.TextScaled, label.Font = "A1 AUTOBAHN\nMERGE LEFT AHEAD", true, Enum.Font.GothamBold
		label.TextColor3, label.Parent = Color3.new(1, 1, 1), gui
		ramp.Parent = folder
	end
	return CFrame.new(H.X + Config.Ramp.XOffset, H.Y + 3, Config.Ramp.StartZ)
end

function Highway.wrapCar(model: Model, body: BasePart)
	local z = body.Position.Z
	local wrapped = HighwayMath.wrap(z, H.HalfLength)
	if math.abs(wrapped - z) < 0.01 then
		return
	end
	Highway.prepare(wrapped)
	local linear, angular = body.AssemblyLinearVelocity, body.AssemblyAngularVelocity
	model:PivotTo(model:GetPivot() + Vector3.new(0, 0, wrapped - z))
	body.AssemblyLinearVelocity, body.AssemblyAngularVelocity = linear, angular
	-- Lets the local chase camera apply the same translation rather than lerp across the world.
	model:SetAttribute("HighwayWraps", ((model:GetAttribute("HighwayWraps") :: number?) or 0) + 1)
end

function Highway.update(dt: number, vehicles: Instance)
	clock += dt
	if clock < H.UpdateSeconds then
		return
	end
	clock = 0
	local positions = {}
	for _, model in vehicles:GetChildren() do
		if
			model:IsA("Model")
			and model:GetAttribute("Highway")
			and model.PrimaryPart
			and Driving.finite(model.PrimaryPart.Position.Z)
		then
			table.insert(positions, model.PrimaryPart.Position.Z)
		end
	end
	-- Keep road underneath passengers/drivers who get out of a car, too.
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
		if root and math.abs(root.Position.X - H.X) < 300 and Driving.finite(root.Position.Z) then
			local wrapped = HighwayMath.wrap(root.Position.Z, H.HalfLength)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if humanoid and not humanoid.SeatPart and math.abs(wrapped - root.Position.Z) > 0.01 then
				Highway.prepare(wrapped)
				character:PivotTo(character:GetPivot() + Vector3.new(0, 0, wrapped - root.Position.Z))
			end
			table.insert(positions, wrapped)
		end
	end
	local needed = HighwayMath.needed(positions, H.ChunkLength, H.LoadRadius, H.HalfLength)
	for index in needed do
		build(index)
	end
	for index, model in chunks do
		if not needed[index] then
			model:Destroy()
			chunks[index] = nil
		end
	end
	Traffic.update(needed)
	local count = 0
	for _ in chunks do
		count += 1
	end
	folder:SetAttribute("LoadedSections", count)
end

return Highway
