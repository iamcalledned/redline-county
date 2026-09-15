--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Config = require(ReplicatedStorage.Shared.Config)
local Units = require(ReplicatedStorage.Shared.Units)
local Driving = require(ReplicatedStorage.Shared.Driving)
local DriftRules = require(ReplicatedStorage.Shared.DriftRules)
local Garage = require(script.Parent.TownGarage)
local TownTraffic = require(script.Parent.TownTraffic)
local Workshop = require(script.Parent.Workshop)
local Progression = require(ReplicatedStorage.Shared.Progression)
local Getaway = require(script.Parent.Getaway)
local Circuit = require(script.Parent.Circuit)
local GarageRules = require(ReplicatedStorage.Shared.GarageRules)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Course = require(script.Parent.Course)
local Vehicle = require(script.Parent.Vehicle)
local Highway = require(script.Parent.Highway)
local HighwayMath = require(ReplicatedStorage.Shared.HighwayMath)
local Traffic = require(script.Parent.Traffic)
local CrashEffect = require(script.Parent.CrashEffect)
local CrashMath = require(ReplicatedStorage.Shared.CrashMath)

-- This local handling lab must be deliberately redesigned before public release.
if Config.DevelopmentOnly and not RunService:IsStudio() then
	warn("[REDLINE COUNTY] Development build disabled outside Studio.")
	return
end

for _, name in { "Cars", "Characters", "Traffic", "Police", "Civilian", "Suspension" } do
	if not PhysicsService:IsCollisionGroupRegistered(name) then
		PhysicsService:RegisterCollisionGroup(name)
	end
end
-- Ghost vehicles while tuning. No ramming/pushing in garage or on the course.
PhysicsService:CollisionGroupSetCollidable("Cars", "Cars", false)
PhysicsService:CollisionGroupSetCollidable("Cars", "Characters", false)
PhysicsService:CollisionGroupSetCollidable("Cars", "Traffic", true)
PhysicsService:CollisionGroupSetCollidable("Characters", "Traffic", false)
PhysicsService:CollisionGroupSetCollidable("Traffic", "Traffic", false)
PhysicsService:CollisionGroupSetCollidable("Cars", "Police", true)
PhysicsService:CollisionGroupSetCollidable("Characters", "Police", false)
PhysicsService:CollisionGroupSetCollidable("Police", "Police", true)
PhysicsService:CollisionGroupSetCollidable("Cars", "Civilian", true)
PhysicsService:CollisionGroupSetCollidable("Police", "Civilian", true)
PhysicsService:CollisionGroupSetCollidable("Civilian", "Civilian", true)
PhysicsService:CollisionGroupSetCollidable("Characters", "Civilian", false)
for _, group in { "Cars", "Characters", "Traffic", "Police", "Civilian", "Suspension" } do
	PhysicsService:CollisionGroupSetCollidable("Suspension", group, false)
end
Course.build()
-- Preserve the isolated handling lab away from the geographic town origin.
local labOffset = Vector3.new(-6000, 0, 0)
workspace.HandlingCourse:PivotTo(workspace.HandlingCourse:GetPivot() + labOffset)
Course.Garage += labOffset
for i, pad in Course.Pads do
	Course.Pads[i] = pad + labOffset
end
for _, item in workspace.HandlingCourse:GetDescendants() do
	if item:IsA("SpawnLocation") then
		item.Enabled = false
	end
end
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "Vehicles", workspace
local impactRay = RaycastParams.new()
impactRay.FilterDescendantsInstances = { folder }
impactRay.CollisionGroup = "Cars"
impactRay.RespectCanCollide = true
local remotes = Instance.new("Folder")
remotes.Name, remotes.Parent = "Remotes", ReplicatedStorage
local function remote(name: string): RemoteEvent
	local event = Instance.new("RemoteEvent")
	event.Name, event.Parent = name, remotes
	return event
end
local input, request, notice = remote("DriveInput"), remote("VehicleRequest"), remote("Notice")

type State = {
	car: Vehicle.Car?,
	throttle: number,
	steer: number,
	drift: boolean,
	driftScore: DriftRules.State,
	lastInput: number,
	lastOccupied: number,
	nextSpawn: number,
	nextReset: number,
	inputBucket: Rules.Bucket,
	requestBucket: Rules.Bucket,
	spawning: boolean,
	turboEnabled: boolean,
	trip: number,
	lastHighwayZ: number?,
	previousCF: CFrame?,
	previousVelocity: Vector3?,
	previousTime: number,
	crashUntil: number,
	crashKind: string,
	nextImpact: number,
	nextPursuit: number,
}
local states: { [Player]: State } = {}

local function tell(player: Player, message: string)
	player:SetAttribute("GarageMessage", message)
	notice:FireClient(player, message)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function driving(player: Player, car: Vehicle.Car): boolean
	local occupant = car.Seat.Occupant
	return occupant ~= nil and occupant.Health > 0 and occupant.Parent == player.Character
end

local function clear(state: State)
	state.driftScore = DriftRules.new()
	if state.car then
		local owner = Players:GetPlayerByUserId(state.car.Model:GetAttribute("OwnerId") :: number)
		if owner then
			Getaway.cancel(owner, "JOB LOST · Vehicle removed. Choose a new contract at home.")
			Garage.hideDisplay(owner, false)
		end
		state.car.Model:Destroy()
		state.car = nil
	end
	state.throttle, state.steer, state.drift = 0, 0, false
	state.previousCF = nil
end

local function labPad(exclude: Model?): CFrame?
	local overlap = OverlapParams.new()
	local ignore: { Instance } = { workspace.HandlingCourse }
	if exclude then
		table.insert(ignore, exclude)
	end
	overlap.FilterDescendantsInstances = ignore
	-- Query includes non-colliding car trim and character roots, so occupied pads remain blocked.
	for _, pad in Course.Pads do
		if #workspace:GetPartBoundsInBox(pad, Vector3.new(18, 7, 25), overlap) == 0 then
			return pad
		end
	end
	return nil
end

local function hookEntry(player: Player, car: Vehicle.Car)
	local prompt = car.Model:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt
	prompt.Triggered:Connect(function(who: Player)
		local root = rootOf(who)
		local humanoid = if who.Character then who.Character:FindFirstChildOfClass("Humanoid") else nil
		if
			who ~= player
			or car.Model:GetAttribute("Crashed")
			or not root
			or not humanoid
			or humanoid.Health <= 0
			or car.Seat.Occupant
			or humanoid.SeatPart
		then
			return
		end
		if
			(root.Position - car.Seat.Position).Magnitude > 14
			or car.Body.AssemblyLinearVelocity.Magnitude > 8
		then
			return
		end
		local ray = RaycastParams.new()
		ray.FilterDescendantsInstances = { who.Character :: Model, car.Model }
		ray.RespectCanCollide = true
		if workspace:Raycast(root.Position, car.Seat.Position - root.Position, ray) then
			tell(player, "Walk beside your car; something solid is between you and the driver's seat.")
			return
		end
		car.Seat:Sit(humanoid)
	end)
	car.Seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = car.Seat.Occupant
		if occupant and occupant.Parent ~= player.Character then
			occupant.Sit = false
		end
		prompt.Enabled = occupant == nil and not car.Model:GetAttribute("Crashed")
		-- Seat welds can change assemblies; reassert server ownership after seating.
		if car.Body.Parent and not car.Body.Anchored then
			car.Body:SetNetworkOwner(nil)
		end
	end)
end

local function spawnCar(player: Player, kind: string, initial: boolean?)
	if Getaway.active(player) then
		tell(player, "Finish or abandon your contract before changing cars.")
		return
	end
	local state, root = states[player], rootOf(player)
	if not state or not root or state.spawning then
		return
	end
	if not (Config.Cars :: any)[kind] then
		tell(player, "Unknown vehicle.")
		return
	end
	local now = os.clock()
	local old = state.car
	local speed = if old then old.Body.AssemblyLinearVelocity.Magnitude else 0
	local other = old ~= nil and old.Seat.Occupant ~= nil and not driving(player, old)
	if
		not (
			initial
			or GarageRules.canSelect(
				(root.Position - Garage.Center).Magnitude,
				speed,
				other,
				state.spawning,
				now,
				state.nextSpawn
			)
		)
	then
		tell(player, "Stop at the garage to change cars; spawn cooldown is 4 seconds.")
		return
	end
	if not old and #folder:GetChildren() >= Config.MaxVehicles then
		tell(player, "All 12 vehicles are in use. Try again shortly.")
		return
	end
	local pad = if initial then Highway.entry() else Garage.pad(player, if old then old.Model else nil)
	if not pad then
		tell(player, "Your bay is occupied, or all three home bays are assigned. Clear it and retry.")
		return
	end
	if initial then
		local entry = Highway.entry()
		local found = false
		for slot = 0, Config.MaxVehicles - 1 do
			local candidate = entry + Vector3.new(0, 0, slot * 24)
			local available = true
			for _, otherState in states do
				if otherState.car and (otherState.car.Body.Position - candidate.Position).Magnitude < 18 then
					available = false
					break
				end
			end
			if available then
				pad = candidate
				found = true
				break
			end
		end
		if not found then
			tell(player, "Highway starting bays occupied. Try again shortly.")
			return
		end
	end
	state.spawning = true
	state.nextSpawn = now + Config.SpawnCooldown
	clear(state)
	local car = Vehicle.create(folder, player, kind, pad)
	state.car, state.spawning = car, false
	Workshop.apply(player, car)
	Garage.hideDisplay(player, true)
	car.Model:SetAttribute("TownMode", not initial)
	state.turboEnabled = initial == true and kind ~= "Electric" and kind ~= "Pickup"
	state.lastOccupied = now
	state.trip, state.lastHighwayZ = 0, nil
	car.Model:SetAttribute("TurboEnabled", state.turboEnabled)
	if initial then
		car.Model:SetAttribute("Highway", true)
		car.Model:SetAttribute("TownMode", false)
		car.Model:SetAttribute("TripStuds", 0)
		state.lastHighwayZ = pad.Position.Z
		if player.Character then
			player.Character:PivotTo(pad * CFrame.new(8, 1, 0))
		end
	end
	hookEntry(player, car)
	tell(
		player,
		if initial
			then "SAFE ON-RAMP · Press E, accelerate, then merge left at the sign. Traffic impacts destroy your car."
			else kind
				.. " ready in bay "
				.. tostring(player:GetAttribute("HomeBay"))
				.. ". Open that bay's wall switch with E, then E beside your car to drive."
	)
end

local function resetCar(player: Player): boolean
	local state, root = states[player], rootOf(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not state or not root or not character or not humanoid or humanoid.Health <= 0 then
		tell(player, "Wait for your character to respawn, then retry.")
		return false
	end
	local car, now = state.car, os.clock()
	local finished = Getaway.retryInfo(player) ~= nil
	if now < state.nextReset then
		tell(player, "Recovery cooling down. Try again in a few seconds.")
		return false
	end
	if humanoid.SeatPart and (not car or humanoid.SeatPart ~= car.Seat) then
		tell(player, "Leave the other vehicle before recovering.")
		return false
	end
	if car and car.Seat.Occupant and not driving(player, car) then
		tell(player, "Your car is occupied. Wait until its driver leaves.")
		return false
	end
	if
		car
		and not finished
		and not Rules.canReset(
			car.Body.AssemblyLinearVelocity.Magnitude,
			car.Body.CFrame.UpVector.Y,
			driving(player, car),
			(root.Position - car.Body.Position).Magnitude,
			Config.Lifecycle
		)
	then
		tell(player, "Stop first, or slow down while overturned. Stay beside your own car.")
		return false
	end
	local pad = Garage.pad(player, if car then car.Model else nil)
	if not pad then
		tell(player, "Garage bay occupied. Clear it and retry.")
		return false
	end
	Getaway.cancel(player, "Job abandoned for recovery. Choose a new contract at home.")
	-- Detach before teleporting: moving a still-welded rider can drag the car back out of its bay.
	humanoid.Sit = false
	if car then
		local weld = car.Seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		car.Model:SetAttribute("Damage", 0)
		car.Model:SetAttribute("Highway", false)
		car.Model:SetAttribute("TownMode", true)
		car.Model:PivotTo(pad)
		car.Body.AssemblyLinearVelocity, car.Body.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		car.Align.CFrame = pad.Rotation
		car.Body:SetNetworkOwner(nil)
	end
	character:PivotTo(Garage.spawnPoint(player))
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	state.nextReset = now + Config.ResetCooldown
	state.throttle, state.steer, state.drift = 0, 0, false
	state.driftScore = DriftRules.new()
	state.lastHighwayZ, state.previousCF, state.previousVelocity = nil, nil, nil
	state.lastOccupied, state.nextImpact = now, now + 2
	state.nextPursuit = now + 5
	if not car then
		state.nextSpawn = 0
	end
	tell(player, "You and your car are back at the garage.")
	return true
end

local function enterHighway(player: Player)
	local state = states[player]
	if not state or not state.car then
		tell(player, "Spawn a car and sit in it first.")
		return
	end
	local car = state.car
	if not driving(player, car) or car.Body.AssemblyLinearVelocity.Magnitude > Config.Lifecycle.StopSpeed then
		tell(player, "Sit in your car and stop before entering the Autobahn.")
		return
	end
	if car.Model:GetAttribute("Highway") then
		tell(player, "Already on the Autobahn. Stop and use Recover to return.")
		return
	end
	if os.clock() < state.nextReset then
		tell(player, "Travel cooling down.")
		return
	end
	local pad = Highway.entry()
	-- Choose a clear launch point along the shoulder. Ghost cars still get distinct launch spaces.
	local found = false
	for slot = 0, Config.MaxVehicles - 1 do
		local candidate = pad + Vector3.new(0, 0, slot * 24)
		local entryClear = true
		for _, other in states do
			if
				other.car
				and other.car ~= car
				and (other.car.Body.Position - candidate.Position).Magnitude < 18
			then
				entryClear = false
				break
			end
		end
		if entryClear then
			pad = candidate
			found = true
			break
		end
	end
	if not found then
		tell(player, "Highway entry is occupied. Try again shortly.")
		return
	end
	state.nextReset = os.clock() + Config.ResetCooldown
	state.throttle, state.steer, state.drift = 0, 0, false
	state.trip, state.lastHighwayZ = 0, pad.Position.Z
	state.previousCF = nil
	car.Model:SetAttribute("Highway", true)
	car.Model:SetAttribute("TripStuds", 0)
	car.Model:SetAttribute("TownMode", false)
	car.Model:PivotTo(pad)
	car.Body.AssemblyLinearVelocity, car.Body.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	car.Align.CFrame, car.Steer = pad.Rotation, 0
	car.Body:SetNetworkOwner(nil)
	tell(player, "SAFE ON-RAMP · Follow the acceleration lane and merge left. Stop + R to return.")
end

local function crashCar(player: Player, state: State, contactTime: number)
	local car = state.car
	if not car or not CrashMath.canBegin(state.crashUntil > 0, true) then
		return
	end
	state.crashUntil = os.clock() + Config.Crash.RecoverySeconds
	state.nextSpawn, state.nextReset = state.crashUntil, state.crashUntil
	state.crashKind = car.Model:GetAttribute("Kind") :: string
	car.Model:SetAttribute("Crashed", true)
	state.throttle, state.steer, state.drift = 0, 0, false
	-- Stop at first swept contact, rather than leaving the wreck on the far side of traffic.
	if state.previousCF then
		car.Model:PivotTo(state.previousCF:Lerp(car.Body.CFrame, contactTime))
	end
	car.Body.AssemblyLinearVelocity, car.Body.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	car.Body.Anchored = true
	car.Drive.Force = Vector3.zero
	car.Align.Enabled = false
	for _, spring in car.Springs do
		spring.Force = Vector3.zero
	end
	local prompt = car.Model:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	CrashEffect.show(car.Model, car.Body)
	tell(player, "CRASH! Car destroyed. Replacement at the safe on-ramp in 3 seconds.")
end

input.OnServerEvent:Connect(function(player: Player, throttle: any, steer: any, drift: any)
	local state, now = states[player], os.clock()
	if not state or not Rules.consume(state.inputBucket, now, 35, 45) then
		return
	end
	if
		not Driving.validInput(throttle, steer, drift)
		or state.crashUntil > 0
		or not state.car
		or not driving(player, state.car)
	then
		return
	end
	state.throttle, state.steer, state.drift, state.lastInput = throttle, steer, drift, now
end)

request.OnServerEvent:Connect(function(player: Player, action: any, kind: any, option: any)
	local state, now = states[player], os.clock()
	if not state or not Rules.consume(state.requestBucket, now, 2, 3) then
		return
	end
	if state.crashUntil > 0 then
		tell(player, "Crash recovery in progress…")
		return
	end

	if action == "RetryMission" or action == "ReturnHome" then
		local contract, difficulty = Getaway.retryInfo(player)
		if not contract then
			tell(player, "Finish or abandon the current run before retrying.")
			return
		end
		if not resetCar(player) then
			return
		end
		if action == "ReturnHome" then
			Getaway.remove(player)
			player:SetAttribute("MissionPhase", "idle")
			notice:FireClient(
				player,
				"Ready for your next run.",
				if kind == "workshop" then "workshop" else "jobs"
			)
			return
		end
		-- Continue through the ordinary mission validation and seating path.
		action, kind, option = "Mission", contract, difficulty
	end

	if (action == "Upgrade" or action == "Cosmetic") and type(kind) == "string" and #kind < 20 then
		local car = state.car
		local root = rootOf(player)
		if not car or not root then
			tell(player, "Select a car at home before fitting upgrades.")
			return
		end
		local atHome = (root.Position - Garage.Center).Magnitude < 85
			and (car.Body.Position - Garage.Center).Magnitude < 85
			and car.Body.AssemblyLinearVelocity.Magnitude < 2
			and (not car.Seat.Occupant or driving(player, car))
		tell(
			player,
			if action == "Cosmetic"
				then Workshop.cosmetic(player, car, kind, atHome, Getaway.active(player))
				else Workshop.buy(player, car, kind, atHome, Getaway.active(player))
		)
		return
	end
	if action == "HeatChoice" then
		if type(kind) == "string" then
			Getaway.choose(player, kind)
		end
		return
	end
	if action == "CancelMission" then
		Getaway.cancel(player, "Job abandoned. Return home for another contract.")
		return
	end
	if
		Getaway.active(player)
		and (action == "Mission" or action == "Spawn" or action == "Lab" or action == "Highway")
	then
		tell(player, "Finish or abandon the current contract first. R abandons it and recovers your car.")
		return
	end
	if action == "Mission" then
		local root = rootOf(player)
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		local known = Progression.difficulty(option or "light") ~= nil
		local knownContract = false
		for _, contract in require(ReplicatedStorage.Shared.Contracts) do
			if contract.Id == kind then
				knownContract = true
			end
		end
		if
			not known
			or not knownContract
			or not root
			or not humanoid
			or humanoid.Health <= 0
			or (root.Position - Garage.Center).Magnitude > 85
		then
			tell(player, "Return to the home garage to start a contract.")
			return
		end
		if not state.car then
			spawnCar(player, (player:GetAttribute("SelectedCar") :: string?) or "Electric")
		end
		local car = state.car
		if
			not car
			or car.Model:GetAttribute("Highway")
			or (car.Body.Position - Garage.Center).Magnitude > 85
			or car.Body.AssemblyLinearVelocity.Magnitude > 2
			or (car.Seat.Occupant and not driving(player, car))
			or (humanoid.SeatPart and humanoid.SeatPart ~= car.Seat)
		then
			tell(player, "Stop your car at home before starting a contract.")
			return
		end
		if Getaway.start(player, car, kind, option or "light") then
			Garage.openFor(player)
			car.Seat:Sit(humanoid)
			tell(player, "GETAWAY · Follow the cyan route. Gold marker = pickup. Green marker = home.")
		end
		return
	end
	if
		action == "Lab"
		and state.car
		and driving(player, state.car)
		and state.car.Body.AssemblyLinearVelocity.Magnitude < 2
	then
		local pad = labPad(state.car.Model)
		if pad then
			state.car.Model:SetAttribute("Highway", false)
			state.car.Model:SetAttribute("TownMode", true)
			state.car.Model:PivotTo(pad)
			state.car.Body.AssemblyLinearVelocity = Vector3.zero
			state.previousCF = nil
			tell(player, "ISOLATED HANDLING LAB · V camera, G diagnostics, R home.")
		end
	elseif action == "Spawn" and type(kind) == "string" and #kind <= 20 then
		spawnCar(player, kind)
	elseif action == "Reset" then
		if resetCar(player) then
			Getaway.remove(player)
			player:SetAttribute("MissionPhase", "idle")
		end
	elseif action == "Highway" then
		enterHighway(player)
	elseif action == "Turbo" and state.car and driving(player, state.car) then
		if
			state.car.Model:GetAttribute("Kind") == "Electric"
			or state.car.Model:GetAttribute("Kind") == "Pickup"
		then
			tell(player, "This collection vehicle has no turbo.")
			return
		end
		state.turboEnabled = not state.turboEnabled
		state.car.Model:SetAttribute("TurboEnabled", state.turboEnabled)
		tell(
			player,
			if state.turboEnabled then "Turbo armed: accelerate to build boost." else "Turbo switched off."
		)
	end
end)

local joining: { [Player]: boolean } = {}
local PlaytestMetrics = require(script.Parent.PlaytestMetrics)
local function joined(player: Player)
	if states[player] or joining[player] then
		return
	end
	joining[player] = true
	local now = os.clock()
	if not Garage.claim(player) then
		player:Kick("This three-driver garage is full. Please join another server.")
		return
	end
	if not Workshop.init(player) or not player.Parent then
		return
	end
	player:SetAttribute("MissionPhase", "idle")
	states[player] = {
		car = nil,
		throttle = 0,
		steer = 0,
		drift = false,
		driftScore = DriftRules.new(),
		lastInput = 0,
		lastOccupied = now,
		nextSpawn = 0,
		nextReset = 0,
		spawning = false,
		turboEnabled = true,
		trip = 0,
		lastHighwayZ = nil,
		previousCF = nil,
		previousTime = workspace:GetServerTimeNow(),
		crashUntil = 0,
		crashKind = "Compact",
		nextImpact = 0,
		nextPursuit = 0,
		inputBucket = { tokens = 45, updated = now },
		requestBucket = { tokens = 3, updated = now },
	}
	local function characterAdded(character: Model)
		local function collision(item: Instance)
			if item:IsA("BasePart") then
				item.CollisionGroup = "Characters"
			end
		end
		for _, item in character:GetDescendants() do
			collision(item)
		end
		character.DescendantAdded:Connect(collision)
		local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
		character:WaitForChild("HumanoidRootPart", 10)
		if humanoid then
			humanoid.Died:Connect(function()
				local state = states[player]
				if state then
					clear(state)
				end -- Timers are kept through character resets.
			end)
		end
		task.delay(1, function()
			if states[player] and player.Character == character and not states[player].car then
				local arrival = Garage.spawnPoint(player)
				character:PivotTo(arrival)
				character:SetAttribute("GarageArrival", arrival)
				tell(
					player,
					"HOPEDALE HOME · E beside a display to select, or click Pickup / Electric / Sport. Your car appears in bay "
						.. tostring(player:GetAttribute("HomeBay"))
						.. "."
				)
			end
		end)
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end
Garage.bind(spawnCar)
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
	joining[player] = nil
	PlaytestMetrics.remove(player)
	Getaway.remove(player)
	Workshop.remove(player)
	Circuit.remove(player)
	if states[player] then
		clear(states[player])
		states[player] = nil
	end
end)
for _, player in Players:GetPlayers() do
	joined(player)
end

RunService.PreSimulation:Connect(function(dt: number)
	local now = os.clock()
	Highway.update(dt, folder)
	Traffic.move()
	local trafficTime = workspace:GetServerTimeNow()
	for player, state in states do
		if state.crashUntil > 0 then
			local root = rootOf(player)
			local humanoid = if player.Character
				then player.Character:FindFirstChildOfClass("Humanoid")
				else nil
			if now >= state.crashUntil and root and humanoid and humanoid.Health > 0 then
				clear(state)
				humanoid.Sit = false
				(player.Character :: Model):PivotTo(CFrame.new(Course.Garage + Vector3.new(0, 6, 0)))
				root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
				state.crashUntil, state.nextSpawn = 0, 0
				spawnCar(player, state.crashKind, true)
			end
			continue
		end
		local root = rootOf(player)
		if root and math.floor(now * 2) ~= (player:GetAttribute("DiscoveryTick") or -1) then
			player:SetAttribute("DiscoveryTick", math.floor(now * 2))
			for _, site in require(ReplicatedStorage.Shared.TownMap).Discoveries do
				if
					(root.Position - site.Position).Magnitude < 65 and Workshop.discover(player, site.Name)
				then
					tell(player, "DISCOVERED " .. site.Name .. " · +$150 for your next upgrade")
				end
			end
		end
		local car = state.car
		if car and car.Body.AssemblyLinearVelocity.Magnitude > 8 then
			player:SetAttribute("HasDriven", true)
			PlaytestMetrics.mark(player, "first_movement", nil, true)
		end
		if not car then
			state.driftScore = DriftRules.new()
			Circuit.step(player, nil, dt, false)
			continue
		end
		local occupied = driving(player, car)
		local lapMessage = Circuit.step(player, car, dt, occupied)
		if lapMessage then
			tell(player, lapMessage)
		end
		if
			occupied
			and not car.Model:GetAttribute("Highway")
			and not Getaway.active(player)
			and now >= state.nextPursuit
			and Units.kmh(car.Body.AssemblyLinearVelocity.Magnitude) > 80
		then
			local nearby = workspace:FindFirstChild("TownTraffic")
			if nearby then
				for _, patrol in nearby:GetChildren() do
					if
						patrol:IsA("Model")
						and patrol.PrimaryPart
						and patrol:GetAttribute("Police")
						and (patrol.PrimaryPart.Position - car.Body.Position).Magnitude < 180
					then
						local ray = RaycastParams.new()
						ray.FilterDescendantsInstances = { folder, nearby }
						ray.RespectCanCollide = true
						if
							not workspace:Raycast(
								patrol.PrimaryPart.Position,
								car.Body.Position - patrol.PrimaryPart.Position,
								ray
							)
						then
							Getaway.provoke(player, car)
							state.nextPursuit = now + 45
							break
						end
					end
				end
			end
		end
		if car.Model:GetAttribute("Highway") then
			local contact = Traffic.contact(
				car.Body,
				state.previousCF,
				if state.previousCF then state.previousTime else trafficTime,
				trafficTime
			)
			if contact then
				crashCar(player, state, contact)
				continue
			end
		end
		if car.Model:GetAttribute("TownMode") and state.previousCF and now >= state.nextImpact then
			local delta = car.Body.Position - state.previousCF.Position
			if delta.Magnitude > 0.01 and delta.Magnitude < 100 then
				local hit = workspace:Blockcast(state.previousCF, car.Body.Size, delta, impactRay)
				if hit and math.abs(hit.Normal.Y) < 0.7 then
					local impact = Units.kmh(
						math.abs((state.previousVelocity or car.Body.AssemblyLinearVelocity):Dot(hit.Normal))
					)
					local damage = GarageRules.damage(impact)
					if damage > 0 then
						local total =
							math.min(100, ((car.Model:GetAttribute("Damage") :: number?) or 0) + damage)
						car.Model:SetAttribute("Damage", total)
						state.nextImpact = now + 1
						tell(
							player,
							if total >= 100
								then "Vehicle disabled by repeated impacts. Stop + R to repair at home."
								else "Impact · damage " .. total .. "%. Slow down; R repairs at home."
						)
					end
				end
			end
		end
		if ((car.Model:GetAttribute("Damage") :: number?) or 0) >= 100 then
			state.throttle = 0
		end
		if occupied then
			state.lastOccupied = now
		end
		if not occupied or now - state.lastInput > Config.InputTimeout then
			state.throttle, state.steer, state.drift = 0, 0, false
		end
		if
			car.Body.Position.Y < -35
			or not Driving.finite(car.Body.Position.X)
			or car.Body.AssemblyLinearVelocity.Magnitude > Config.PhysicsSpeedLimit
		then
			clear(state)
			tell(
				player,
				"Vehicle removed after leaving the course or exceeding the physics limit. Return to the garage."
			)
		elseif not occupied and now - state.lastOccupied > Config.AbandonedSeconds then
			clear(state)
			tell(player, "Unused car returned to the garage. Spawn another when ready.")
		else
			if car.Model:GetAttribute("Highway") then
				Highway.wrapCar(car.Model, car.Body)
				local z = car.Body.Position.Z
				if state.lastHighwayZ then
					state.trip += HighwayMath.travel(
						state.lastHighwayZ,
						z,
						Config.Highway.HalfLength,
						Config.PhysicsSpeedLimit * math.min(dt, 0.25) + 5
					)
				end
				state.lastHighwayZ = z
			end
			Vehicle.step(
				car,
				math.min(dt, 1 / 20),
				state.throttle,
				state.steer,
				state.drift,
				state.turboEnabled and occupied
			)
			local velocity = car.Body.AssemblyLinearVelocity
			local bank, score = DriftRules.step(
				state.driftScore,
				dt,
				velocity:Dot(car.Body.CFrame.LookVector),
				velocity:Dot(car.Body.CFrame.RightVector),
				((car.Model:GetAttribute("GroundedWheels") :: number?) or 0) >= 3,
				((car.Model:GetAttribute("Damage") :: number?) or 0),
				occupied and car.Model:GetAttribute("TownMode") == true
			)
			if bank > 0 then
				Workshop.credit(player, bank)
				player:SetAttribute(
					"BestDrift",
					math.max(score, (player:GetAttribute("BestDrift") :: number?) or 0)
				)
				tell(player, "DRIFT BANKED · " .. score .. " points · +$" .. bank)
			end
			if car.TelemetryClock == 0 then
				car.Model:SetAttribute("DriftPoints", math.floor(state.driftScore.points))
			end
			state.previousCF, state.previousTime = car.Body.CFrame, trafficTime
			state.previousVelocity = car.Body.AssemblyLinearVelocity
			if car.TelemetryClock == 0 then
				car.Model:SetAttribute("TripStuds", math.floor(state.trip))
			end
		end
	end
	debug.profilebegin("Redline.Traffic")
	TownTraffic.step(dt)
	debug.profileend()
	debug.profilebegin("Redline.PoliceMissions")
	Getaway.step(dt)
	debug.profileend()
end)
print(
	"[REDLINE COUNTY] Getaway contracts + AI police ready. Saved garage with local practice fallback; Studio development build."
)
