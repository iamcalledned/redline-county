--!strict
-- Engine-independent road routing. Coordinates are Roblox X/Z studs.
local Nav = {}
export type Point = { x: number, z: number }
export type Node = { x: number, z: number, links: { number } }
export type Graph = { Node }
function Nav.distance(a: Point, b: Point): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end
local function linked(graph: Graph, a: number, b: number): boolean
	return table.find(graph[a].links, b) ~= nil
end
function Nav.project(graph: Graph, point: Point): (Point, number, number, number)
	local best, aBest, bBest, gap = point, 1, 1, math.huge
	for a, node in graph do
		for _, b in node.links do
			local other = graph[b]
			local dx, dz = other.x - node.x, other.z - node.z
			local length2 = dx * dx + dz * dz
			if length2 > 0 then
				local t = math.clamp(((point.x - node.x) * dx + (point.z - node.z) * dz) / length2, 0, 1)
				local p = { x = node.x + dx * t, z = node.z + dz * t }
				local d = Nav.distance(p, point)
				if d < gap then
					best, aBest, bBest, gap = p, a, b, d
				end
			end
		end
	end
	return best, aBest, bBest, gap
end
-- A small priority queue avoids scanning every known node for every expansion.
type Entry = { node: number, cost: number }
local function push(heap: { Entry }, entry: Entry)
	local i = #heap + 1
	while i > 1 do
		local parent = math.floor(i / 2)
		if heap[parent].cost <= entry.cost then
			break
		end
		heap[i] = heap[parent]
		i = parent
	end
	heap[i] = entry
end
local function pop(heap: { Entry }): Entry
	local result = heap[1]
	local last = table.remove(heap) :: Entry
	if #heap > 0 then
		local i = 1
		while i * 2 <= #heap do
			local child = i * 2
			if child < #heap and heap[child + 1].cost < heap[child].cost then
				child += 1
			end
			if last.cost <= heap[child].cost then
				break
			end
			heap[i] = heap[child]
			i = child
		end
		heap[i] = last
	end
	return result
end
function Nav.route(graph: Graph, start: Point, finish: Point): { Point }
	local first, a, b = Nav.project(graph, start)
	local last, c, d = Nav.project(graph, finish)
	if
		a == c
		and b == d
		and (Nav.distance(graph[a], first) <= Nav.distance(graph[a], last) or linked(graph, b, a))
	then
		return { first, last }
	end
	local distance: { [number]: number } = { [b] = Nav.distance(first, graph[b]) }
	if linked(graph, b, a) or Nav.distance(first, graph[a]) < 0.001 then
		distance[a] = Nav.distance(first, graph[a])
	end
	local previous: { [number]: number } = {}
	local visited: { [number]: boolean } = {}
	local queue: { Entry } = {}
	for node, cost in distance do
		push(queue, { node = node, cost = cost })
	end
	while #queue > 0 do
		local current = pop(queue)
		local best, cost = current.node, current.cost
		if visited[best] then
			continue
		end
		visited[best] = true
		for _, nextNode in graph[best].links do
			local candidate = cost + Nav.distance(graph[best], graph[nextNode])
			if candidate < (distance[nextNode] or math.huge) then
				distance[nextNode], previous[nextNode] = candidate, best
				push(queue, { node = nextNode, cost = candidate })
			end
		end
	end
	local ending = c
	local cost = (distance[c] or math.huge) + Nav.distance(graph[c], last)
	if linked(graph, d, c) or Nav.distance(last, graph[d]) < 0.001 then
		local other = (distance[d] or math.huge) + Nav.distance(graph[d], last)
		if other < cost then
			ending, cost = d, other
		end
	end
	if cost == math.huge then
		return {}
	end
	local reverse: { Point } = {}
	local cursor: number? = ending
	while cursor do
		table.insert(reverse, { x = graph[cursor].x, z = graph[cursor].z })
		cursor = previous[cursor]
	end
	local result = { first }
	for i = #reverse, 1, -1 do
		if Nav.distance(result[#result], reverse[i]) > 0.05 then
			table.insert(result, reverse[i])
		end
	end
	if Nav.distance(result[#result], last) > 0.05 then
		table.insert(result, last)
	end
	return result
end
-- Advance a cached route with the vehicle between graph replans. Steering at a
-- fixed old look-ahead point can otherwise turn the car back toward passed nodes.
function Nav.remaining(path: { Point }, position: Point): { Point }
	local best, first, gap = 1, path[1], math.huge
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local dx, dz = b.x - a.x, b.z - a.z
		local length2 = dx * dx + dz * dz
		if length2 > 0 then
			local t = math.clamp(((position.x - a.x) * dx + (position.z - a.z) * dz) / length2, 0, 1)
			local point = { x = a.x + dx * t, z = a.z + dz * t }
			local distance = Nav.distance(position, point)
			if distance < gap then
				best, first, gap = i, point, distance
			end
		end
	end
	if not first then
		return {}
	end
	local result = { first }
	for i = best + 1, #path do
		table.insert(result, path[i])
	end
	return result
end
function Nav.ahead(path: { Point }, distance: number): Point?
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local length = Nav.distance(a, b)
		if length > 0 and distance <= length then
			local t = distance / length
			return { x = a.x + (b.x - a.x) * t, z = a.z + (b.z - a.z) * t }
		end
		distance -= length
	end
	return path[#path]
end
-- Pure-pursuit steering, with a slower corner approach and braking before reverse.
function Nav.cornerSpeed(path: { Point }, cruise: number?): number
	local limit, distance = cruise or 78, 0
	for i = 1, #path - 2 do
		local a, b, c = path[i], path[i + 1], path[i + 2]
		local ab, bc = Nav.distance(a, b), Nav.distance(b, c)
		distance += ab
		if ab > 0.1 and bc > 0.1 then
			local cosine = ((b.x - a.x) * (c.x - b.x) + (b.z - a.z) * (c.z - b.z)) / (ab * bc)
			if cosine < math.cos(math.rad(25)) then
				-- Brake before a junction, using distance to the bend and a conservative
				-- deceleration budget. Merely steering harder after arrival cuts corners.
				limit = math.min(limit, math.sqrt(14 * 14 + 2 * 24 * math.max(0, distance - 32)))
			end
		end
	end
	return limit
end
function Nav.controls(
	lateral: number,
	forward: number,
	speed: number,
	wheelbase: number,
	speedLimit: number?
): (number, number)
	local angle = math.atan2(lateral, forward)
	local steering = math.atan(2 * wheelbase * lateral / math.max(16, lateral * lateral + forward * forward))
	local steer = math.clamp(steering / (math.rad(32) / (1 + math.abs(speed) / 38)), -1, 1)
	if forward < 0 then
		steer = if lateral < 0 then -1 else 1
	end
	local cruise = math.max(78, speedLimit or 78)
	local target = math.min(speedLimit or 78, math.clamp(cruise / (1 + math.abs(angle) * 5), 12, cruise))
	return if speed > target + 3 then -1 elseif speed < target - 2 then 1 else 0, steer
end
return Nav
