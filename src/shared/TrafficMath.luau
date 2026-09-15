--!strict
local TrafficMath = {}

-- Three lanes each way. Equal speeds within a lane preserve spacing indefinitely.
function TrafficMath.position(
	lane: number,
	slot: number,
	elapsed: number,
	half: number,
	perLane: number
): (number, number, number)
	local direction = if lane <= 3 then -1 else 1
	local offset = (lane - 1) % 3
	local x = (15 + offset * 18) * -direction
	local speed = (90 - offset * 15) * direction
	local start = -180 - lane * 35 + slot * (half * 2 / perLane)
	local z = (start + elapsed * speed + half) % (half * 2) - half
	return x, z, direction
end

return TrafficMath
