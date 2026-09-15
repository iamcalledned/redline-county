--!strict
local HeadlightMath = {}
export type Tuning = {
	LowRange: number,
	HighRange: number,
	Angle: number,
	Brightness: number,
	FullBeamKmh: number,
}

function HeadlightMath.beam(kmh: number, tune: Tuning): (number, number, number)
	local blend = math.clamp(kmh / tune.FullBeamKmh, 0, 1)
	-- Smoothstep avoids sudden visible changes near the endpoints.
	blend = blend * blend * (3 - 2 * blend)
	return tune.LowRange + (tune.HighRange - tune.LowRange) * blend, tune.Angle, tune.Brightness
end

return HeadlightMath
