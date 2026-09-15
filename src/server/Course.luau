--!strict
local Course = {}
Course.Garage = Vector3.new(0, 0, 82)
Course.Pads = { CFrame.new(-36, 4, 60), CFrame.new(-12, 4, 60), CFrame.new(12, 4, 60), CFrame.new(36, 4, 60) }

local function part(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(parent: Instance, title: string, subtitle: string, cf: CFrame, width: number)
	local board = part(parent, title, Vector3.new(width, 9, 1), cf, Color3.fromRGB(18, 28, 42))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = title .. "\n" .. subtitle
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(255, 180, 127)
	label.TextScaled = true
	label.Parent = gui
end

function Course.build(): Model
	local model = Instance.new("Model")
	model.Name = "HandlingCourse"
	model.Parent = workspace
	local asphalt = Color3.fromRGB(44, 53, 65)
	part(
		model,
		"CoastalShelf",
		Vector3.new(1600, 8, 1600),
		CFrame.new(0, -4.6, -210),
		Color3.fromRGB(149, 141, 114),
		Enum.Material.Sand
	)
	local ocean = part(
		model,
		"Ocean",
		Vector3.new(2200, 1, 2200),
		CFrame.new(0, -10, -200),
		Color3.fromRGB(32, 126, 157),
		Enum.Material.SmoothPlastic
	)
	ocean.CanCollide, ocean.CanQuery = false, false
	part(
		model,
		"HandlingPad",
		Vector3.new(510, 1, 620),
		CFrame.new(0, -0.5, -200),
		asphalt,
		Enum.Material.Asphalt
	)
	part(model, "GarageApron", Vector3.new(140, 1, 85), CFrame.new(0, 0, 83), Color3.fromRGB(57, 77, 87))
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "GarageSpawn"
	spawn.Size, spawn.CFrame = Vector3.new(12, 1, 10), CFrame.new(0, 1, 105)
	spawn.Anchored, spawn.Neutral = true, true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(84, 219, 206)
	spawn.Parent = model
	sign(model, "REDLINE COUNTY", "GARAGE / HANDLING LAB", CFrame.new(0, 13, 124), 64)
	part(
		model,
		"NeonHeader",
		Vector3.new(64, 0.5, 1.2),
		CFrame.new(0, 18, 124),
		Color3.fromRGB(255, 95, 126),
		Enum.Material.Neon
	)
	for i, pad in Course.Pads do
		part(
			model,
			"Bay" .. i,
			Vector3.new(15, 0.15, 24),
			CFrame.new(pad.Position.X, 0.58, pad.Position.Z),
			Color3.fromRGB(77, 112, 119)
		)
	end
	-- Wide rectangular loop with escape room; central infield is deliberately open.
	for _, x in { -210, 210 } do
		for z = -460, 30, 25 do
			part(
				model,
				"LaneDash",
				Vector3.new(0.6, 0.08, 11),
				CFrame.new(x, 0.06, z),
				Color3.fromRGB(239, 216, 160)
			)
		end
	end
	for _, z in { -470, 20 } do
		for x = -180, 180, 25 do
			part(
				model,
				"LaneDash",
				Vector3.new(11, 0.08, 0.6),
				CFrame.new(x, 0.06, z),
				Color3.fromRGB(239, 216, 160)
			)
		end
	end
	-- Open edges connect the handling pad to the surrounding drivable land.
	for z = -70, -350, -40 do
		local x = if math.floor(-z / 40) % 2 == 0 then -22 else 22
		local cone = part(
			model,
			"SlalomBollard",
			Vector3.new(3, 4, 3),
			CFrame.new(x, 2, z),
			Color3.fromRGB(255, 130, 76)
		)
		cone.CanCollide = false
	end
	sign(model, "01 / SLALOM", "Predictable turns at 35–60 km/h", CFrame.new(0, 13, -45), 35)
	-- A low bridge provides a ramp, crest and descent without expanding into a full map.
	part(
		model,
		"RampUp",
		Vector3.new(35, 2, 85),
		CFrame.new(115, 6, -170) * CFrame.Angles(math.rad(8), 0, 0),
		asphalt
	)
	part(model, "Crest", Vector3.new(35, 2, 40), CFrame.new(115, 12, -232), asphalt)
	part(
		model,
		"RampDown",
		Vector3.new(35, 2, 85),
		CFrame.new(115, 6, -294) * CFrame.Angles(math.rad(-8), 0, 0),
		asphalt
	)
	sign(model, "02 / CREST", "Climb · landing · recovery", CFrame.new(115, 13, -115), 32)
	for i = 1, 28 do
		local angle = i * math.pi * 2 / 28
		part(
			model,
			"SkidCircle",
			Vector3.new(3, 0.08, 5),
			CFrame.new(-108 + math.cos(angle) * 51, 0.07, -240 + math.sin(angle) * 51),
			Color3.fromRGB(92, 204, 191)
		).CanCollide =
			false
	end
	sign(model, "03 / SKIDPAD", "Turn + Space / Shift at speed", CFrame.new(-110, 13, -155), 39)
	for _, pos in { Vector3.new(-280, 0, 25), Vector3.new(280, 0, -70), Vector3.new(-280, 0, -365) } do
		part(
			model,
			"PalmTrunk",
			Vector3.new(3, 24, 3),
			CFrame.new(pos + Vector3.new(0, 12, 0)),
			Color3.fromRGB(114, 95, 82)
		)
		for yaw = 0, 135, 45 do
			part(
				model,
				"PalmCrown",
				Vector3.new(32, 2, 6),
				CFrame.new(pos + Vector3.new(0, 24, 0)) * CFrame.Angles(0, math.rad(yaw), 0),
				Color3.fromRGB(47, 113, 103)
			)
		end
	end
	return model
end

return Course
