--!strict
local Nav = require("./RoadNavigation")
local Traffic = {}
export type Route = { points: { Nav.Point }, lengths: { number }, length: number }
function Traffic.route(center: { Nav.Point }, reverse: boolean): Route
	local raw: { Nav.Point } = {}
	for i = 1, #center - 1 do
		table.insert(raw, center[if reverse then #center - i else i])
	end
	local points: { Nav.Point } = {}
	for i, p in raw do
		local before, after = raw[if i == 1 then #raw else i - 1], raw[if i == #raw then 1 else i + 1]
		local l1, l2 = Nav.distance(before, p), Nav.distance(p, after)
		local n1x, n1z = -(p.z - before.z) / l1, (p.x - before.x) / l1
		local n2x, n2z = -(after.z - p.z) / l2, (after.x - p.x) / l2
		local nx, nz = n1x + n2x, n1z + n2z
		local m = math.sqrt(nx * nx + nz * nz)
		if m < 0.01 then
			nx, nz = n2x, n2z
		else
			nx, nz = nx / m, nz / m
		end
		local scale = math.min(9, (1.8 / 0.28) / math.max(0.5, nx * n2x + nz * n2z))
		table.insert(points, { x = p.x + nx * scale, z = p.z + nz * scale })
	end
	table.insert(points, points[1])
	local lengths = { 0 }
	local total = 0
	for i = 1, #points - 1 do
		total += Nav.distance(points[i], points[i + 1])
		table.insert(lengths, total)
	end
	return { points = points, lengths = lengths, length = total }
end
function Traffic.sample(route: Route, progress: number): Nav.Point
	progress %= route.length
	for i = 1, #route.points - 1 do
		if progress <= route.lengths[i + 1] then
			local a, b = route.points[i], route.points[i + 1]
			local t = (progress - route.lengths[i]) / (route.lengths[i + 1] - route.lengths[i])
			return { x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t }
		end
	end
	return route.points[1]
end
function Traffic.project(route: Route, p: Nav.Point): number
	local best, progress = math.huge, 0
	for i = 1, #route.points - 1 do
		local a, b = route.points[i], route.points[i + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local t = math.clamp(((p.x - a.x) * dx + (p.z - a.z) * dz) / (dx * dx + dz * dz), 0, 1)
		local d = (p.x - a.x - dx * t) ^ 2 + (p.z - a.z - dz * t) ^ 2
		if d < best then
			best = d
			progress = route.lengths[i] + (route.lengths[i + 1] - route.lengths[i]) * t
		end
	end
	return progress % route.length
end
function Traffic.path(route: Route, progress: number): { Nav.Point }
	local path = { Traffic.sample(route, progress) }
	for round = 0, 1 do
		for i = 2, #route.points do
			local d = route.lengths[i] + round * route.length - progress
			if d > 0 then
				table.insert(path, route.points[i])
				if d > 180 then
					return path
				end
			end
		end
	end
	return path
end
function Traffic.lookahead(speed: number): number
	return math.clamp(22 + math.abs(speed) * 0.2, 22, 30)
end
function Traffic.cornerSpeed(path: { Nav.Point }, cruise: number?): number
	local limit = cruise or 42
	for _, distance in { 4, 10, 18, 30, 45, 65 } do
		local a, b, c =
			Nav.ahead(path, math.max(0, distance - 8)),
			Nav.ahead(path, distance),
			Nav.ahead(path, distance + 8)
		if a and b and c then
			local ab, bc = Nav.distance(a, b), Nav.distance(b, c)
			if ab > 0.1 and bc > 0.1 then
				local angle = math.acos(
					math.clamp(((b.x - a.x) * (c.x - b.x) + (b.z - a.z) * (c.z - b.z)) / (ab * bc), -1, 1)
				)
				if angle > 0.08 then
					local bend = math.clamp(math.sqrt(9 * 8 / angle), 6, 42)
					limit = math.min(limit, math.sqrt(bend * bend + 2 * 14 * math.max(0, distance - 24)))
				end
			end
		end
	end
	return limit
end
function Traffic.followSpeed(gap: number, cruise: number?): number
	return math.clamp((gap - 28) / 1.5, 0, cruise or 42)
end
function Traffic.stopSpeed(distance: number): number
	return math.sqrt(2 * 24 * math.max(0, distance - 20))
end
return Traffic
