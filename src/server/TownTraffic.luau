--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Vehicle = require(script.Parent.Vehicle)
local Players = game:GetService("Players")
local Graph = require(Shared.RoadGraph).Nodes
local Nav = require(Shared.RoadNavigation)
local Math = require(Shared.TownTrafficMath)
local Map = require(Shared.TownMap)
local Progression = require(Shared.Progression)
local TownTraffic = {}
local folder = Instance.new("Folder")
folder.Name = "TownTraffic"
folder.Parent = workspace
local routes: { Math.Route } = {}
for _, source in { Map.Course, Map.Route, Map.ServiceRoute } do
	local points: { Nav.Point } = {}
	for _, p in source do
		table.insert(points, { x = p.X, z = p.Z })
	end
	table.insert(routes, Math.route(points, false))
	table.insert(routes, Math.route(points, true))
end
-- Reserve conflict zones briefly, in arrival order, to prevent opposing queues
-- from both entering a junction and then waiting for one another forever.
local reservations: { [number]: { id: number, expires: number } } = {}
type Driver = {
	id: number,
	car: Vehicle.Car,
	route: number,
	progress: number,
	police: boolean,
	stalled: number,
	reverseUntil: number,
	rejoin: boolean,
	throttle: number,
	steer: number,
	immobile: number,
}
local drivers: { Driver } = {}
local demands: { [Player]: string? } = {}
local serial, spawnClock, thinkClock = 0, 0, 0
local function horizontal(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end
function TownTraffic.demand(player: Player, id: string?)
	demands[player] = id
end
function TownTraffic.population(): number
	local n = 0
	for _, d in drivers do
		if not d.police then
			n += 1
		end
	end
	return n
end
local function demandCount(): number
	local count = 6
	for _, id in demands do
		local d = Progression.difficulty(id)
		if d then
			count = math.max(count, d.Traffic)
		end
	end
	return count
end
local function policeStyle(car: Vehicle.Car)
	car.Model:SetAttribute("Police", true)
	car.Body.Color = Color3.fromRGB(24, 32, 43)
	if car.Model:GetAttribute("BundledVehicle") then
		return
	end
	for _, x in { -1.5, 1.5 } do
		local lamp = Instance.new("Part")
		lamp.Name = if x < 0 then "PoliceRed" else "PoliceBlue"
		lamp.Size = Vector3.new(2.6, 0.5, 1)
		lamp.CFrame = car.Body.CFrame * CFrame.new(x, 2.9, 0)
		lamp.Color = if x < 0 then Color3.fromRGB(255, 55, 65) else Color3.fromRGB(65, 140, 255)
		lamp.Material = Enum.Material.Neon
		lamp.Massless = true
		lamp.CanCollide = false
		lamp.CanQuery = false
		lamp.CanTouch = false
		lamp.Parent = car.Model
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = car.Body, lamp, lamp
	end
end
function TownTraffic.policeCount(): number
	local count = 0
	for _, d in drivers do
		if d.police then
			count += 1
		end
	end
	local active = workspace:FindFirstChild("PolicePatrols")
	return count + (if active then #active:GetChildren() else 0)
end
function TownTraffic.takePatrol(position: Vector3): Vehicle.Car?
	local best, dist = nil, if TownTraffic.policeCount() >= 8 then math.huge else 360
	for i, d in drivers do
		local gap = horizontal(d.car.Body.Position, position)
		if d.police and gap < dist then
			best, dist = i, gap
		end
	end
	if best then
		local driver = table.remove(drivers, best) :: Driver
		return driver.car
	end
	return nil
end
function TownTraffic.returnPatrol(car: Vehicle.Car)
	if not car.Model.Parent then
		return
	end
	serial += 1
	local p = { x = car.Body.Position.X, z = car.Body.Position.Z }
	local best, gap = 1, math.huge
	for i, route in routes do
		local distance = Nav.distance(p, Math.sample(route, Math.project(route, p)))
		if distance < gap then
			best, gap = i, distance
		end
	end
	car.Model.Parent = folder
	car.Model:SetAttribute("TargetUserId", nil)
	car.Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	car.Tune.TopSpeed = 68
	car.Tune.Acceleration = 9
	car.Ray.FilterDescendantsInstances = { folder, workspace.Vehicles, workspace.PolicePatrols }
	table.insert(drivers, {
		id = serial,
		car = car,
		route = best,
		progress = Math.project(routes[best], p),
		police = true,
		stalled = 0,
		reverseUntil = 0,
		rejoin = gap > 14,
		throttle = 0,
		steer = 0,
		immobile = 0,
	})
end
local function spawn(police: boolean): boolean
	serial += 1
	local counts = { 0, 0, 0, 0, 0, 0 }
	for _, d in drivers do
		counts[d.route] += 1
	end
	local routeIndex = if police then 3 + serial % 2 else 1 + serial % #routes
	for i, count in counts do
		if not police and count < counts[routeIndex] then
			routeIndex = i
		end
	end
	local route = routes[routeIndex]
	for attempt = 1, 30 do
		local homeAlong = Math.project(route, { x = Map.Garage.X, z = Map.Garage.Z })
		local progress = (homeAlong + serial * 95 + attempt * 67) % route.length
		local p, q = Math.sample(route, progress), Math.sample(route, progress + 8)
		local v = Vector3.new(p.x, 34.25, p.z)
		local clear = horizontal(v, Map.Garage) > 120
		for _, model in workspace.Vehicles:GetChildren() do
			if
				model:IsA("Model")
				and model.PrimaryPart
				and horizontal(v, model.PrimaryPart.Position) < 100
			then
				clear = false
			end
		end
		for _, d in drivers do
			if horizontal(v, d.car.Body.Position) < 65 then
				clear = false
			end
		end
		local cf = CFrame.lookAt(v, Vector3.new(q.x, v.Y, q.z))
		local overlap = OverlapParams.new()
		overlap.RespectCanCollide = true
		if
			clear
			and #workspace:GetPartBoundsInBox(cf + Vector3.new(0, 1.5, 0), Vector3.new(8, 3, 21), overlap)
				== 0
		then
			local kind = if not police and serial % 4 == 0 then "Pickup" else "Electric"
			local car = Vehicle.create(folder, nil, kind, cf, if police then "Police" else kind)
			car.Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
			car.Model:SetAttribute("Police", police)
			car.Model:SetAttribute("Civilian", not police)
			car.Model.Name = if police then "TownPatrol_" .. serial else "Civilian_" .. serial
			car.Tune = table.clone(car.Tune)
			car.Tune.TopSpeed = 68
			car.Tune.Acceleration = 9
			for _, part in car.Model:GetDescendants() do
				if part:IsA("BasePart") then
					part.CollisionGroup = if police then "Police" else "Civilian"
				end
			end
			car.Ray.FilterDescendantsInstances = { folder, workspace.Vehicles, workspace.PolicePatrols }
			if police then
				policeStyle(car)
			else
				local colors = {
					Color3.fromRGB(134, 155, 158),
					Color3.fromRGB(188, 179, 157),
					Color3.fromRGB(143, 64, 48),
					Color3.fromRGB(55, 63, 81),
				}
				car.Body.Color = colors[serial % 4 + 1]
			end
			table.insert(drivers, {
				id = serial,
				car = car,
				route = routeIndex,
				progress = progress,
				police = police,
				stalled = 0,
				reverseUntil = 0,
				rejoin = false,
				throttle = 0,
				steer = 0,
				immobile = 0,
			})
			return true
		end
	end
	return false
end
local function unseen(d: Driver): boolean
	for _, player in Players:GetPlayers() do
		local root = if player.Character then player.Character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") and horizontal(root.Position, d.car.Body.Position) < 800 then
			return false
		end
	end
	for _, model in workspace.Vehicles:GetChildren() do
		if
			model:IsA("Model")
			and model.PrimaryPart
			and horizontal(model.PrimaryPart.Position, d.car.Body.Position) < 220
		then
			return false
		end
	end
	return true
end
function TownTraffic.step(dt: number)
	local now = os.clock()
	spawnClock -= dt
	thinkClock -= dt
	local think = thinkClock <= 0
	if think then
		thinkClock = 0.1
	end
	local civilians, police = 0, 0
	for _, d in drivers do
		if d.police then
			police += 1
		else
			civilians += 1
		end
	end
	if spawnClock <= 0 then
		spawnClock = 0.35
		if police < 2 and TownTraffic.policeCount() < 8 then
			spawn(true)
		elseif civilians < demandCount() then
			spawn(false)
		end
	end
	for i = #drivers, 1, -1 do
		local d = drivers[i]
		local car = d.car
		local body = car.Body
		local route = routes[d.route]
		if
			(
				civilians > demandCount() and not d.police
				or d.police and police > 2
				or d.immobile > 60
				or body.Position.Y < 0
			) and unseen(d)
		then
			car.Model:Destroy()
			table.remove(drivers, i)
			if not d.police then
				civilians -= 1
			else
				police -= 1
			end
			continue
		end
		if think then
			d.progress = Math.project(route, { x = body.Position.X, z = body.Position.Z })
			local speed = body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector)
			local path = Math.path(route, d.progress)
			local aim = Math.sample(route, d.progress + Math.lookahead(speed))
			local target = body.CFrame:PointToObjectSpace(Vector3.new(aim.x, body.Position.Y, aim.z))
			local cruise = if d.route <= 2 then 64 elseif d.route <= 4 then 42 else 32
			local limit = Math.cornerSpeed(path, cruise)
			for _, other in drivers do
				if other ~= d and other.route == d.route and not other.rejoin then
					limit = math.min(
						limit,
						Math.followSpeed((other.progress - d.progress) % route.length, cruise)
					)
				end
			end
			for junction, position in Map.Junctions do
				local delta = body.CFrame:PointToObjectSpace(position)
				if delta.Z < 8 and delta.Z > -75 and math.abs(delta.X) < 28 then
					local lock = reservations[junction]
					if lock and lock.expires > now and lock.id ~= d.id then
						limit = math.min(limit, Math.stopSpeed(-delta.Z))
					elseif delta.Z > -42 then
						reservations[junction] = { id = d.id, expires = now + 2.5 }
					end
				end
			end
			if d.rejoin then
				local here = { x = body.Position.X, z = body.Position.Z }
				local lane = Math.sample(route, d.progress)
				if Nav.distance(here, lane) < 14 then
					d.rejoin = false
				else
					local plan = Nav.route(Graph, here, lane)
					local join = Nav.ahead(plan, 18)
					if join then
						target = body.CFrame:PointToObjectSpace(Vector3.new(join.x, body.Position.Y, join.z))
						limit = math.min(limit, 20)
					else
						limit = 0
					end
				end
			end
			local throttle, steer = Nav.controls(target.X, -target.Z, speed, car.Wheelbase or 10.4, limit)
			local ray = RaycastParams.new()
			ray.FilterDescendantsInstances = { car.Model }
			ray.RespectCanCollide = true
			ray.CollisionGroup = if d.police then "Police" else "Civilian"
			local reach = math.clamp(math.abs(speed) * 1.2, 12, 55)
			local origin = body.Position
			local hit: RaycastResult? = nil
			for _, along in { 8, 18, reach } do
				if along > reach then
					continue
				end
				local p = Math.sample(route, d.progress + along)
				local destination = if d.rejoin
					then origin + body.CFrame.LookVector * along
					else Vector3.new(p.x, origin.Y, p.z)
				local delta = destination - origin
				if delta.Magnitude > 0.1 then
					hit = workspace:Blockcast(
						CFrame.lookAt(origin, destination),
						Vector3.new(body.Size.X * 0.85, 1, body.Size.Z * 0.65),
						delta,
						ray
					)
					if hit then
						break
					end
				end
				origin = destination
			end
			car.Model:SetAttribute("TrafficBlocked", hit ~= nil)
			if car.Model:GetAttribute("TrafficBlocked") or limit < 1 then
				throttle = if speed > 1 then -1 else 0
			end
			local staticBlock = hit ~= nil
				and not hit.Instance:IsDescendantOf(folder)
				and not hit.Instance:IsDescendantOf(workspace.Vehicles)
				and not hit.Instance:IsDescendantOf(workspace.PolicePatrols)
			-- A crossed or head-on stationary car is a blockage, not a normal queue.
			local crossedCar = hit ~= nil
				and hit.Instance.AssemblyLinearVelocity.Magnitude < 1
				and hit.Instance.CFrame.LookVector:Dot(body.CFrame.LookVector) < 0.65
			d.stalled = if math.abs(speed) < 1 and (throttle > 0 or staticBlock or crossedCar)
				then d.stalled + 0.1
				else 0
			d.immobile = if math.abs(speed) < 1 then d.immobile + 0.1 else 0
			if d.stalled > 4 then
				d.reverseUntil = now + 1.25
				d.stalled = 0
			end
			if now < d.reverseUntil then
				local rear = RaycastParams.new()
				rear.FilterDescendantsInstances = { car.Model }
				rear.RespectCanCollide = true
				local obstruction = workspace:Blockcast(
					body.CFrame,
					Vector3.new(body.Size.X, 1, body.Size.Z),
					-body.CFrame.LookVector * 14,
					rear
				)
				throttle = if obstruction then 0 else -0.4
				steer = -steer
			end
			d.throttle, d.steer = throttle, steer
		end
		Vehicle.step(car, math.min(dt, 0.05), d.throttle, d.steer, false, false)
	end
	if think then
		workspace:SetAttribute("TownTrafficCount", TownTraffic.population())
		workspace:SetAttribute("TownTrafficTarget", demandCount())
		workspace:SetAttribute("TownPatrolCount", police)
	end
end
return TownTraffic
