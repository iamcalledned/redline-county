--!strict
local HighwayMath = {}

function HighwayMath.wrap(z: number, halfLength: number): number
	return (z + halfLength) % (2 * halfLength) - halfLength
end

function HighwayMath.needed(
	positions: { number },
	length: number,
	radius: number,
	halfLength: number
): { [number]: boolean }
	local result: { [number]: boolean } = {}
	local function add(z: number)
		local center = math.floor(-z / length)
		for index = center - radius, center + radius do
			result[index] = true
		end
	end
	for _, z in positions do
		z = HighwayMath.wrap(z, halfLength)
		add(z)
		-- Prefetch the other side of the recycle point BEFORE a car reaches it.
		if z < -halfLength + length * radius then
			add(z + 2 * halfLength)
		end
		if z > halfLength - length * radius then
			add(z - 2 * halfLength)
		end
	end
	return result
end

function HighwayMath.travel(previousZ: number, nextZ: number, halfLength: number, maxTravel: number): number
	local delta = math.abs(HighwayMath.wrap(nextZ - previousZ, halfLength))
	return if delta <= maxTravel then delta else 0
end

return HighwayMath
