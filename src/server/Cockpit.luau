--!strict
local Cockpit = {}

function Cockpit.install(model: Model, body: BasePart, seatOffset: Vector3)
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
	local eye = Instance.new("Attachment")
	eye.Name = "CockpitEye"
	eye.Position = seatOffset + Vector3.new(0, 1.8, -0.15)
	eye.Parent = body

	local wheel = Instance.new("Model")
	wheel.Name = "SteeringWheel"
	local center = CFrame.new(seatOffset + Vector3.new(0, 0.85, -1.3)) * CFrame.Angles(math.rad(-15), 0, 0)
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
				Vector3.new(0.2, 0.13, 0.14),
				CFrame.new(math.sin(angle) * 0.68, math.cos(angle) * 0.68, 0) * CFrame.Angles(0, 0, -angle)
			)
		)
	end
	for _, angle in { math.pi / 2, -math.pi / 2, math.pi } do
		weld(piece("Spoke", Vector3.new(0.12, 0.6, 0.12), CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.3, 0)))
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
