--!strict
local TownDriving = {}
function TownDriving.steerAngle(speed: number, steer: number): number
	return math.rad(32) * steer / (1 + math.abs(speed) / 38)
end
function TownDriving.yaw(
	speed: number,
	steer: number,
	wheelbase: number,
	drift: boolean?,
	minSpeed: number?,
	driftTurn: number?
): number
	local slide = if drift then math.clamp((speed - (minSpeed or 18)) / 15, 0, 1) else 0
	local yaw = -speed / wheelbase * math.tan(TownDriving.steerAngle(speed, steer))
	return math.clamp(yaw * (1 + ((driftTurn or 1.7) - 1) * slide), -1.8, 1.8)
end
function TownDriving.wheelRotation(speed: number, dt: number, radius: number): number
	return -speed * dt / radius
end
return TownDriving
