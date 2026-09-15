--!strict
local Nav = require("./RoadNavigation")
local Tactics = {}
function Tactics.target(graph: Nav.Graph, last: Nav.Point, velocity: Nav.Point, role: string): Nav.Point
	local lead = if role == "intercept" then 3 else 0
	local speed = math.sqrt(velocity.x ^ 2 + velocity.z ^ 2)
	local scale = if speed > 0 then math.min(lead, 180 / speed) else 0
	local projected = Nav.project(graph, { x = last.x + velocity.x * scale, z = last.z + velocity.z * scale })
	return projected
end
function Tactics.spawnSafe(distance: number, visible: boolean, occupied: boolean): boolean
	return distance >= 180 and not visible and not occupied
end
return Tactics
