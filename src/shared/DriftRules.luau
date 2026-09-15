--!strict
local Drift = {}
export type State = { points: number, seconds: number, gap: number, damage: number }
function Drift.new(): State
	return { points = 0, seconds = 0, gap = 0, damage = 0 }
end
function Drift.step(
	s: State,
	dt: number,
	speed: number,
	lateral: number,
	grounded: boolean,
	damage: number,
	valid: boolean
): (number, number)
	dt = math.clamp(dt, 0, 0.1)
	if not valid or damage > s.damage then
		s.points = 0
		s.seconds = 0
		s.gap = 0
	end
	s.damage = damage
	if not valid then
		return 0, 0
	end
	local angle = math.deg(math.atan2(math.abs(lateral), math.abs(speed)))
	if grounded and speed > 25 and angle >= 10 and angle <= 65 then
		s.seconds += dt
		s.gap = 0
		s.points += dt * math.min(60, angle) * math.min(2, 1 + s.seconds / 6)
	elseif s.points > 0 then
		s.gap += dt
	end
	if s.gap >= 1.25 then
		local bank = if s.seconds >= 1.5 then math.min(100, math.floor(s.points / 10)) else 0
		local score = if bank > 0 then math.floor(s.points) else 0
		s.points = 0
		s.seconds = 0
		s.gap = 0
		return bank, score
	end
	return 0, 0
end
return Drift
