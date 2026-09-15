--!strict
-- Engine-independent handling math: tested in the standalone Luau runtime.
local Driving = {}
export type Tuning = {
	TopSpeed: number,
	BoostSpeed: number,
	BoostAcceleration: number,
	ReverseSpeed: number,
	Acceleration: number,
	Brake: number,
	Grip: number,
	DriftGrip: number,
	DriftTurn: number,
	DriftMinSpeed: number,
	DriftDrag: number,
	Turn: number,
}

function Driving.finite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Driving.validInput(throttle: any, steer: any, drift: any): boolean
	return Driving.finite(throttle)
		and Driving.finite(steer)
		and math.abs(throttle) <= 1
		and math.abs(steer) <= 1
		and type(drift) == "boolean"
end

function Driving.forces(
	speed: number,
	lateral: number,
	throttle: number,
	steer: number,
	drift: boolean,
	tune: Tuning,
	boost: number?
): (number, number, number)
	local pressure = math.clamp(boost or 0, 0, 1)
	local acceleration: number
	if throttle * speed < -3 then
		acceleration = throttle * tune.Brake
	elseif math.abs(throttle) < 0.01 then
		acceleration = -speed * 0.65
	else
		local limit = if throttle > 0 then tune.TopSpeed + pressure * tune.BoostSpeed else tune.ReverseSpeed
		local powerFade = if throttle > 0 then 1 / (1 + (math.abs(speed) / (limit * 0.55)) ^ 2) else 1
		acceleration = throttle
			* powerFade
			* tune.Acceleration
			* (1 + pressure * (tune.BoostAcceleration - 1))
			* math.clamp((limit - math.abs(speed)) / 15, 0, 1)
		-- Aerodynamic slowdown above the available power limit, including turbo cooldown.
		acceleration -= math.sign(speed) * math.max(0, math.abs(speed) - limit) * 0.65
	end
	-- Blend in only while moving forward: parking and reversing stay predictable.
	local slide = if drift then math.clamp((speed - tune.DriftMinSpeed) / 15, 0, 1) else 0
	acceleration -= speed * tune.DriftDrag * slide
	-- Steering tapers at speed, and reverses while backing up. No pivoting at rest.
	local turn = -steer * tune.Turn * math.clamp(speed / 18, -1, 1) / (1 + math.abs(speed) / 130)
	turn *= 1 + (tune.DriftTurn - 1) * slide
	local grip = tune.Grip + (tune.DriftGrip - tune.Grip) * slide
	return acceleration, -lateral * grip, turn
end

function Driving.approach(current: number, target: number, response: number, dt: number): number
	return current + (target - current) * (1 - math.exp(-response * dt))
end

return Driving
