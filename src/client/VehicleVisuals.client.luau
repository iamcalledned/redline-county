--!strict
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local TownDriving = require(Shared.TownDriving)
local Driving = require(Shared.Driving)
type Visual = {
	body: BasePart,
	motors: { Motor6D },
	spin: number,
	steer: number,
	connection: RBXScriptConnection,
}
local visuals: { [Model]: Visual } = {}
local scan = 0
RunService.PreSimulation:Connect(function(dt: number)
	scan += dt
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if scan >= 0.5 then
		scan = 0
		local near: { { model: Model, distance: number } } = {}
		for _, name in { "Vehicles", "TownTraffic", "PolicePatrols" } do
			local folder = workspace:FindFirstChild(name)
			if folder then
				for _, m in folder:GetChildren() do
					if m:IsA("Model") and m.PrimaryPart then
						local distance = (m.PrimaryPart.Position - camera.CFrame.Position).Magnitude
						if distance < 650 then
							table.insert(near, { model = m, distance = distance })
						end
					end
				end
			end
		end
		table.sort(near, function(a, b)
			return a.distance < b.distance
		end)
		local keep: { [Model]: boolean } = {}
		for i = 1, math.min(20, #near) do
			keep[near[i].model] = true
		end
		for m, v in visuals do
			if not keep[m] then
				v.connection:Disconnect()
				visuals[m] = nil
			end
		end
		for m in keep do
			if not visuals[m] and m.PrimaryPart then
				local motors: { Motor6D } = {}
				local function add(part: Instance)
					if part:IsA("Motor6D") and (part.Name == "RoadWheel" or part.Name == "SteeringMotor") then
						table.insert(motors, part)
					end
				end
				for _, part in m:GetDescendants() do
					add(part)
				end
				visuals[m] = {
					body = m.PrimaryPart,
					motors = motors,
					spin = 0,
					steer = 0,
					connection = m.DescendantAdded:Connect(add),
				}
			end
		end
	end
	for m, v in visuals do
		if not m.Parent then
			continue
		end
		local speed = v.body.AssemblyLinearVelocity:Dot(v.body.CFrame.LookVector)
		v.spin = (
			v.spin
			+ TownDriving.wheelRotation(
				speed,
				math.min(dt, 0.1),
				(m:GetAttribute("WheelRadius") :: number?) or 1.25
			)
		) % (math.pi * 2)
		v.steer = Driving.approach(v.steer, (m:GetAttribute("VisualSteer") :: number?) or 0, 12, dt)
		for _, motor in v.motors do
			if not motor.Parent then
				continue
			end
			if motor.Name == "SteeringMotor" then
				motor.Transform = CFrame.Angles(0, 0, -v.steer * math.rad(120))
			else
				motor.Transform = CFrame.Angles(
					0,
					if motor:GetAttribute("FrontWheel") then -TownDriving.steerAngle(speed, v.steer) else 0,
					0
				) * CFrame.Angles(v.spin, 0, 0)
			end
		end
	end
end)
