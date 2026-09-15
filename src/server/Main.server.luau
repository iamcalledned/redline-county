--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Config = require(ReplicatedStorage.Shared.Config)
local Driving = require(ReplicatedStorage.Shared.Driving)
local Rules = require(ReplicatedStorage.Shared.Rules)
local Course = require(script.Parent.Course)
local Vehicle = require(script.Parent.Vehicle)
local Highway = require(script.Parent.Highway)
local HighwayMath = require(ReplicatedStorage.Shared.HighwayMath)
local Traffic = require(script.Parent.Traffic)
local CrashEffect = require(script.Parent.CrashEffect)
local CrashMath = require(ReplicatedStorage.Shared.CrashMath)

-- This local handling lab must be deliberately redesigned before public release.
if not RunService:IsStudio() then
	warn("[REDLINE COUNTY] Development build disabled outside Studio.")
	return
end

for _, name in { "Cars", "Characters", "Traffic" } do
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
Course.build()
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "Vehicles", workspace
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
	previousTime: number,
	crashUntil: number,
	crashKind: string,
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
	if state.car then
		state.car.Model:Destroy()
		state.car = nil
	end
	state.throttle, state.steer, state.drift = 0, 0, false
	state.previousCF = nil
end

local function freePad(exclude: Model?): CFrame?
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
		if workspace:Raycast(root.Position, car.Seat.Position - root.Position, ray) then
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
		not Rules.canSpawn(
			(root.Position - Course.Garage).Magnitude,
			speed,
			other,
			now,
			state.nextSpawn,
			Config.Lifecycle
		)
	then
		tell(player, "Stop at the garage to change cars; spawn cooldown is 4 seconds.")
		return
	end
	if not old and #folder:GetChildren() >= Config.MaxVehicles then
		tell(player, "All 12 vehicles are in use. Try again shortly.")
		return
	end
	local pad = if initial then Highway.entry() else freePad(if old then old.Model else nil)
	if not pad then
		tell(player, "All four bays are occupied. Clear a bay and try again.")
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
	state.lastOccupied = now
	state.trip, state.lastHighwayZ = 0, nil
	car.Model:SetAttribute("TurboEnabled", state.turboEnabled)
	if initial then
		car.Model:SetAttribute("Highway", true)
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
			else kind .. " ready. Press E beside your car."
	)
end

local function resetCar(player: Player)
	local state, root = states[player], rootOf(player)
	if not state or not state.car or not root then
		return
	end
	local car, now = state.car, os.clock()
	if now < state.nextReset then
		tell(player, "Recovery cooling down.")
		return
	end
	if
		not Rules.canReset(
			car.Body.AssemblyLinearVelocity.Magnitude,
			car.Body.CFrame.UpVector.Y,
			driving(player, car),
			(root.Position - car.Body.Position).Magnitude,
			Config.Lifecycle
		)
	then
		tell(player, "Stop first, or slow down while overturned. Stay beside your own car.")
		return
	end
	local pad = freePad(car.Model)
	if not pad then
		tell(player, "Garage bays occupied. Recovery waits for a clear bay.")
		return
	end
	state.nextReset = now + Config.ResetCooldown
	state.throttle, state.steer, state.drift = 0, 0, false
	car.Model:SetAttribute("Highway", false)
	state.lastHighwayZ = nil
	state.previousCF = nil
	car.Model:PivotTo(pad)
	car.Body.AssemblyLinearVelocity, car.Body.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	car.Align.CFrame = pad.Rotation
	car.Body:SetNetworkOwner(nil)
	tell(player, "Recovered to the garage.")
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

request.OnServerEvent:Connect(function(player: Player, action: any, kind: any)
	local state, now = states[player], os.clock()
	if not state or not Rules.consume(state.requestBucket, now, 2, 3) then
		return
	end
	if state.crashUntil > 0 then
		tell(player, "Crash recovery in progress…")
		return
	end
	if action == "Spawn" and type(kind) == "string" and #kind <= 20 then
		spawnCar(player, kind)
	elseif action == "Reset" then
		resetCar(player)
	elseif action == "Highway" then
		enterHighway(player)
	elseif action == "Turbo" and state.car and driving(player, state.car) then
		state.turboEnabled = not state.turboEnabled
		state.car.Model:SetAttribute("TurboEnabled", state.turboEnabled)
		tell(
			player,
			if state.turboEnabled then "Turbo armed: accelerate to build boost." else "Turbo switched off."
		)
	end
end)

local function joined(player: Player)
	if states[player] then
		return
	end
	local now = os.clock()
	states[player] = {
		car = nil,
		throttle = 0,
		steer = 0,
		drift = false,
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
				spawnCar(player, "Compact", true)
			end
		end)
	end
	player.CharacterAdded:Connect(characterAdded)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end
Players.PlayerAdded:Connect(joined)
Players.PlayerRemoving:Connect(function(player)
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
		local car = state.car
		if not car then
			continue
		end
		local occupied = driving(player, car)
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
			state.previousCF, state.previousTime = car.Body.CFrame, trafficTime
			if car.TelemetryClock == 0 then
				car.Model:SetAttribute("TripStuds", math.floor(state.trip))
			end
		end
	end
end)
print("[REDLINE COUNTY] Autobahn + turbo prototype ready. Server-owned chassis; no economy or persistence.")
