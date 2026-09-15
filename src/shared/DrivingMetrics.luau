--!strict
local Metrics = {}
export type State = {
	previous: number,
	accelerating: number?,
	zeroTo50: number?,
	brakeFrom: number?,
	brakeDistance: number,
	lastStop: number?,
	lastFrom: number?,
}
function Metrics.new(): State
	return {
		previous = 0,
		accelerating = nil,
		zeroTo50 = nil,
		brakeFrom = nil,
		brakeDistance = 0,
		lastStop = nil,
		lastFrom = nil,
	}
end
function Metrics.step(s: State, kmh: number, throttle: number, dt: number)
	if dt <= 0 or dt > 0.25 then
		s.previous = kmh
		return
	end
	if kmh < 1 and throttle <= 0 then
		s.accelerating = nil
	end
	if s.previous < 1 and throttle > 0 and not s.accelerating then
		s.accelerating = 0
	end
	if s.accelerating then
		s.accelerating += dt
		if kmh >= 50 then
			s.zeroTo50 = s.accelerating
			s.accelerating = nil
		end
	end
	if throttle < 0 and s.previous >= 10 and not s.brakeFrom then
		s.brakeFrom = s.previous
		s.brakeDistance = 0
	end
	if s.brakeFrom then
		s.brakeDistance += (s.previous + kmh) / 2 / 3.6 * dt
		if kmh < 1 then
			s.lastStop = s.brakeDistance
			s.lastFrom = s.brakeFrom
			s.brakeFrom = nil
		elseif throttle >= 0 then
			s.brakeFrom = nil
		end
	end
	s.previous = kmh
end
return Metrics
