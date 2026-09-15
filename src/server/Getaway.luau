--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Vehicle = require(script.Parent.Vehicle)
local Nav = require(ReplicatedStorage.Shared.RoadNavigation)
local Graph = require(ReplicatedStorage.Shared.RoadGraph).Nodes
local Map = require(ReplicatedStorage.Shared.TownMap)
local Rules = require(ReplicatedStorage.Shared.GetawayRules)
local Contracts = require(ReplicatedStorage.Shared.Contracts)
local Workshop = require(script.Parent.Workshop)
local TownTraffic = require(script.Parent.TownTraffic)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Variants = require(ReplicatedStorage.Shared.MissionVariants)
local Tactics = require(ReplicatedStorage.Shared.PoliceTactics)
local Roadblock = require(script.Parent.Roadblock)
local Metrics = require(script.Parent.PlaytestMetrics)
local Getaway = {}
type Contract = typeof(Contracts[1])
local function checkpoint(contract: Contract, index: number): Vector3
	return (if contract.Parkway then Map.Course else Map.Route)[contract.Checkpoints[index]]
end
type Unit = {
	car: Vehicle.Car,
	lastKnown: Vector3,
	plan: { Nav.Point },
	replan: number,
	stalled: number,
	reverseUntil: number,
	alertUntil: number,
	role: string,
	lastVelocity: Vector3,
	lastSeen: number,
	searchNode: number,
}
type Job = {
	owner: Player,
	difficulty: string,
	car: Vehicle.Car,
	contract: Contract,
	rules: Rules.State,
	cops: { Unit },
	nextSpawn: number,
	grace: number,
	clock: number,
	policeReady: boolean,
	free: boolean?,
	variant: Variants.State,
	started: number,
	dispatch: Vector3,
	block: Roadblock.Block?,
	blockTried: boolean,
}
local jobs: { [Player]: Job } = {}
local patrols = Instance.new("Folder")
patrols.Name = "PolicePatrols"
patrols.Parent = workspace
local function point(v: Vector3): Nav.Point
	return { x = v.X, z = v.Z }
end
local function vector(p: Nav.Point): Vector3
	return Vector3.new(p.x, 32, p.z)
end
local function distance(a: Vector3, b: Vector3): number
	return ((a - b) * Vector3.new(1, 0, 1)).Magnitude
end
local function dispose(job: Job)
	Roadblock.clear(job.owner, job.block)
	job.block = nil
	TownTraffic.demand(job.owner, nil)
	for _, unit in job.cops do
		TownTraffic.returnPatrol(unit.car)
	end
	table.clear(job.cops)
end
function Getaway.active(player: Player): boolean
	local job = jobs[player]
	return job ~= nil and Rules.active(job.rules)
end
-- Read the server's finished run, never a client-supplied contract or result.
function Getaway.retryInfo(player: Player): (string?, string?)
	local job = jobs[player]
	if not job or not Rules.recoverable(job.rules) then
		return nil, nil
	end
	return if job.free then "first" else job.contract.Id, job.difficulty
end
function Getaway.cancel(player: Player, reason: string)
	local job = jobs[player]
	if job then
		dispose(job)
		if Rules.active(job.rules) then
			job.rules.phase = "failed"
			player:SetAttribute("MissionPhase", "failed")
			player:SetAttribute("MissionMessage", reason)
			player:SetAttribute("Wanted", 0)
			player:SetAttribute("MissionTarget", nil)
			player:SetAttribute("MissionChoice", false)
		end
	end
end
function Getaway.remove(player: Player)
	Getaway.cancel(player, "Left game")
	jobs[player] = nil
end
local function visible(unit: Unit, target: Vehicle.Car, player: Player): boolean
	if distance(unit.car.Body.Position, target.Body.Position) > 260 then
		return false
	end
	local ray = RaycastParams.new()
	ray.FilterDescendantsInstances = { patrols, workspace.Vehicles, player.Character :: Model }
	ray.RespectCanCollide = true
	local origin = unit.car.Body.Position + Vector3.new(0, 2, 0)
	return workspace:Raycast(origin, target.Body.Position + Vector3.new(0, 2, 0) - origin, ray) == nil
end
local function spawnUnit(player: Player, job: Job): boolean
	local body = job.car.Body
	local patrol = TownTraffic.takePatrol(body.Position)
	if patrol then
		patrol.Model.Parent = patrols
		patrol.Model:SetAttribute("TargetUserId", player.UserId)
		patrol.Tune.TopSpeed = 125
		patrol.Tune.Acceleration = 18
		patrol.Ray.FilterDescendantsInstances = { patrols, workspace.Vehicles, workspace.TownTraffic }
		table.insert(job.cops, {
			car = patrol,
			lastKnown = job.dispatch,
			lastVelocity = Vector3.zero,
			lastSeen = os.clock(),
			searchNode = 0,
			role = if #job.cops == 0 then "follow" else "intercept",
			plan = {},
			replan = 0,
			stalled = 0,
			reverseUntil = 0,
			alertUntil = os.clock() + 1,
		})
		job.policeReady = true
		return true
	end
	if TownTraffic.policeCount() >= 8 then
		return false
	end
	local candidates: { { node: Nav.Node, score: number } } = {}
	for _, node in Graph do
		local v = vector(node)
		local dist = distance(v, body.Position)
		if dist > 180 and dist < 1100 and distance(v, Map.Garage) > 180 and #node.links > 0 then
			-- Prefer behind the driver and never create a roadblock directly in their path.
			local score = dist + math.max(0, (v - body.Position):Dot(body.CFrame.LookVector)) * 3
			table.insert(candidates, { node = node, score = score })
		end
	end
	table.sort(candidates, function(a, b)
		return a.score < b.score
	end)
	for _, candidate in candidates do
		local node = candidate.node
		local position = vector(node) + Vector3.new(0, 2.25, 0)
		local clear = true
		for _, other in workspace.Vehicles:GetChildren() do
			if
				other:IsA("Model")
				and other.PrimaryPart
				and distance(other.PrimaryPart.Position, position) < 100
			then
				clear = false
				break
			end
		end
		for _, cop in patrols:GetChildren() do
			if cop:IsA("Model") and cop.PrimaryPart and distance(cop.PrimaryPart.Position, position) < 70 then
				clear = false
				break
			end
		end
		local sight = RaycastParams.new()
		sight.FilterDescendantsInstances = { workspace.Vehicles, patrols, workspace.TownTraffic }
		sight.RespectCanCollide = true
		local inFront = (position - body.Position).Unit:Dot(body.CFrame.LookVector) > -0.3
		local visibleSpawn = (inFront or distance(position, body.Position) < 350)
			and workspace:Raycast(body.Position + Vector3.new(0, 3, 0), position - body.Position, sight)
				== nil
		if not Tactics.spawnSafe(distance(position, body.Position), visibleSpawn, not clear) then
			continue
		end
		local path = Nav.route(Graph, point(position), point(job.dispatch))
		local aim = Nav.ahead(path, 18)
		if not clear or not aim or #path < 2 then
			continue
		end
		local cf = CFrame.lookAt(position, Vector3.new(aim.x, position.Y, aim.z))
		local overlap = OverlapParams.new()
		overlap.RespectCanCollide = true
		if #workspace:GetPartBoundsInBox(cf + Vector3.new(0, 1.5, 0), Vector3.new(8, 3, 18), overlap) > 0 then
			continue
		end
		local car = Vehicle.create(patrols, nil, "Electric", cf)
		car.Model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
		car.Model.Name = "Patrol_" .. player.UserId .. "_" .. (#job.cops + 1)
		car.Model:SetAttribute("TargetUserId", player.UserId)
		car.Tune = table.clone(car.Tune)
		car.Tune.TopSpeed = 125
		car.Tune.Acceleration = 18
		car.Body.Color = Color3.fromRGB(25, 33, 48)
		for _, p in car.Model:GetDescendants() do
			if p:IsA("BasePart") then
				p.CollisionGroup = "Police"
			end
		end
		car.Ray.FilterDescendantsInstances =
			{ patrols, workspace.Vehicles, workspace.HighwayTraffic, workspace.TownTraffic }
		local lampPositions: { number } = if car.Model:GetAttribute("BundledVehicle")
			then {}
			else { -1.5, 1.5 }
		for _, x in lampPositions do
			local lamp = Instance.new("Part")
			lamp.Name = if x < 0 then "PoliceRed" else "PoliceBlue"
			lamp.Size = Vector3.new(2.6, 0.5, 1)
			lamp.CFrame = cf * CFrame.new(x, 2.9, 0)
			lamp.Color = if x < 0 then Color3.fromRGB(255, 55, 65) else Color3.fromRGB(65, 140, 255)
			lamp.Material = Enum.Material.Neon
			lamp.Massless, lamp.CanCollide, lamp.CanTouch, lamp.CanQuery = true, false, false, false
			lamp.Parent = car.Model
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1, weld.Parent = car.Body, lamp, lamp
		end
		local badge = Instance.new("BillboardGui")
		badge.Name = "PoliceBadge"
		badge.Size = UDim2.fromOffset(90, 25)
		badge.StudsOffset = Vector3.new(0, 5, 0)
		badge.MaxDistance = 160
		badge.Parent = car.Body
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 0.25
		label.BackgroundColor3 = Color3.fromRGB(18, 28, 48)
		label.Text = "POLICE"
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 14
		label.Parent = badge
		table.insert(job.cops, {
			car = car,
			lastKnown = job.dispatch,
			lastVelocity = Vector3.zero,
			lastSeen = os.clock(),
			searchNode = 0,
			role = if #job.cops == 0 then "follow" else "intercept",
			plan = path,
			replan = 0,
			stalled = 0,
			reverseUntil = 0,
			alertUntil = os.clock() + 3,
		})
		job.policeReady = true
		return true
	end
	return false
end
function Getaway.start(player: Player, car: Vehicle.Car, id: string, difficulty: string): boolean
	if Getaway.active(player) or not Progression.difficulty(difficulty) then
		return false
	end
	local contract: Contract? = nil
	for _, option in Contracts do
		if option.Id == id then
			contract = option
			break
		end
	end
	if not contract then
		return false
	end
	if jobs[player] then
		dispose(jobs[player])
	end
	Metrics.mark(player, "job", { id = id, difficulty = difficulty })
	if (player:GetAttribute("GetawayWins") :: number? or 0) > 0 then
		Metrics.mark(player, "second_job", nil, true)
	end
	TownTraffic.demand(player, difficulty)
	jobs[player] = {
		owner = player,
		difficulty = difficulty,
		car = car,
		contract = contract,
		rules = Rules.new(#contract.Checkpoints, contract.Seconds, contract.Heat),
		cops = {},
		nextSpawn = 0,
		grace = os.clock() + 3,
		clock = 0,
		policeReady = false,
		variant = Variants.new(
			contract.Mode,
			(car.Model:GetAttribute("Damage") :: number?) or 0,
			contract.Heat
		),
		started = os.clock(),
		dispatch = car.Body.Position,
		blockTried = false,
	}
	player:SetAttribute("MissionChoice", false)
	player:SetAttribute("CargoQuality", if contract.Mode == "cargo" then 100 else nil)
	player:SetAttribute("MissionDifficulty", difficulty)
	player:SetAttribute("MissionPhase", "pickup")
	player:SetAttribute("MissionName", contract.Name)
	player:SetAttribute(
		"MissionMessage",
		"Follow the cyan route to the gold pickup. Police respond when you collect it."
	)
	player:SetAttribute("MissionTarget", checkpoint(contract, 1))
	player:SetAttribute("Wanted", 0)
	player:SetAttribute("MissionRemaining", contract.Seconds)
	return true
end
function Getaway.choose(player: Player, choice: string)
	local job = jobs[player]
	if not job or not Rules.active(job.rules) or not Variants.choose(job.variant, choice) then
		return
	end
	job.rules.phase = if choice == "continue" then "run" else "escape"
	job.rules.escape = 0
	job.clock = 0
	player:SetAttribute("MissionChoice", false)
	player:SetAttribute(
		"MissionMessage",
		if choice == "continue"
			then "Another pickup. Police pressure increased!"
			else "Break sight, then bring your haul home."
	)
end
function Getaway.provoke(player: Player, car: Vehicle.Car)
	if not Getaway.start(player, car, "first", "light") then
		return
	end
	local job = jobs[player]
	job.free = true
	job.rules.phase = "escape"
	job.rules.remaining = 180
	player:SetAttribute("MissionPhase", "escape")
	player:SetAttribute("MissionName", "POLICE PURSUIT")
	player:SetAttribute("MissionMessage", "Reckless driving spotted. Break police sight for 10 seconds.")
	player:SetAttribute("MissionTarget", nil)
	player:SetAttribute("Wanted", 1)
end
local function steerUnit(unit: Unit, car: Vehicle.Car, seen: boolean, dt: number, now: number)
	local body = unit.car.Body
	if seen then
		unit.lastKnown = car.Body.Position
		unit.lastVelocity = car.Body.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		unit.lastSeen = now
		unit.searchNode = 0
	end
	if now >= unit.replan then
		local target = Tactics.target(
			Graph,
			point(unit.lastKnown),
			point(unit.lastVelocity),
			if seen then unit.role else "follow"
		)
		if not seen and (distance(body.Position, unit.lastKnown) < 30 or unit.searchNode > 0) then
			-- Sweep the adjoining road branches at the last sighting; never query hidden driver position.
			local _, node = Nav.project(Graph, point(unit.lastKnown))
			local links = Graph[node].links
			if #links > 0 then
				unit.searchNode = if unit.searchNode == 0 then 1 else unit.searchNode
				local nextNode = Graph[links[unit.searchNode]]
				target = { x = nextNode.x, z = nextNode.z }
				if Nav.distance(point(body.Position), target) < 18 then
					unit.searchNode = unit.searchNode % #links + 1
				end
			end
		end
		unit.plan = Nav.route(Graph, point(body.Position), target)
		unit.replan = now + 0.5
	end
	local speed = body.AssemblyLinearVelocity:Dot(body.CFrame.LookVector)
	local remaining = Nav.remaining(unit.plan, point(body.Position))
	local aim = Nav.ahead(remaining, math.clamp(8 + math.abs(speed) * 0.45, 12, 60))
	local throttle, steer = 0, 0
	if aim then
		local target = Vector3.new(aim.x, body.Position.Y, aim.z)
		-- Direct interception only on nearby visible pavement, never through houses.
		if seen and distance(body.Position, car.Body.Position) < 45 then
			target = car.Body.Position
		end
		local localPoint = body.CFrame:PointToObjectSpace(target)
		throttle, steer = Nav.controls(
			localPoint.X,
			-localPoint.Z,
			speed,
			unit.car.Wheelbase or 10.4,
			Nav.cornerSpeed(remaining, if seen then 120 else 32)
		)
	end
	unit.stalled = if math.abs(speed) < 2
			and throttle > 0
			and now > unit.alertUntil
		then unit.stalled + dt
		else 0
	if unit.stalled > 3 then
		unit.reverseUntil = now + 1.5
		unit.stalled = 0
	end
	if now < unit.reverseUntil then
		local ray = RaycastParams.new()
		ray.FilterDescendantsInstances = { unit.car.Model }
		ray.RespectCanCollide = true
		ray.CollisionGroup = "Police"
		local behind = workspace:Blockcast(
			body.CFrame,
			Vector3.new(body.Size.X, 1, body.Size.Z),
			-body.CFrame.LookVector * 12,
			ray
		)
		throttle = if behind then 0 else -0.5
		steer = -steer
	end
	-- Home is protected: officers hold outside the driveway rather than entering bays.
	if distance(body.Position, Map.Garage) < 150 then
		throttle = if speed > 2 then -1 else 0
	end
	if now < unit.alertUntil then
		throttle, steer = 0, 0
	end
	Vehicle.step(unit.car, math.min(dt, 0.05), throttle, steer, false, false)
	unit.car.Model:SetAttribute("PoliceRole", if seen then unit.role else "search")
end
function Getaway.step(dt: number)
	local now = os.clock()
	for player, job in jobs do
		if not Rules.active(job.rules) then
			continue
		end
		local car = job.car
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		local valid = car.Model.Parent ~= nil
			and humanoid ~= nil
			and humanoid.Health > 0
			and (car.Seat.Occupant == humanoid or now < job.grace)
		valid = valid
			and not car.Model:GetAttribute("Highway")
			and car.Body.Position.X > -2400
			and ((car.Model:GetAttribute("Damage") :: number?) or 0) < 100
		local seen, near = false, false
		if valid and job.rules.phase ~= "pickup" then
			if #job.cops < job.variant.heat and now >= job.nextSpawn then
				spawnUnit(player, job)
				job.nextSpawn = now + 4
			end
			for _, unit in job.cops do
				local canSee = visible(unit, car, player)
				if canSee then
					job.dispatch = car.Body.Position
				end
				seen = seen or canSee
				near = near or (canSee and distance(unit.car.Body.Position, car.Body.Position) < 24)
				steerUnit(unit, car, canSee, math.min(dt, 0.25), now)
			end
		end
		if seen and job.variant.heat >= 3 and not job.blockTried then
			job.block = Roadblock.deploy(player, job.dispatch, car.Body.AssemblyLinearVelocity)
			job.blockTried = job.block ~= nil
		end
		if job.block and now >= job.block.expires then
			Roadblock.clear(player, job.block)
			job.block = nil
		end
		Variants.damage(job.variant, (car.Model:GetAttribute("Damage") :: number?) or 0)
		if job.variant.choice and now >= job.variant.deadline then
			Getaway.choose(player, "bank")
		end
		local target = checkpoint(job.contract, math.min(job.rules.checkpoint, #job.contract.Checkpoints))
		local result = Rules.step(job.rules, dt, {
			valid = valid,
			atCheckpoint = distance(car.Body.Position, target) < 22
				and math.abs(car.Body.Position.Y - target.Y) < 12,
			atHome = distance(car.Body.Position, Map.Garage) < 35,
			seen = seen,
			nearCop = near,
			slow = car.Body.AssemblyLinearVelocity.Magnitude < 12,
			stopped = car.Body.AssemblyLinearVelocity.Magnitude < 2,
			policeReady = job.policeReady and not job.variant.choice,
		})
		if result == "alarm" or result == "checkpoint" then
			job.dispatch = target
			Variants.pickup(job.variant, job.rules.checkpoint <= #job.contract.Checkpoints, now)
			if job.contract.Mode == "heat" then
				job.rules.phase = "escape"
				player:SetAttribute("MissionChoice", job.variant.choice)
				player:SetAttribute("UnbankedHaul", Variants.base(job.variant, job.contract.Reward))
			end
		end
		if result then
			Metrics.mark(player, result, {
				damage = job.variant.damage,
				quality = job.variant.quality,
				remaining = job.rules.remaining,
			})
		end
		if result == "alarm" then
			player:SetAttribute("MissionMessage", "LOOT COLLECTED · Police alerted. Keep moving!")
		elseif result == "checkpoint" then
			player:SetAttribute("MissionMessage", "Stash collected. Keep moving to the next marker.")
		elseif result == "escaped" and job.free then
			job.rules.phase = "complete"
			player:SetAttribute("MissionMessage", "ESCAPED · Patrol lost you. Cool down before another run.")
		elseif result == "escaped" then
			player:SetAttribute(
				"MissionMessage",
				"ESCAPED · Return to the green home marker. Stop there for 2 seconds."
			)
		elseif result == "spotted" then
			player:SetAttribute("MissionMessage", "SPOTTED AGAIN · Break line of sight for 10 seconds.")
		elseif result == "reward" then
			local reward = Variants.payout(
				job.variant,
				Progression.payout(
					Variants.base(job.variant, job.contract.Reward),
					job.rules.remaining,
					job.difficulty,
					(car.Model:GetAttribute("Damage") :: number?) or 0
				)
			)
			local withoutClean = Variants.payout(
				job.variant,
				Progression.payout(
					Variants.base(job.variant, job.contract.Reward),
					job.rules.remaining,
					job.difficulty,
					1
				)
			)
			player:SetAttribute("LastCleanBonus", math.max(0, reward - withoutClean))
			player:SetAttribute("LastReward", reward)
			Metrics.mark(
				player,
				"bank",
				{ amount = reward, seconds = now - job.started, difficulty = job.difficulty }
			)
			Workshop.credit(player, reward)
			Workshop.win(player)
			player:SetAttribute(
				"MissionMessage",
				"DELIVERED! +$" .. reward .. " · Choose another contract at home."
			)
		elseif result == "busted" then
			player:SetAttribute(
				"MissionMessage",
				"BUSTED · Held by police for 5 seconds. R to return home and retry."
			)
		elseif result == "timeout" then
			player:SetAttribute("MissionMessage", "TIME UP · R to return home and retry.")
		elseif result == "vehicle_lost" then
			player:SetAttribute(
				"MissionMessage",
				"JOB LOST · Stay in a working car. R to recover, then retry at home."
			)
		end
		if result or job.clock <= 0 then
			player:SetAttribute(
				"CargoQuality",
				if job.contract.Mode == "cargo" then math.floor(job.variant.quality) else nil
			)
			player:SetAttribute("MissionPhase", job.rules.phase)
			player:SetAttribute("MissionRemaining", math.ceil(job.rules.remaining))
			player:SetAttribute("MissionEscape", math.floor(job.rules.escape))
			player:SetAttribute("MissionBusted", math.floor(job.rules.busted * 10) / 10)
			player:SetAttribute(
				"MissionCheckpoint",
				math.min(job.rules.checkpoint, #job.contract.Checkpoints)
			)
			player:SetAttribute("MissionCheckpointCount", #job.contract.Checkpoints)
			player:SetAttribute("PoliceSeeing", seen)
			player:SetAttribute(
				"Wanted",
				if job.rules.phase == "pickup" or not Rules.active(job.rules) then 0 else job.variant.heat
			)
			player:SetAttribute(
				"MissionTarget",
				if not Rules.active(job.rules) or job.rules.phase == "escape"
					then nil
					elseif job.rules.phase == "deliver" then Map.Garage
					else checkpoint(job.contract, job.rules.checkpoint)
			)
			job.clock = 0.2
		end
		job.clock -= dt
		if not Rules.active(job.rules) then
			player:SetAttribute("MissionChoice", false)
			player:SetAttribute("LastRunSeconds", math.floor(now - job.started))
			if result ~= "reward" then
				player:SetAttribute("LastReward", 0)
				player:SetAttribute("LastCleanBonus", 0)
			end
			player:SetAttribute(
				"ResultSequence",
				((player:GetAttribute("ResultSequence") :: number?) or 0) + 1
			)
			dispose(job)
		end
	end
end
return Getaway
