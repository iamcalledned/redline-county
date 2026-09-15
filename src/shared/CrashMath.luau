--!strict
local CrashMath = {}

-- Intersect entry/exit times on separating axes. Used for a moving oriented car
-- against axis-aligned lane traffic, including vertical separation.
function CrashMath.sweep(start: { number }, finish: { number }, halfExtents: { number }): number?
	local first, last = 0, 1
	for axis, extent in halfExtents do
		local origin, delta = start[axis], finish[axis] - start[axis]
		if math.abs(delta) < 1e-8 then
			if math.abs(origin) > extent then
				return nil
			end
		else
			local a, b = (-extent - origin) / delta, (extent - origin) / delta
			if a > b then
				a, b = b, a
			end
			first, last = math.max(first, a), math.min(last, b)
			if first > last then
				return nil
			end
		end
	end
	return first
end

function CrashMath.canBegin(crashed: boolean, contact: boolean): boolean
	return contact and not crashed
end

return CrashMath
