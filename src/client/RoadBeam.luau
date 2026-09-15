--!strict
-- Client-only road illumination approximation, independent of the light-grid refresh.
-- Raycasts place a small, reusable beam mesh on the road each rendered frame.
local RoadBeam = {}
local STEPS = 10

type Strip = { a: Attachment, b: Attachment, beam: Beam, side: number, step: number }
local strips: { Strip } = {}
local holder = Instance.new("Part")
holder.Name = "LocalRoadBeams"
holder.Anchored = true
holder.Transparency = 1
holder.Size = Vector3.one
holder.CanCollide, holder.CanTouch, holder.CanQuery = false, false, false
holder.Parent = workspace
for _, side in { -1, 1 } do
	for step = 1, STEPS do
		local a, b = Instance.new("Attachment"), Instance.new("Attachment")
		a.Parent, b.Parent = holder, holder
		local beam = Instance.new("Beam")
		beam.Name = "RoadLight"
		beam.Attachment0, beam.Attachment1 = a, b
		beam.FaceCamera = false
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Color = ColorSequence.new(Color3.fromRGB(255, 241, 205))
		beam.Segments = 1
		local t0, t1 = (step - 1) / STEPS, step / STEPS
		beam.Transparency = NumberSequence.new(0.78 + 0.22 * t0, 0.78 + 0.22 * t1)
		beam.Enabled = false
		beam.Parent = holder
		table.insert(strips, { a = a, b = b, beam = beam, side = side, step = step })
	end
end
local params = RaycastParams.new()
params.RespectCanCollide = true
params.FilterType = Enum.RaycastFilterType.Exclude

function RoadBeam.hide()
	for _, strip in strips do
		strip.beam.Enabled = false
	end
end

function RoadBeam.update(body: BasePart, range: number, character: Model?)
	local forward = body.CFrame.LookVector * Vector3.new(1, 0, 1)
	if forward.Magnitude < 0.1 or body.CFrame.UpVector.Y < 0.5 then
		RoadBeam.hide()
		return
	end
	forward = forward.Unit
	local right = forward:Cross(Vector3.yAxis)
	local exclude: { Instance } = { body.Parent :: Instance, holder }
	if character then
		table.insert(exclude, character)
	end
	params.FilterDescendantsInstances = exclude
	-- Origin follows this frame's chassis transform, including turns and highway wraps.
	for _, side in { -1, 1 } do
		local origin = body.Position + forward * (body.Size.Z / 2 + 0.2) + right * (side * body.Size.X * 0.33)
		local obstacle = workspace:Raycast(origin, forward * range, params)
		local reach = if obstacle then math.max(0, obstacle.Distance - 1) else range
		local points: { RaycastResult? } = {}
		for i = 0, STEPS do
			local distance = range * i / STEPS
			local sample = origin + forward * distance
			points[i + 1] = workspace:Raycast(sample + Vector3.yAxis * 2, -Vector3.yAxis * 10, params)
		end
		for _, strip in strips do
			if strip.side ~= side then
				continue
			end
			local a, b = points[strip.step], points[strip.step + 1]
			local d0, d1 = range * (strip.step - 1) / STEPS, range * strip.step / STEPS
			local valid = a ~= nil and b ~= nil and d1 <= reach
			if a and b then
				valid = valid
					and a.Normal.Y > 0.85
					and b.Normal.Y > 0.85
					and math.abs(a.Position.Y - b.Position.Y) < 1
				-- Attachment Y axes define the beam's width across the road.
				strip.a.WorldCFrame = CFrame.fromMatrix(a.Position + a.Normal * 0.035, forward, right)
				strip.b.WorldCFrame = CFrame.fromMatrix(b.Position + b.Normal * 0.035, forward, right)
				strip.beam.Width0, strip.beam.Width1 = 2 + d0 * 0.16, 2 + d1 * 0.16
			end
			strip.beam.Enabled = valid
		end
	end
end

return RoadBeam
