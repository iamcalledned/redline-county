--!strict
-- Roblox standard scale: one stud = 0.28 metres.
local Units = {}
function Units.kmh(studsPerSecond: number): number
	return math.abs(studsPerSecond) * 0.28 * 3.6
end
function Units.mph(studsPerSecond: number): number
	return Units.kmh(studsPerSecond) / 1.609344
end
function Units.fromKmh(kmh: number): number
	return kmh / (0.28 * 3.6)
end
function Units.kilometres(studs: number): number
	return studs * 0.28 / 1000
end
return Units
