--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Driving = require(ReplicatedStorage.Shared.Driving)
local Turbo = require(ReplicatedStorage.Shared.Turbo)
local Progression = require(ReplicatedStorage.Shared.Progression)
local HeadlightMath = require(ReplicatedStorage.Shared.HeadlightMath)

local Cockpit = require(script.Parent.Cockpit)
local TownDriving = require(ReplicatedStorage.Shared.TownDriving)
local Appearance = require(script.Parent.VehicleAppearance)

local Bundled = require(script.Parent.BundledVehicles)
local Style = require(script.Parent.VehicleStyle)
local Vehicle = {}
export type Car = {
	Model: Model,
	Body: Part,
	Seat: VehicleSeat,
	Springs: { VectorForce },
	Drive: VectorForce,
	Align: AlignOrientation,
	Ray: RaycastParams,
	Tune: Driving.Tuning,
	Steer: number,
	Turbo: Turbo.State,
	TelemetryClock: number,
	Wheels: { { motor: Motor6D, rest: CFrame, front: boolean } },
	WheelSpin: number,
	Wheelbase: number?,
	WheelRadius: number,
	Suspension: { Rest: number, Reach: number, Spring: number, Damping: number },
}

function Vehicle.create(
	parent: Instance,
	owner: Player?,
	kind: string,
	cf: CFrame,
	appearanceKind: string?
): Car
	local tune = (Config.Cars :: any)[kind]
	local town = kind == "Pickup" or kind == "Electric" or kind == "Sport"
	local dimensions = if town then tune.Dimensions else Vector3.new(5.4, 1.1, 9)
	local sx, sz = dimensions.X / 5.4, dimensions.Z / 9
	local wheels: { { motor: Motor6D, rest: CFrame, front: boolean } } = {}
	local model = Instance.new("Model")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.Name = if owner then "Car_" .. owner.UserId else "AI_Patrol"
	if owner then
		model:SetAttribute("OwnerId", owner.UserId)
	else
		model:SetAttribute("Police", true)
	end
	model:SetAttribute("Kind", kind)
	local body = Instance.new("Part")
	body.Name, body.Size, body.CFrame = "Chassis", dimensions, cf
	body.Color = tune.Color
	body.CustomPhysicalProperties =
		PhysicalProperties.new(if town then tune.Density else 1, 0.05, 0, 100, 100)
	body.RootPriority = 127
	body.CollisionGroup = "Cars"
	body.Parent = model
	model.PrimaryPart = body

	local function trim(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		shape: Enum.PartType?
	): Part
		if town then
			offset = CFrame.new(offset.Position * Vector3.new(sx, 1, sz)) * offset.Rotation
			size = if shape then size * Vector3.new(1, 1.25, 1.25) else size * Vector3.new(sx, 1, sz)
		end
		local p = Instance.new("Part")
		p.Name, p.Size, p.CFrame, p.Color = name, size, cf * offset, color
		p.Shape = shape or Enum.PartType.Block
		p.CanCollide, p.Massless = false, true
		p.CollisionGroup = "Cars"
		p.Parent = model
		if name == "Wheel" or name == "Rim" then
			local motor = Instance.new("Motor6D")
			motor.Name = "RoadWheel"
			motor.Part0 = body
			motor.Part1 = p
			motor.C0 = offset
			motor.Parent = p
			table.insert(wheels, { motor = motor, rest = offset, front = offset.Position.Z < 0 })
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = body, p, p
		end
		return p
	end
	if town then
		Style.build(model, body, dimensions, kind, owner ~= nil)
	else
		trim("Cabin", Vector3.new(4.4, 1.8, 3.6), CFrame.new(0, 1.3, 0.4), Color3.fromRGB(35, 53, 70))
		trim("Roof", Vector3.new(4.5, 0.3, 3.7), CFrame.new(0, 2.3, 0.4), tune.Color)
	end
	for _, x in { -1.8, 1.8 } do
		local lens = trim(
			"Headlamp",
			Vector3.new(1, 0.35, 0.2),
			CFrame.new(x, 0.2, -4.55),
			Color3.fromRGB(255, 243, 220)
		)
		lens.Material = Enum.Material.Neon
		local attachment = Instance.new("Attachment")
		attachment.Name = "HeadlightMount"
		-- Fixed directly to the chassis: no independently followed or smoothed light position.
		attachment.CFrame = CFrame.new(x * sx, 0.2, -dimensions.Z / 2 - 0.17)
			* CFrame.Angles(math.rad(-2), 0, 0)
		attachment.Parent = body
		local light = Instance.new("SpotLight")
		light.Enabled = false
		light.Name, light.Face = "AdaptiveHeadlight", Enum.NormalId.Front
		light.Color = lens.Color
		light.Range, light.Angle, light.Brightness = HeadlightMath.beam(0, Config.Headlights)
		light.Shadows = false
		light.Parent = attachment
		trim("TailLamp", Vector3.new(1, 0.35, 0.2), CFrame.new(x, 0.2, 4.55), Color3.fromRGB(255, 83, 102)).Material =
			Enum.Material.Neon
	end
	-- Original front-mounted intercooler geometry for the turbo-equipped prototype cars.
	trim(
		"Intercooler",
		Vector3.new(2.6, 0.65, 0.22),
		CFrame.new(0, -0.1, -4.65),
		Color3.fromRGB(130, 159, 171)
	)
	for y = -0.3, 0.15, 0.15 do
		trim("CoolingFin", Vector3.new(2.4, 0.04, 0.05), CFrame.new(0, y, -4.79), Color3.fromRGB(37, 50, 61))
	end
	if kind == "Interceptor" then
		for _, x in { -1, 1 } do
			trim(
				"Lightbar",
				Vector3.new(1.8, 0.35, 0.6),
				CFrame.new(x, 2.65, 0.4),
				if x < 0 then Color3.fromRGB(255, 90, 110) else Color3.fromRGB(83, 194, 255)
			).Material =
				Enum.Material.Neon
		end
	end
	local springs = {}
	for _, x in { -2.3, 2.3 } do
		for _, z in { -3.1, 3.1 } do
			trim(
				"Wheel",
				Vector3.new(0.8, 2, 2),
				CFrame.new(x * 1.22, -1, if town then math.sign(z) * tune.Wheelbase / 2 / sz else z),
				Color3.fromRGB(23, 27, 34),
				Enum.PartType.Cylinder
			)
			local rim = trim(
				"Rim",
				Vector3.new(0.85, 1.2, 1.2),
				CFrame.new(x * 1.22, -1, if town then math.sign(z) * tune.Wheelbase / 2 / sz else z),
				Color3.fromRGB(175, 193, 196),
				Enum.PartType.Cylinder
			)
			if town and owner then
				Style.rim(rim)
			end
			local attachment = Instance.new("Attachment")
			attachment.Position =
				Vector3.new(x * sx, 0, if town then math.sign(z) * tune.Wheelbase / 2 else z)
			attachment.Parent = body
			local spring = Instance.new("VectorForce")
			spring.Name = "Suspension"
			spring.Attachment0 = attachment
			spring.RelativeTo = Enum.ActuatorRelativeTo.World
			spring.ApplyAtCenterOfMass = true
			spring.Force = Vector3.zero
			spring.Parent = body
			table.insert(springs, spring)
		end
	end
	local center = Instance.new("Attachment")
	center.Parent = body
	local drive = Instance.new("VectorForce")
	drive.Name, drive.Attachment0 = "Drive", center
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.ApplyAtCenterOfMass = true
	drive.Force = Vector3.zero
	drive.Parent = body
	local align = Instance.new("AlignOrientation")
	align.Name = "Stability"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = center
	align.Responsiveness = 12
	align.MaxAngularVelocity = 4
	align.CFrame = cf.Rotation
	align.Parent = body
	local seat = Instance.new("VehicleSeat")
	seat.Name, seat.Size, seat.CFrame = "DriverSeat", Vector3.new(2, 0.5, 2), cf * CFrame.new(0, 1.5, 0.3)
	seat.Transparency, seat.CanCollide, seat.Massless = 1, false, true
	seat.Torque, seat.MaxSpeed, seat.TurnSpeed = 0, 0, 0
	seat.HeadsUpDisplay = false
	seat.Disabled = true -- Only the owner-authorized prompt can seat a driver.
	seat.CollisionGroup = "Cars"
	seat.Parent = model
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = body, seat, seat
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText =
		"Drive", kind .. " · " .. (if owner then owner.DisplayName else "Police")
	prompt.Enabled = owner ~= nil
	prompt.MaxActivationDistance = 12
	-- Validate character-to-seat clearance on the server; an indoor camera can be
	-- occluded even when the player is standing directly beside the driver's door.
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	-- Center the prompt on the car rather than a concealed interior seat.
	prompt.Parent = model
	model.Parent = parent
	Appearance.attach(model, body, kind)
	local imported = if town
		then Bundled.attach(
			model,
			body,
			appearanceKind or (if owner then kind else "Police"),
			wheels,
			owner ~= nil
		)
		else nil
	if town and owner and not imported then
		Cockpit.install(model, body, Vector3.new(-dimensions.X * 0.22, 0.2, 0.2))
		model:SetAttribute("ProvisionalAppearance", true)
	end
	body:SetNetworkOwner(nil)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { parent, workspace:WaitForChild("HighwayTraffic") }
	-- Use solid world geometry, including Terrain and parts outside the course.
	-- Cars/Characters do not collide with this query group.
	ray.CollisionGroup = "Suspension"
	ray.RespectCanCollide = true
	ray.IgnoreWater = true
	model:SetAttribute(
		"WheelRadius",
		if imported then imported:GetAttribute("WheelRadius") else (if town then 1.25 else 1)
	)
	for _, wheel in wheels do
		wheel.motor.Name = "RoadWheel"
		wheel.motor:SetAttribute("FrontWheel", wheel.front)
	end
	return {
		Model = model,
		Body = body,
		Seat = seat,
		Springs = springs,
		Drive = drive,
		Align = align,
		Ray = ray,
		Tune = tune,
		Steer = 0,
		Turbo = { boost = 0, heat = 0, overheated = false },
		TelemetryClock = 0,
		Wheels = wheels,
		WheelSpin = 0,
		Wheelbase = if imported
			then math.abs(
				(
					(imported:GetAttribute("Wheel_FL") :: Vector3)
					- imported:GetAttribute("Wheel_RL") :: Vector3
				).Z
			)
			elseif town then tune.Wheelbase
			else nil,
		WheelRadius = if imported
			then imported:GetAttribute("WheelRadius") :: number
			else (if town then 1.25 else 1),
		Suspension = table.clone(Config.Suspension),
	}
end

function Vehicle.step(
	car: Car,
	dt: number,
	throttle: number,
	steer: number,
	drift: boolean,
	turboEnabled: boolean
)
	local body = car.Body
	local mass = body.AssemblyMass
	local boost = Turbo.step(
		car.Turbo,
		dt,
		turboEnabled,
		throttle,
		body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector),
		drift,
		Config.Turbo
	)
	car.TelemetryClock += dt
	if car.TelemetryClock >= 0.1 then
		car.TelemetryClock = 0
		car.Model:SetAttribute("Throttle", throttle)
		car.Model:SetAttribute("Boost", boost)
		car.Model:SetAttribute("TurboHeat", car.Turbo.heat)
		car.Model:SetAttribute("TurboOverheated", car.Turbo.overheated)
	end
	car.Steer = Driving.approach(car.Steer, steer, Config.SteeringResponse, dt)
	local speed = body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector)
	-- Cosmetic motors animate locally. Never replicate every wheel transform every physics step.
	if car.TelemetryClock == 0 then
		car.Model:SetAttribute("VisualSteer", car.Steer)
	end
	local grounded, normal = 0, Vector3.zero
	-- Suspension applies through the assembly centre. AlignOrientation alone controls
	-- attitude: offset springs and the upright servo used to fight after a contact.
	for _, spring in car.Springs do
		local origin = (spring.Attachment0 :: Attachment).WorldPosition
		local hit = workspace:Raycast(origin, Vector3.new(0, -car.Suspension.Reach, 0), car.Ray)
		if hit and hit.Normal.Y > 0.45 then
			grounded += 1
			normal += hit.Normal
			local velocity = body:GetVelocityAtPosition(origin)
			local strength = Progression.spring(
				car.Suspension.Rest,
				hit.Distance,
				velocity.Y,
				workspace.Gravity,
				car.Suspension.Spring,
				car.Suspension.Damping,
				dt
			)
			spring.Force = Vector3.new(0, strength * mass, 0)
		else
			spring.Force = Vector3.zero
		end
	end
	if car.TelemetryClock == 0 then
		car.Model:SetAttribute("GroundedWheels", grounded)
		car.Model:SetAttribute("Drifting", drift and speed > car.Tune.DriftMinSpeed and grounded >= 2)
	end
	car.Align.Enabled = grounded >= 2
	if grounded < 2 then
		car.Drive.Force = Vector3.zero
		return
	end
	local up = normal.Unit
	local forward = body.CFrame.LookVector
	forward -= up * forward:Dot(up)
	if forward.Magnitude < 0.1 then
		car.Drive.Force = Vector3.zero
		return
	end
	forward = forward.Unit
	local right = forward:Cross(up).Unit
	local velocity = body.AssemblyLinearVelocity
	local acceleration, lateral, turn = Driving.forces(
		velocity:Dot(forward),
		velocity:Dot(right),
		throttle,
		car.Steer,
		drift,
		car.Tune,
		boost
	)
	if car.Wheelbase then
		turn = TownDriving.yaw(
			velocity:Dot(forward),
			car.Steer,
			car.Wheelbase,
			drift,
			car.Tune.DriftMinSpeed,
			car.Tune.DriftTurn
		)
	end
	if car.TelemetryClock == 0 then
		car.Model:SetAttribute("SteeringAngle", math.deg(TownDriving.steerAngle(speed, car.Steer)))
	end
	car.Drive.Force = (forward * acceleration + right * lateral) * mass
	local heading = CFrame.fromAxisAngle(up, turn * dt):VectorToWorldSpace(forward)
	-- Lead the orientation target slightly; otherwise responsiveness would attenuate yaw every frame.
	local target = CFrame.fromAxisAngle(up, turn * 0.16):VectorToWorldSpace(heading)
	car.Align.CFrame = CFrame.lookAt(Vector3.zero, target, up)
	car.Align.MaxTorque = mass * 6000
end

return Vehicle
