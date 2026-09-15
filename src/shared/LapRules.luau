--!strict
local Lap = {}
export type State = { previous: number?, travel: number, time: number, direction: number }
function Lap.new(): State
	return { previous = nil, travel = 0, time = 0, direction = 0 }
end
function Lap.step(s: State, progress: number, length: number, dt: number, valid: boolean): (boolean, number)
	if not valid then
		s.previous = nil
		s.travel = 0
		s.time = 0
		s.direction = 0
		return false, 0
	end
	local before = s.previous
	s.previous = progress
	if not before then
		return false, 0
	end
	local delta = (progress - before + length / 2) % length - length / 2
	if math.abs(delta) > 500 * math.clamp(dt, 0, 0.25) + 3 then
		s.previous = nil
		s.travel = 0
		s.time = 0
		s.direction = 0
		return false, 0
	end
	if s.direction == 0 and math.abs(delta) > 0.1 then
		s.direction = math.sign(delta)
	end
	s.time += math.clamp(dt, 0, 0.25)
	s.travel = math.max(0, s.travel + delta * s.direction)
	if s.travel >= length then
		local seconds = s.time
		s.travel = 0
		s.time = 0
		s.direction = 0
		return true, seconds
	end
	return false, 0
end
return Lap
