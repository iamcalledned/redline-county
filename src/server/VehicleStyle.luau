--!strict
-- Original procedural coachwork: believable proportions, no external mesh dependency.
local Style = {}
function Style.build(model: Model, body: Part, dimensions: Vector3, kind: string, detailed: boolean)
	local w, l = dimensions.X, dimensions.Z
	local pickup = kind == "Pickup"
	local roof = if pickup then 3.3 elseif kind == "Electric" then 2.75 else 2.35
	local rear = if pickup then l * 0.08 else l * 0.20
	local dark = Color3.fromRGB(26, 30, 34)
	local paint: { BasePart } = {}
	local function part(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3?,
		wedge: boolean?
	): BasePart
		local p: BasePart = if wedge then Instance.new("WedgePart") else Instance.new("Part")
		p.Name, p.Size, p.CFrame = name, size, body.CFrame * offset
		p.Color = color or body.Color
		p.Material = Enum.Material.SmoothPlastic
		p.CanCollide, p.CanTouch, p.CanQuery, p.Massless = false, false, false, true
		p.Parent = model
		if not color then
			p.Reflectance = 0.08
			table.insert(paint, p)
		end
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = body, p, p
		return p
	end
	local function glass(name: string, size: Vector3, cf: CFrame): BasePart
		local p = part(name, size, cf, Color3.fromRGB(91, 123, 132))
		p.Material = Enum.Material.Glass
		p.Transparency = if detailed then 0.68 else 0.28
		p.Reflectance = 0.12
		return p
	end
	body.Material = Enum.Material.SmoothPlastic
	body.Reflectance = 0.08
	part("SculptedHood", Vector3.new(w * 0.94, 1.1, l * 0.27), CFrame.new(0, 0.62, -l * 0.335), nil, true)
	part(
		"RearDeck",
		Vector3.new(w * 0.95, 0.9, l * 0.24),
		CFrame.new(0, 0.52, l * 0.35) * CFrame.Angles(0, math.pi, 0),
		nil,
		true
	)
	part(
		"CabinRoof",
		Vector3.new(w * 0.78, 0.18, if pickup then l * 0.31 else l * 0.37),
		CFrame.new(0, roof, -l * 0.005)
	)
	glass(
		"RakedWindshield",
		Vector3.new(w * 0.79, roof - 1, 0.1),
		CFrame.new(0, (roof + 1) / 2, -l * 0.19) * CFrame.Angles(math.rad(24), 0, 0)
	)
	glass(
		"RearGlass",
		Vector3.new(w * 0.77, roof - 1, 0.1),
		CFrame.new(0, (roof + 1) / 2, rear) * CFrame.Angles(math.rad(-22), 0, 0)
	)
	for _, side in { -1, 1 } do
		part("Sill", Vector3.new(0.2, 0.5, l * 0.88), CFrame.new(side * w * 0.48, -0.25, 0), dark)
		part("DoorSkin", Vector3.new(0.15, 0.85, l * 0.46), CFrame.new(side * w * 0.485, 0.75, -0.1))
		glass(
			"SideGlass",
			Vector3.new(0.09, roof - 1.3, l * 0.32),
			CFrame.new(side * w * 0.414, (roof + 1.1) / 2, 0)
		)
		part(
			"DoorPillar",
			Vector3.new(0.17, roof - 1, 0.17),
			CFrame.new(side * w * 0.42, (roof + 1) / 2, l * 0.01),
			dark
		)
		part(
			"FrontPillar",
			Vector3.new(0.16, roof - 1, 0.16),
			CFrame.new(side * w * 0.42, (roof + 1) / 2, -l * 0.19) * CFrame.Angles(math.rad(24), 0, 0)
		)
		part(
			"RearPillar",
			Vector3.new(0.18, roof - 1, 0.18),
			CFrame.new(side * w * 0.42, (roof + 1) / 2, rear) * CFrame.Angles(math.rad(-22), 0, 0)
		)
		part("Mirror", Vector3.new(0.65, 0.38, 0.9), CFrame.new(side * (w / 2 + 0.23), 1.55, -l * 0.16), dark)
		part(
			"Handle",
			Vector3.new(0.13, 0.12, 0.62),
			CFrame.new(side * (w / 2 + 0.04), 1.03, l * 0.04),
			Color3.fromRGB(185, 191, 194)
		)
		if pickup then
			part("BedRail", Vector3.new(0.26, 1.15, l * 0.35), CFrame.new(side * w * 0.46, 0.7, l * 0.30))
		end
	end
	if pickup then
		part("OpenBed", Vector3.new(w * 0.84, 0.12, l * 0.31), CFrame.new(0, 0.9, l * 0.31), dark)
		part("Tailgate", Vector3.new(w * 0.96, 1.15, 0.25), CFrame.new(0, 0.6, l * 0.48))
	end
	part("FrontBumper", Vector3.new(w * 0.97, 0.4, 0.5), CFrame.new(0, -0.05, -l * 0.5), dark)
	part("RearBumper", Vector3.new(w * 0.95, 0.35, 0.4), CFrame.new(0, -0.1, l * 0.5), dark)
	part("LowerGrille", Vector3.new(w * 0.55, 0.45, 0.12), CFrame.new(0, 0.35, -l * 0.5 - 0.27), dark)
	part(
		"FrontPlate",
		Vector3.new(1.4, 0.34, 0.06),
		CFrame.new(0, -0.08, -l * 0.5 - 0.29),
		Color3.fromRGB(221, 225, 212)
	)
	part(
		"RearPlate",
		Vector3.new(1.4, 0.34, 0.06),
		CFrame.new(0, 0.12, l * 0.5 + 0.24),
		Color3.fromRGB(221, 225, 212)
	)
	if detailed then
		part("Dashboard", Vector3.new(w * 0.78, 0.4, 1.4), CFrame.new(0, 0.95, -l * 0.12), dark)
		part("Console", Vector3.new(0.7, 0.6, 2.3), CFrame.new(0, 0.6, l * 0.04), dark)
		for _, x in { -w * 0.22, w * 0.22 } do
			part("SeatCushion", Vector3.new(w * 0.29, 0.25, 1.8), CFrame.new(x, 0.4, l * 0.055), dark)
			part(
				"SeatBack",
				Vector3.new(w * 0.29, 1.7, 0.3),
				CFrame.new(x, 1.25, l * 0.12) * CFrame.Angles(math.rad(-10), 0, 0),
				dark
			)
			part("Headrest", Vector3.new(w * 0.2, 0.55, 0.35), CFrame.new(x, 2.25, l * 0.14), dark)
		end
	end
	body:GetPropertyChangedSignal("Color"):Connect(function()
		for _, p in paint do
			if p.Parent then
				p.Color = body.Color
			end
		end
	end)
end
function Style.rim(rim: Part)
	for i = 0, 4 do
		local spoke = Instance.new("Part")
		spoke.Name = "AlloySpoke"
		spoke.Size = Vector3.new(0.035, 0.13, 1.05)
		spoke.CFrame = rim.CFrame * CFrame.Angles(i * math.pi * 2 / 5, 0, 0) * CFrame.new(0, 0.35, 0)
		spoke.Color = Color3.fromRGB(58, 63, 67)
		spoke.Material = Enum.Material.Metal
		spoke.CanCollide, spoke.CanQuery, spoke.CanTouch, spoke.Massless = false, false, false, true
		spoke.Parent = rim
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = rim, spoke, spoke
	end
end
return Style
