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

-- The native light has a short engine range. The road overlay provides a separate,
-- bounded driving preview; never smooth its position or delay its speed response.
export type RoadTuning = { RoadMinRange: number, RoadMaxRange: number, PreviewSeconds: number }
function HeadlightMath.roadReach(studsPerSecond: number, tune: RoadTuning): number
	return math.clamp(
		tune.RoadMinRange + math.abs(studsPerSecond) * tune.PreviewSeconds,
		tune.RoadMinRange,
		tune.RoadMaxRange
	)
end
function HeadlightMath.sampleDistance(reach: number, step: number, steps: number): number
	-- Concentrate samples near the bumper, including when an obstacle shortens the beam.
	return math.max(0, reach) * (math.clamp(step / steps, 0, 1) ^ 2)
end
-- Rendered asphalt/paint is above the collidable terrain on this authored flat map.
HeadlightMath.SurfaceLift = 0.4
return HeadlightMath
