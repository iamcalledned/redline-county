--!strict
local Fit = require(game:GetService("ReplicatedStorage").Shared.CockpitFit)
local Cockpit = {}

function Cockpit.install(
	model: Model,
	body: BasePart,
	seatOffset: Vector3,
	windowY: number?,
	windowHeight: number?
)
	local seat = model:FindFirstChild("DriverSeat") :: VehicleSeat
	local occupant = seat.Occupant
	if occupant then
		occupant.Sit = false
		local riderWeld = seat:FindFirstChild("SeatWeld")
		if riderWeld then
			riderWeld:Destroy()
		end
	end
	for _, child in seat:GetChildren() do
		if child:IsA("WeldConstraint") then
			child:Destroy()
		end
	end
	seat.CFrame = body.CFrame * CFrame.new(seatOffset)
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0, seatWeld.Part1, seatWeld.Parent = body, seat, seat
	-- Replacing an appearance must not leave a stale eye or a second steering wheel.
	for _, name in { "CockpitEye", "SteeringMotor" } do
		local old = body:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end
	local oldWheel = model:FindFirstChild("SteeringWheel")
	if oldWheel then
		oldWheel:Destroy()
	end
	local height, minimum, maximum = Fit.height(seatOffset.Y, windowY, windowHeight)
	local eyeOffset = Vector3.new(seatOffset.X, height, seatOffset.Z - 0.15)
	local eye = Instance.new("Attachment")
	eye.Name = "CockpitEye"
	eye.Position = eyeOffset
	eye:SetAttribute("MinHeight", minimum)
	eye:SetAttribute("MaxHeight", maximum)
	eye.Parent = body

	local wheel = Instance.new("Model")
	wheel.Name = "SteeringWheel"
	local center = CFrame.new(eyeOffset + Vector3.new(0, -0.85, -1.8)) * CFrame.Angles(math.rad(-15), 0, 0)
	local function piece(name: string, size: Vector3, offset: CFrame): Part
		local part = Instance.new("Part")
		part.Name, part.Size = name, size
		part.CFrame = body.CFrame * center * offset
		part.Color = Color3.fromRGB(27, 31, 36)
		part.Material = Enum.Material.SmoothPlastic
		part.CanCollide, part.CanTouch, part.CanQuery, part.Massless = false, false, false, true
		part.Parent = wheel
		return part
	end
	local hub = piece("Hub", Vector3.new(0.35, 0.3, 0.18), CFrame.identity)
	local function weld(part: Part)
		local joint = Instance.new("WeldConstraint")
		joint.Part0, joint.Part1, joint.Parent = hub, part, part
	end
	for i = 0, 23 do
		local angle = i * math.pi * 2 / 24
		weld(
			piece(
				"Rim",
				Vector3.new(0.15, 0.1, 0.12),
				CFrame.new(math.sin(angle) * 0.52, math.cos(angle) * 0.52, 0) * CFrame.Angles(0, 0, -angle)
			)
		)
	end
	for _, angle in { math.pi / 2, -math.pi / 2, math.pi } do
		weld(piece("Spoke", Vector3.new(0.1, 0.48, 0.1), CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.24, 0)))
	end
	local motor = Instance.new("Motor6D")
	motor.Name = "SteeringMotor"
	motor.Part0, motor.Part1, motor.C0 = body, hub, center
	motor:SetAttribute("Rest", center)
	motor.Parent = body
	wheel.Parent = model
	model:SetAttribute("CockpitReady", true)
	if occupant then
		task.defer(function()
			if
				seat.Parent
				and occupant.Parent
				and occupant.Health > 0
				and not model:GetAttribute("Crashed")
			then
				seat:Sit(occupant)
			end
		end)
	end
end

return Cockpit
