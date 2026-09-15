--!strict
local GarageRules = require("../src/shared/GarageRules")
local TownDriving = require("../src/shared/TownDriving")
local DrivingMetrics = require("../src/shared/DrivingMetrics")
local ModelFit = require("../src/shared/ModelFit")
local Units = require("../src/shared/Units")
local HeadlightMath = require("../src/shared/HeadlightMath")
local Driving = require("../src/shared/Driving")
local Rules = require("../src/shared/Rules")
local CrashMath = require("../src/shared/CrashMath")
local TrafficMath = require("../src/shared/TrafficMath")
local Turbo = require("../src/shared/Turbo")
local HighwayMath = require("../src/shared/HighwayMath")
local limits = { GarageRadius = 68, StopSpeed = 8, ResetReach = 16, FlippedUp = 0.25, FlippedSpeed = 22 }
local passed = 0
local function test(name: string, fn: () -> ())
	fn()
	passed += 1
	print("PASS " .. name)
end
local tune = {
	TopSpeed = 95,
	BoostSpeed = 100,
	BoostAcceleration = 1.65,
	ReverseSpeed = 28,
	Acceleration = 43,
	Brake = 85,
	Grip = 8,
	DriftGrip = 1.1,
	DriftTurn = 1.7,
	DriftMinSpeed = 18,
	DriftDrag = 0.06,
	Turn = 1.5,
}
test("reject malformed/nonfinite/out-of-range remote values", function()
	for _, bad in { "1", {}, math.huge, -math.huge, 0 / 0, 1.01, -1.01 } do
		assert(not Driving.validInput(bad, 0, false), "reject malformed/nonfinite/out-of-range remote values")
		assert(not Driving.validInput(0, bad, false), "reject malformed/nonfinite/out-of-range remote values")
	end
	assert(not Driving.validInput(nil, 0, false), "reject malformed/nonfinite/out-of-range remote values")
	assert(not Driving.validInput(0, 0, 1), "reject malformed/nonfinite/out-of-range remote values")
	assert(Driving.validInput(-1, 1, true), "reject malformed/nonfinite/out-of-range remote values")
end)
test("forward, reverse, speed limiting and braking", function()
	assert(Driving.forces(0, 0, 1, 0, false, tune) == 43, "forward, reverse, speed limiting and braking")
	assert(Driving.forces(0, 0, -1, 0, false, tune) == -43, "forward, reverse, speed limiting and braking")
	assert(Driving.forces(95, 0, 1, 0, false, tune) == 0, "forward, reverse, speed limiting and braking")
	assert(Driving.forces(-28, 0, -1, 0, false, tune) == 0, "forward, reverse, speed limiting and braking")
	assert(Driving.forces(60, 0, -1, 0, false, tune) == -85, "forward, reverse, speed limiting and braking")
	assert(Driving.forces(-15, 0, 1, 0, false, tune) == 85, "forward, reverse, speed limiting and braking")
end)
test("drift loses lateral grip and release restores it", function()
	local _, grip = Driving.forces(50, 12, 1, 0, false, tune)
	local _, slide = Driving.forces(50, 12, 1, 0, true, tune)
	assert(grip < slide and slide < 0, "drift loses lateral grip and release restores it")
	local _, opposite = Driving.forces(50, -12, 1, 0, false, tune)
	assert(opposite == -grip, "drift loses lateral grip and release restores it")
end)
test("drift initiates stronger yaw while preserving powered momentum", function()
	local normalAcceleration, _, normalTurn = Driving.forces(50, 0, 1, 1, false, tune)
	local slideAcceleration, _, slideTurn = Driving.forces(50, 0, 1, 1, true, tune)
	assert(
		math.abs(slideTurn) > math.abs(normalTurn) * 1.5,
		"drift must turn the body more than normal steering"
	)
	assert(slideAcceleration > normalAcceleration * 0.8, "drift should preserve powered momentum")
	local _, _, straight = Driving.forces(50, 0, 1, 0, true, tune)
	assert(straight == 0, "drift must not spin the car without steering")
end)
test("drift preserves low-speed and reverse control", function()
	for _, speed in { 0, 10, -25 } do
		local a, b, c = Driving.forces(speed, 3, 0, 1, false, tune)
		local x, y, z = Driving.forces(speed, 3, 0, 1, true, tune)
		assert(a == x and b == y and c == z, "drift should activate only at forward driving speed")
	end
end)
test("reverse steering and stationary steering", function()
	local _, _, forward = Driving.forces(25, 0, 0, 1, false, tune)
	local _, _, reverse = Driving.forces(-25, 0, 0, 1, false, tune)
	local _, _, still = Driving.forces(0, 0, 0, 1, false, tune)
	assert(forward < 0 and reverse > 0 and still == 0, "reverse steering and stationary steering")
end)
test("input smoothing is independent of frame subdivision", function()
	local whole = Driving.approach(0, 1, 9, 1 / 30)
	local half = Driving.approach(Driving.approach(0, 1, 9, 1 / 60), 1, 9, 1 / 60)
	assert(math.abs(whole - half) < 1e-10, "input smoothing is independent of frame subdivision")
end)
test("remote flood rejected and tokens recover", function()
	local bucket = { tokens = 3, updated = 0 }
	for _ = 1, 3 do
		assert(Rules.consume(bucket, 0, 2, 3), "remote flood rejected and tokens recover")
	end
	assert(not Rules.consume(bucket, 0, 2, 3), "remote flood rejected and tokens recover")
	assert(not Rules.consume(bucket, 0.2, 2, 3), "remote flood rejected and tokens recover")
	assert(Rules.consume(bucket, 0.5, 2, 3), "remote flood rejected and tokens recover")
	assert(not Rules.consume(bucket, 0.5, 2, 3), "remote flood rejected and tokens recover")
end)
test("moving and remote vehicle resets rejected", function()
	assert(not Rules.canReset(40, 1, true, 0, limits), "moving and remote vehicle resets rejected")
	assert(not Rules.canReset(0, 1, false, 100, limits), "moving and remote vehicle resets rejected")
	assert(Rules.canReset(0, 1, true, 0, limits), "moving and remote vehicle resets rejected")
	assert(Rules.canReset(15, -1, true, 0, limits), "moving and remote vehicle resets rejected")
	assert(not Rules.canReset(25, -1, true, 0, limits), "moving and remote vehicle resets rejected")
end)
test("spawn distance, cooldown, occupancy and speed enforced", function()
	assert(
		Rules.canSpawn(5, 0, false, 10, 10, limits),
		"spawn distance, cooldown, occupancy and speed enforced"
	)
	assert(
		not Rules.canSpawn(70, 0, false, 10, 10, limits),
		"spawn distance, cooldown, occupancy and speed enforced"
	)
	assert(
		not Rules.canSpawn(5, 20, false, 10, 10, limits),
		"spawn distance, cooldown, occupancy and speed enforced"
	)
	assert(
		not Rules.canSpawn(5, 0, true, 10, 10, limits),
		"spawn distance, cooldown, occupancy and speed enforced"
	)
	assert(
		not Rules.canSpawn(5, 0, false, 9, 10, limits),
		"spawn distance, cooldown, occupancy and speed enforced"
	)
end)
local turboTune = {
	SpoolSeconds = 1.2,
	DecaySeconds = 0.5,
	HeatRate = 0.12,
	CoolRate = 0.22,
	RestartHeat = 0.35,
	MinSpeed = 15,
}
test("turbo spools under load, raises performance, stops on lift", function()
	local state = { boost = 0, heat = 0, overheated = false }
	local boost = Turbo.step(state, 0.1, true, 1, 50, false, turboTune)
	assert(boost > 0 and boost < 0.1, "turbo should build gradually")
	for _ = 1, 20 do
		boost = Turbo.step(state, 0.1, true, 1, 50, false, turboTune)
	end
	assert(boost > 0.99, "turbo should reach full boost")
	assert(Driving.forces(150, 0, 1, 0, false, tune, 0) < 0, "cooling must slow the car toward stock speed")
	assert(Driving.forces(100, 0, 1, 0, false, tune, boost) > 0, "turbo should pull beyond stock top speed")
	assert(Driving.forces(195, 0, 1, 0, false, tune, boost) == 0, "boosted top speed remains bounded")
	assert(Turbo.step(state, 0.1, true, 0, 80, false, turboTune) == 0, "lifting removes power immediately")
	assert(Turbo.step(state, 0.1, false, 1, 80, false, turboTune) == 0, "disabled turbo supplies no power")
	assert(Turbo.step(state, 0.1, true, 1, -20, false, turboTune) == 0, "no boost in reverse")
	assert(Turbo.step(state, 0.1, true, 1, 80, true, turboTune) == 0, "no boost while drifting")
end)
test("turbo heat protection cannot be bypassed by toggling", function()
	local state = { boost = 0, heat = 0, overheated = false }
	for _ = 1, 150 do
		Turbo.step(state, 0.1, true, 1, 80, false, turboTune)
		if state.overheated then
			break
		end
	end
	assert(state.overheated, "sustained full boost must trigger heat protection")
	assert(Turbo.step(state, 0.1, false, 1, 80, false, turboTune) == 0, "disabled during overheat")
	assert(Turbo.step(state, 0.1, true, 1, 80, false, turboTune) == 0, "toggle must not reset heat lock")
	for _ = 1, 40 do
		Turbo.step(state, 0.1, false, 0, 0, false, turboTune)
	end
	assert(not state.overheated and state.heat < 0.35, "turbo cools and unlocks")
	assert(Turbo.step(state, 0.1, true, 1, 80, false, turboTune) > 0, "cooled turbo works again")
end)
test("highway wraps both ways without inflating distance", function()
	assert(HighwayMath.wrap(-4097, 4096) == 4095, "forward crossing")
	assert(HighwayMath.wrap(4097, 4096) == -4095, "reverse crossing")
	assert(HighwayMath.travel(-4090, 4090, 4096, 20) == 12, "trip counts movement across seam")
	assert(HighwayMath.travel(0, 3000, 4096, 20) == 0, "teleports do not count as distance")
	local trip, previous = 0, 0
	for _ = 1, 100000 do
		local nextZ = HighwayMath.wrap(previous - 21, 4096)
		trip += HighwayMath.travel(previous, nextZ, 4096, 22)
		assert(nextZ >= -4096 and nextZ < 4096, "coordinates stay bounded")
		previous = nextZ
	end
	assert(trip == 2100000, "long runs preserve exact cumulative distance")
end)
test("highway preloads recycle targets and retains separated players", function()
	local needed = HighwayMath.needed({ -4090, 0 }, 512, 3, 4096)
	assert(needed[7] and needed[-8] and needed[0], "both sides of seam and other player retained")
	local allPositions = {}
	for z = -4096, 4095, 64 do
		table.insert(allPositions, z)
	end
	local all = HighwayMath.needed(allPositions, 512, 3, 4096)
	local count = 0
	for _ in all do
		count += 1
	end
	assert(count <= 32, "section count bounded even with widely separated players")
	assert(next(HighwayMath.needed({}, 512, 3, 4096)) == nil, "empty highway needs no sections")
	local one = HighwayMath.needed({ 0 }, 512, 3, 4096)
	assert(not one[7], "unused distant road can be unloaded")
end)
test("traffic follows both carriageways and keeps lane spacing", function()
	for lane = 1, 6 do
		local x, z, direction = TrafficMath.position(lane, 0, 0, 4096, 12)
		local nextX, nextZ = TrafficMath.position(lane, 0, 1, 4096, 12)
		assert(x == nextX and math.abs(x) >= 15 and math.abs(x) <= 51, "traffic stays inside a lane")
		assert((nextZ - z) * direction > 0, "traffic moves in its declared direction")
		assert(x * direction < 0, "right carriageway travels forward; left travels back")
		local _, followingZ = TrafficMath.position(lane, 1, 10000, 4096, 12)
		local _, leadingZ = TrafficMath.position(lane, 0, 10000, 4096, 12)
		assert(
			math.abs(HighwayMath.wrap(followingZ - leadingZ, 4096)) > 600,
			"same-lane spacing is preserved"
		)
	end
end)
test("traffic remains bounded during long runs and inner lanes pass faster", function()
	for lane = 1, 6 do
		for slot = 0, 11 do
			local _, z = TrafficMath.position(lane, slot, 1000000, 4096, 12)
			assert(z >= -4096 and z < 4096, "traffic must recycle inside the road span")
		end
	end
	local _, innerStart = TrafficMath.position(1, 0, 0, 4096, 12)
	local _, innerEnd = TrafficMath.position(1, 0, 1, 4096, 12)
	local _, outerStart = TrafficMath.position(3, 0, 0, 4096, 12)
	local _, outerEnd = TrafficMath.position(3, 0, 1, 4096, 12)
	assert(
		math.abs(innerEnd - innerStart) > math.abs(outerEnd - outerStart),
		"passing lane should move faster"
	)
end)
test("swept crashes catch fast traffic crossings and stationary overlaps", function()
	local hit = CrashMath.sweep({ 0, 0, -100 }, { 0, 0, 100 }, { 6, 2, 10 })
	assert(hit and math.abs(hit - 0.45) < 1e-9, "detect impact even when neither endpoint overlaps")
	assert(CrashMath.sweep({ 0, 0, 0 }, { 0, 0, 0 }, { 6, 2, 10 }) == 0, "detect existing contact")
	assert(
		CrashMath.sweep({ 0, 0, 100 }, { 0, 0, -100 }, { 6, 2, 10 }) ~= nil,
		"detect rear and opposing impacts"
	)
end)
test("collision sweep rejects near misses and airborne clearance", function()
	assert(
		CrashMath.sweep({ 7, 0, -100 }, { 7, 0, 100 }, { 6, 2, 10 }) == nil,
		"nearby lane is not a collision"
	)
	assert(
		CrashMath.sweep({ 0, 5, -100 }, { 0, 5, 100 }, { 6, 2, 10 }) == nil,
		"a car well above traffic does not hit"
	)
	assert(CrashMath.sweep({ 0, 0, 30 }, { 0, 0, 40 }, { 6, 2, 10 }) == nil, "moving away must not hit")
	assert(
		CrashMath.sweep({ 0, 0, 0, 20 }, { 0, 0, 0, 20 }, { 6, 2, 10, 5 }) == nil,
		"oriented separating axes reject corner false positives"
	)
end)
test("one crash per car and starting lane outside all traffic", function()
	assert(CrashMath.canBegin(false, true), "first collision crashes")
	assert(
		not CrashMath.canBegin(true, true),
		"repeated contact must not restart recovery or duplicate replacement"
	)
	assert(not CrashMath.canBegin(false, false), "no contact means no crash")
	for lane = 1, 6 do
		local x = TrafficMath.position(lane, 0, 0, 4096, 12)
		assert(math.abs(105 - x) > 30, "on-ramp launch lane must be separated from traffic")
	end
end)
test("speed and distance use actual metric conversions", function()
	assert(math.abs(Units.kmh(100) - 100.8) < 1e-8, "100 studs/s is 100.8 km/h")
	assert(math.abs(Units.kmh(Units.fromKmh(230)) - 230) < 1e-8, "km/h tuning round trip")
	assert(math.abs(Units.mph(Units.fromKmh(160.9344)) - 100) < 1e-8, "mph conversion")
	assert(Units.kmh(-100) == Units.kmh(100), "reverse speed display is absolute")
	assert(Units.kilometres(1000) == 0.28, "trip distance is kilometres, not thousands of studs")
end)
test("headlights change only range and keep a finite reach", function()
	local lights = {
		LowRange = 36,
		HighRange = 120,
		Angle = 60,
		Brightness = 3,
		FullBeamKmh = 180,
	}
	local lowRange, lowAngle, lowBrightness = HeadlightMath.beam(0, lights)
	local midRange, midAngle, midBrightness = HeadlightMath.beam(90, lights)
	local highRange, highAngle, highBrightness = HeadlightMath.beam(180, lights)
	assert(lowRange < midRange and midRange < highRange, "beam reaches farther as speed rises")
	assert(lowAngle == midAngle and midAngle == highAngle, "beam angle stays fixed to the headlights")
	assert(lowBrightness == midBrightness and midBrightness == highBrightness, "brightness stays constant")
	assert(HeadlightMath.beam(10000, lights) == 120, "range clamps at supported high beam target")
	assert(HeadlightMath.beam(-10, lights) == 36, "low-speed beam stays on")
end)
test("gentler steering preserves direction and speed taper", function()
	local softened = table.clone(tune)
	softened.Turn *= 0.85
	local _, _, original = Driving.forces(60, 0, 0, 1, false, tune)
	local _, _, gentle = Driving.forces(60, 0, 0, 1, false, softened)
	local _, _, fast = Driving.forces(250, 0, 0, 1, false, softened)
	assert(math.abs(gentle / original - 0.85) < 1e-8, "15 percent less turning")
	assert(math.abs(fast) < math.abs(gentle), "high speed steering stays damped")
	assert(Driving.approach(0, 1, 7, 0.1) < Driving.approach(0, 1, 9, 0.1), "smoother steering onset")
	local low = Driving.forces(20, 0, 1, 0, false, tune)
	local high = Driving.forces(70, 0, 1, 0, false, tune)
	assert(low > high and high > 0, "power falls off progressively as speed rises")
end)
test("imported driver stays aligned when scaling a model far from the origin", function()
	-- A seat two studs behind a pivot at Z=100, scaled by half, must finish
	-- one stud behind the centred car. The old origin scaling gave -49.
	assert(ModelFit.coordinate(102, 100, 0.5, 100) == 1, "seat must remain inside the centred car")
	assert(
		ModelFit.coordinate(10002, 10000, 0.5, 10000) == 1,
		"positive world translation must not change fit"
	)
	assert(
		ModelFit.coordinate(-998, -1000, 0.5, -1000) == 1,
		"negative world translation must not change fit"
	)
	-- Preserve relative placement of the seat and a dashboard point at any scale.
	for _, scale in { 0.25, 0.5, 1, 1.6, 2 } do
		local seat = ModelFit.coordinate(102, 100, scale, 97)
		local dash = ModelFit.coordinate(98, 100, scale, 97)
		assert(math.abs((seat - dash) - 4 * scale) < 0.000001, "seat/dashboard spacing must scale together")
	end
end)

test("garage selection rejects remote, moving, occupied, duplicate and cooldown requests", function()
	assert(GarageRules.canSelect(20, 0, false, false, 10, 0), "valid walk-up selection")
	assert(not GarageRules.canSelect(86, 0, false, false, 10, 0), "remote selection")
	assert(not GarageRules.canSelect(20, 3, false, false, 10, 0), "moving car")
	assert(not GarageRules.canSelect(20, 0, true, false, 10, 0), "occupied by another player")
	assert(not GarageRules.canSelect(20, 0, false, true, 10, 0), "duplicate in-flight spawn")
	assert(not GarageRules.canSelect(20, 0, false, false, 10, 11), "cooldown")
end)
test("garage doors validate owner, reach and closing clearance", function()
	assert(GarageRules.canUseDoor(1, 1, 10, false), "owner can operate door")
	assert(not GarageRules.canUseDoor(1, 2, 10, false), "another player's door")
	assert(not GarageRules.canUseDoor(1, 1, 17, false), "remote door request")
	assert(not GarageRules.canUseDoor(1, 1, 10, true), "obstruction keeps door open")
end)
test("town steering has a finite turning radius and tapers at speed", function()
	assert(TownDriving.yaw(0, 1, 12) == 0, "no turning at rest")
	assert(
		TownDriving.wheelRotation(10, 0.1, 1) == -1,
		"forward -Z travel rotates tyres in the rolling direction"
	)
	local slow = TownDriving.steerAngle(5, 1)
	assert(slow > TownDriving.steerAngle(50, 1), "steering authority tapers")
	assert(TownDriving.yaw(-5, 1, 12) > 0 and TownDriving.yaw(5, 1, 12) < 0, "reverse steering")
	assert(
		math.abs(TownDriving.yaw(5, 1, 12)) < math.abs(TownDriving.yaw(5, 1, 9)),
		"longer wheelbase turns wider"
	)
	assert(12 / math.tan(slow) * 0.28 > 5, "plausible low-speed radius")
end)
test("town damage is graduated and parking taps stay recoverable", function()
	assert(GarageRules.damage(8) == 0, "parking tap")
	assert(GarageRules.damage(20) == 10, "minor contact")
	assert(GarageRules.damage(50) == 30, "moderate impact")
	assert(GarageRules.damage(80) == 60, "severe impact does not instantly explode")
end)
test("driving diagnostics integrate stopping distance from sampled speed", function()
	local state = DrivingMetrics.new()
	state.previous = 36
	for i = 1, 100 do
		DrivingMetrics.step(state, 36 * (1 - i / 100), -1, 0.1)
	end
	assert(
		state.lastStop ~= nil and math.abs((state.lastStop or 0) - 50) < 0.2,
		"linear 10 m/s stop over ten seconds travels 50 m"
	)
	assert(state.lastFrom == 36, "record starting speed")
end)

local GetawayRules = require("../src/shared/GetawayRules")
local Nav = require("../src/shared/RoadNavigation")
local Roads = require("../src/shared/RoadGraph")
local Contracts = require("../src/shared/Contracts")
local function sample(): GetawayRules.Sample
	return {
		valid = true,
		atCheckpoint = false,
		atHome = false,
		seen = false,
		nearCop = false,
		slow = false,
		stopped = false,
		policeReady = true,
	}
end
test("getaway requires pickup, sight break and stopped delivery; pays only once", function()
	local job = GetawayRules.new(1, 240, 1)
	local s = sample()
	s.atHome = true
	s.slow = true
	s.stopped = true
	for _ = 1, 50 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.phase == "pickup", "home alone cannot earn a reward")
	s.atCheckpoint = true
	assert(GetawayRules.step(job, 0.1, s) == "alarm", "pickup raises the alarm")
	s.atCheckpoint = false
	s.seen = true
	for _ = 1, 50 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.escape == 0, "seen players cannot escape")
	s.seen = false
	for _ = 1, 40 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.phase == "deliver", "ten unseen seconds unlock delivery")
	s.slow = false
	s.stopped = false
	for _ = 1, 12 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.phase == "deliver", "must stop for delivery")
	s.slow = true
	s.stopped = true
	local rewards = 0
	for _ = 1, 20 do
		if GetawayRules.step(job, 0.25, s) == "reward" then
			rewards += 1
		end
	end
	assert(rewards == 1 and job.phase == "complete", "terminal state prevents duplicate payouts")
end)
test("multi-stash mission holds escape until all ordered checkpoints", function()
	local job = GetawayRules.new(3, 240, 2)
	local s = sample()
	s.atCheckpoint = true
	GetawayRules.step(job, 0.1, s)
	s.atCheckpoint = false
	for _ = 1, 80 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.phase == "run" and job.checkpoint == 2, "second stash is required")
	s.atCheckpoint = true
	GetawayRules.step(job, 0.1, s)
	assert(job.checkpoint == 3 and job.phase == "run", "third stash is required")
	GetawayRules.step(job, 0.1, s)
	assert(job.phase == "escape", "escape remains active before a terminal result")
end)
test("police catch needs proximity plus low speed and escape resets on sight", function()
	local job = GetawayRules.new(1, 240, 1)
	local s = sample()
	s.atCheckpoint = true
	GetawayRules.step(job, 0.1, s)
	s.atCheckpoint = false
	s.nearCop = true
	s.seen = true
	for _ = 1, 40 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.busted == 0, "fast drive-by is not a bust")
	s.slow = true
	s.stopped = true
	for _ = 1, 19 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.phase == "escape", "escape remains active before a terminal result")
	assert(GetawayRules.step(job, 0.25, s) == "busted", "five held seconds bust the player")
	assert(GetawayRules.step(job, 0.25, s) == nil, "terminal result cannot repeat")
	job = GetawayRules.new(1, 240, 1)
	s = sample()
	s.atCheckpoint = true
	GetawayRules.step(job, 0.1, s)
	s.atCheckpoint = false
	for _ = 1, 39 do
		GetawayRules.step(job, 0.25, s)
	end
	s.seen = true
	GetawayRules.step(job, 0.1, s)
	assert(job.escape == 0, "escape counter resets without valid unseen time")
	s.seen = false
	for _ = 1, 40 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.phase == "deliver", "ten unseen seconds unlock delivery")
	s.seen = true
	assert(
		GetawayRules.step(job, 0.1, s) == "spotted" and job.phase == "escape",
		"being seen again cancels delivery"
	)
end)
test("missing police cannot grant free escape; timeout and lost vehicle fail", function()
	local job = GetawayRules.new(1, 240, 1)
	local s = sample()
	s.atCheckpoint = true
	GetawayRules.step(job, 0.1, s)
	s.atCheckpoint = false
	s.policeReady = false
	for _ = 1, 60 do
		GetawayRules.step(job, 0.25, s)
	end
	assert(job.escape == 0, "escape counter resets without valid unseen time")
	s.valid = false
	assert(GetawayRules.step(job, 0.1, s) == "vehicle_lost", "missing vehicle fails the job")
	job = GetawayRules.new(1, 0.2, 1)
	s = sample()
	assert(GetawayRules.step(job, 0.25, s) == "timeout", "expired deadline fails the job")
end)
test("road routing respects one-way streets and never cuts the inside of a block", function()
	local graph: Nav.Graph = {
		{ x = 0, z = 0, links = { 2 } },
		{ x = 100, z = 0, links = { 3 } },
		{ x = 100, z = 100, links = { 4 } },
		{ x = 0, z = 100, links = { 1 } },
	}
	local path = Nav.route(graph, { x = 80, z = 0 }, { x = 20, z = 0 })
	assert(#path >= 5, "reverse on one-way must go around the block")
	local total = 0
	for i = 1, #path - 1 do
		total += Nav.distance(path[i], path[i + 1])
	end
	assert(math.abs(total - 340) < 0.001, "one-way detour goes around the full block")
	assert(Nav.ahead(path, 50) ~= nil, "route provides a steering target")
	local split: Nav.Graph = {
		{ x = 0, z = 0, links = { 2 } },
		{ x = 10, z = 0, links = {} },
		{ x = 100, z = 0, links = { 4 } },
		{ x = 110, z = 0, links = {} },
	}
	assert(
		#Nav.route(split, { x = 5, z = 0 }, { x = 105, z = 0 }) == 0,
		"unreachable route must not become a straight line"
	)
end)
test("every contract routes from home through its stashes and back on connected road edges", function()
	local graph = Roads.Nodes
	for _, contract in Contracts do
		local from: Nav.Point = graph[Roads.Home]
		local goals: { Nav.Point } = {}
		for _, index in contract.Checkpoints do
			table.insert(goals, graph[(if contract.Parkway then Roads.Course else Roads.Route)[index]])
		end
		table.insert(goals, graph[Roads.Home])
		for _, goal in goals do
			local path = Nav.route(graph, from, goal)
			assert(#path >= 2, contract.Name .. " cannot reach objective")
			for i = 1, #path - 1 do
				local a, b = path[i], path[i + 1]
				local _, _, _, gap = Nav.project(graph, { x = (a.x + b.x) / 2, z = (a.z + b.z) / 2 })
				assert(gap < 0.001, "navigation shortcut leaves pavement")
			end
			from = goal
		end
	end
	assert(Roads.Route[1] == Roads.Route[#Roads.Route], "town loop closes")
end)
test("police controller slows for corners, steers both ways and turns toward targets behind", function()
	local throttle, steer = Nav.controls(0, 40, 20, 10.4)
	assert(throttle > 0 and steer == 0, "accelerate on the straight")
	throttle, steer = Nav.controls(20, 10, 60, 10.4)
	assert(throttle < 0 and steer > 0, "brake and steer right into a bend")
	local _, left = Nav.controls(-20, 10, 20, 10.4)
	assert(left < 0, "left target produces left steering")
	local _, behind = Nav.controls(0, -10, 10, 10.4)
	assert(math.abs(behind) == 1, "target behind needs a turn")
end)

-- Kinematic controller regression only: no Roblox suspension, friction or contacts.
test("police controller follows all five mission legs and brakes before the final sharp turn", function()
	local graph = Roads.Nodes
	for _, pair in { { 3, 11 }, { 11, 13 }, { 13, 19 }, { 19, 53 }, { 53, 3 } } do
		local start, goal = graph[Roads.Route[pair[1]]], graph[Roads.Route[pair[2]]]
		local p = { x = start.x, z = start.z }
		local path = Nav.route(graph, p, goal)
		local aim = Nav.ahead(path, 18)
		assert(aim, "initial route has an aim point")
		local heading = math.atan2(aim.x - p.x, -(aim.z - p.z))
		local speed, maxGap, finished = 0, 0, false
		for frame = 1, 10800 do
			if frame % 12 == 1 then
				path = Nav.route(graph, p, goal)
			end
			aim = Nav.ahead(path, math.clamp(8 + math.abs(speed) * 0.45, 12, 34))
			assert(aim, "route still has an aim point")
			local dx, dz = aim.x - p.x, aim.z - p.z
			local side = dx * math.cos(heading) + dz * math.sin(heading)
			local forward = dx * math.sin(heading) - dz * math.cos(heading)
			local throttle, steer = Nav.controls(side, forward, speed, 10.4, Nav.cornerSpeed(path))
			speed = math.max(
				0,
				speed
					+ (
							if throttle < 0
								then -29
								elseif throttle > 0 then 14 / (1 + (speed / 46) ^ 2)
								else -speed * 0.65
						)
						/ 60
			)
			heading -= TownDriving.yaw(speed, steer, 10.4) / 60
			p.x += math.sin(heading) * speed / 60
			p.z -= math.cos(heading) * speed / 60
			local _, _, _, gap = Nav.project(graph, p)
			maxGap = math.max(maxGap, gap)
			if Nav.distance(p, goal) < 22 then
				finished = true
				break
			end
		end
		assert(finished, "controller cannot reach " .. pair[2])
		assert(maxGap < 12.5, "controller cuts outside the road center corridor at " .. pair[2])
	end
end)

local Progression = require("../src/shared/Progression")
local DriftRules = require("../src/shared/DriftRules")
local TownTrafficMath = require("../src/shared/TownTrafficMath")
test("workshop purchases validate balance, location, job and tier without charging twice", function()
	local levels = Progression.levels()
	assert(
		Progression.buy(499, levels, "Power", true, false) == 499 and levels.Power == 0,
		"insufficient balance"
	)
	assert(
		Progression.buy(500, levels, "Power", false, false) == 500 and levels.Power == 0,
		"remote purchase"
	)
	assert(
		Progression.buy(500, levels, "Power", true, true) == 500 and levels.Power == 0,
		"no upgrades on job"
	)
	local cash = Progression.buy(500, levels, "Power", true, false)
	assert(cash == 0 and levels.Power == 1, "one debit, one level")
	assert(
		Progression.buy(cash, levels, "Power", true, false) == cash and levels.Power == 1,
		"repeated purchase cannot reuse spent cash"
	)
	cash = Progression.buy(5000, levels, "Power", true, false)
	cash = Progression.buy(cash, levels, "Power", true, false)
	assert(levels.Power == 3 and cash == 1700, "tier pricing")
	assert(Progression.buy(cash, levels, "Power", true, false) == cash and levels.Power == 3, "max tier")
	assert(Progression.buy(cash, levels, "Exploit", true, false) == cash, "unknown upgrade")
	assert(Progression.levels().Power == 0, "another car starts stock")
end)
test("installed upgrades change force, grip and suspension response", function()
	local f = Progression.factors({ Power = 3, Brakes = 2, Tyres = 1, Suspension = 3 })
	local upgraded = table.clone(tune)
	upgraded.Acceleration *= f.Acceleration
	upgraded.TopSpeed *= f.TopSpeed
	upgraded.Brake *= f.Brake
	upgraded.Grip *= f.Grip
	assert(
		Driving.forces(30, 0, 1, 0, false, upgraded) > Driving.forces(30, 0, 1, 0, false, tune),
		"power accelerates faster"
	)
	assert(
		Driving.forces(30, 0, -1, 0, false, upgraded) < Driving.forces(30, 0, -1, 0, false, tune),
		"braking force increases"
	)
	local _, stock = Driving.forces(30, 8, 1, 1, false, tune)
	local _, grip = Driving.forces(30, 8, 1, 1, false, upgraded)
	assert(grip < stock, "tyres resist lateral slip more")
	local base = Progression.spring(2.25, 2, 0, 196.2, 135, 11)
	assert(
		Progression.spring(2.25, 2, 0, 196.2, 135 * f.Spring, 11 * f.Damping) > base,
		"spring compression response"
	)
	assert(
		Progression.spring(2.25, 2, 3, 196.2, 135, 11 * f.Damping)
			< Progression.spring(2.25, 2, 3, 196.2, 135, 11),
		"damping resists bounce"
	)
end)
test("suspension settles after a drop at stock and upgraded settings", function()
	for _, level in { 0, 3 } do
		local f = Progression.factors({ Power = 0, Brakes = 0, Tyres = 0, Suspension = level })
		for _, dt in { 1 / 20, 1 / 30, 1 / 60, 1 / 120 } do
			local y, v = 3, 0
			for _ = 1, math.floor(5 / dt) do
				local support = if y <= 3.6
					then 4 * Progression.spring(2.25, y, v, 196.2, 135 * f.Spring, 11 * f.Damping, dt)
					else 0
				v += (support - 196.2) * dt
				y += v * dt
				assert(y > 1 and y < 4, "bounded flat-ground suspension")
			end
			assert(math.abs(y - 2.25) < 0.01 and math.abs(v) < 0.01, "settles without sustained bounce")
		end
	end
end)
test("traffic risk and clean delivery award predictable money", function()
	assert(Progression.payout(300, 60, "light", 10) == 420, "base plus time")
	assert(Progression.payout(300, 60, "busy", 10) == 630, "busy 1.5x")
	assert(Progression.payout(300, 60, "rush", 10) == 924, "rush 2.2x")
	assert(Progression.payout(300, 60, "light", 0) == 504, "clean 20 percent bonus")
	assert(Progression.payout(300, -2, "light", 10) == 300, "no negative time")
	assert(Progression.payout(300, 60, "invalid", 0) == 0, "unknown tier")
end)
test("town handbrake retains drift yaw and restores grip on release", function()
	assert(
		math.abs(TownDriving.yaw(50, 1, 10, true, 18, 1.7)) > math.abs(TownDriving.yaw(50, 1, 10, false)),
		"town branch must not overwrite drift yaw"
	)
	for _, speed in { 0, 10, -25 } do
		assert(
			TownDriving.yaw(speed, 1, 10, true) == TownDriving.yaw(speed, 1, 10, false),
			"low speed and reverse unchanged"
		)
	end
	assert(TownDriving.yaw(50, 0, 10, true) == 0, "no artificial spin")
end)
test("drift scoring requires sustained grounded slide, banks once and cancels damage", function()
	local s = DriftRules.new()
	for _ = 1, 30 do
		DriftRules.step(s, 0.1, 40, 0, true, 0, true)
	end
	assert(s.points == 0, "straight driving is not a drift")
	for _ = 1, 30 do
		DriftRules.step(s, 0.1, 40, 18, true, 0, true)
	end
	assert(s.points > 0, "sustained slide earns points")
	local bank = 0
	for _ = 1, 40 do
		local payout = DriftRules.step(s, 0.1, 40, 0, true, 0, true)
		bank += payout
	end
	assert(bank > 0 and bank <= 100 and s.points == 0, "bank once after release")
	for _ = 1, 30 do
		DriftRules.step(s, 0.1, 40, 18, true, 0, true)
	end
	DriftRules.step(s, 0.1, 40, 0, true, 10, true)
	assert(s.points == 0, "collision loses unbanked chain")
	for _ = 1, 30 do
		DriftRules.step(s, 0.1, 40, 18, false, 10, true)
	end
	assert(s.points == 0, "airborne motion earns nothing")
	DriftRules.step(s, 0.1, 40, 18, true, 10, false)
	assert(s.points == 0, "unoccupied car earns nothing")
end)
test("traffic uses separate right-hand lanes and continuous loop sampling", function()
	local center: { Nav.Point } =
		{ { x = 0, z = 0 }, { x = 200, z = 0 }, { x = 200, z = 200 }, { x = 0, z = 200 }, { x = 0, z = 0 } }
	local a, b = TownTrafficMath.route(center, false), TownTrafficMath.route(center, true)
	local aa = TownTrafficMath.sample(a, TownTrafficMath.project(a, { x = 100, z = 0 }))
	local bb = TownTrafficMath.sample(b, TownTrafficMath.project(b, { x = 100, z = 0 }))
	assert(aa.z > 0 and bb.z < 0 and Nav.distance(aa, bb) > 12, "opposite lanes")
	for _, r in { a, b } do
		for progress = 0, r.length - 1, 19 do
			local p = TownTrafficMath.sample(r, progress)
			assert(
				Nav.distance(p, TownTrafficMath.sample(r, TownTrafficMath.project(r, p))) < 0.001,
				"sample/project roundtrip"
			)
			assert(
				Nav.distance(p, TownTrafficMath.sample(r, progress + r.length)) < 0.001,
				"seam wraps continuously"
			)
		end
	end
	assert(TownTrafficMath.followSpeed(20) == 0 and TownTrafficMath.followSpeed(90) > 0, "queue spacing")
	assert(TownTrafficMath.stopSpeed(20) == 0 and TownTrafficMath.stopSpeed(60) > 0, "stop line")
end)

test("civilian controller completes both town lanes without stalling or large departures", function()
	local center: { Nav.Point } = {}
	for _, index in Roads.Route do
		local p = Roads.Nodes[index]
		table.insert(center, { x = p.x, z = p.z })
	end
	for _, reverse in { false, true } do
		local route = TownTrafficMath.route(center, reverse)
		local p = TownTrafficMath.sample(route, 0)
		local q = TownTrafficMath.sample(route, 8)
		local heading = math.atan2(q.x - p.x, -(q.z - p.z))
		local speed, steer, travel, maxGap = 0, 0, 0, 0
		local worst = ""
		for _ = 1, 18000 do
			local progress = TownTrafficMath.project(route, p)
			local aim = TownTrafficMath.sample(route, progress + TownTrafficMath.lookahead(speed))
			local dx, dz = aim.x - p.x, aim.z - p.z
			local throttle, want = Nav.controls(
				dx * math.cos(heading) + dz * math.sin(heading),
				dx * math.sin(heading) - dz * math.cos(heading),
				speed,
				10.4,
				TownTrafficMath.cornerSpeed(TownTrafficMath.path(route, progress))
			)
			steer = Driving.approach(steer, want, 7, 1 / 60)
			speed = math.max(
				0,
				speed
					+ (
							if throttle < 0
								then -29
								elseif throttle > 0 then 9 / (1 + (speed / 23.1) ^ 2)
								else -speed * 0.65
						)
						/ 60
			)
			heading -= TownDriving.yaw(speed, steer, 10.4) / 60
			p.x += math.sin(heading) * speed / 60
			p.z -= math.cos(heading) * speed / 60
			travel += speed / 60
			local gap = Nav.distance(p, TownTrafficMath.sample(route, progress))
			if gap > maxGap then
				worst = string.format(
					"progress %.1f / xy %.1f %.1f / speed %.1f / steer %.2f",
					progress,
					p.x,
					p.z,
					speed,
					steer
				)
				maxGap = gap
			end
			if travel > route.length + 50 then
				break
			end
		end
		assert(travel > route.length, "traffic must complete a loop")

		assert(maxGap < 10, "traffic must remain close to its lane: " .. worst)
	end
end)
test(
	"civilian controller completes both parkway lanes at a 10 Hz planning rate without stalling or large departures",
	function()
		local center: { Nav.Point } = {}
		for _, index in Roads.Course do
			local p = Roads.Nodes[index]
			table.insert(center, { x = p.x, z = p.z })
		end
		for _, reverse in { false, true } do
			local route = TownTrafficMath.route(center, reverse)
			local p = TownTrafficMath.sample(route, 0)
			local q = TownTrafficMath.sample(route, 8)
			local heading = math.atan2(q.x - p.x, -(q.z - p.z))
			local speed, steer, travel, maxGap = 0, 0, 0, 0
			local worst = ""
			local throttle, want = 0, 0
			for frame = 1, 24000 do
				local progress = TownTrafficMath.project(route, p)
				if frame % 6 == 1 then
					local aim = TownTrafficMath.sample(route, progress + TownTrafficMath.lookahead(speed))
					local dx, dz = aim.x - p.x, aim.z - p.z
					throttle, want = Nav.controls(
						dx * math.cos(heading) + dz * math.sin(heading),
						dx * math.sin(heading) - dz * math.cos(heading),
						speed,
						10.4,
						TownTrafficMath.cornerSpeed(TownTrafficMath.path(route, progress))
					)
				end
				steer = Driving.approach(steer, want, 7, 1 / 60)
				speed = math.max(
					0,
					speed
						+ (
								if throttle < 0
									then -29
									elseif throttle > 0 then 9 / (1 + (speed / 23.1) ^ 2)
									else -speed * 0.65
							)
							/ 60
				)
				heading -= TownDriving.yaw(speed, steer, 10.4) / 60
				p.x += math.sin(heading) * speed / 60
				p.z -= math.cos(heading) * speed / 60
				travel += speed / 60
				local gap = Nav.distance(p, TownTrafficMath.sample(route, progress))
				if gap > maxGap then
					worst = string.format(
						"progress %.1f / xy %.1f %.1f / speed %.1f / steer %.2f",
						progress,
						p.x,
						p.z,
						speed,
						steer
					)
					maxGap = gap
				end
				if travel > route.length + 50 then
					break
				end
			end
			assert(travel > route.length, "traffic must complete a loop")

			assert(maxGap < 10, "traffic must remain close to its lane: " .. worst)
		end
	end
)

local Lap = require("../src/shared/LapRules")
test("civilian controller completes both mill lanes at a 10 Hz planning rate", function()
	local center: { Nav.Point } = {}
	for _, index in Roads.ServiceRoute do
		local p = Roads.Nodes[index]
		table.insert(center, { x = p.x, z = p.z })
	end
	for _, reverse in { false, true } do
		local route = TownTrafficMath.route(center, reverse)
		local p = TownTrafficMath.sample(route, 0)
		local q = TownTrafficMath.sample(route, 8)
		local heading = math.atan2(q.x - p.x, -(q.z - p.z))
		local speed, steer, travel, maxGap = 0, 0, 0, 0
		local worst = ""
		local throttle, want = 0, 0
		for frame = 1, 24000 do
			local progress = TownTrafficMath.project(route, p)
			if frame % 6 == 1 then
				local aim = TownTrafficMath.sample(route, progress + TownTrafficMath.lookahead(speed))
				local dx, dz = aim.x - p.x, aim.z - p.z
				throttle, want = Nav.controls(
					dx * math.cos(heading) + dz * math.sin(heading),
					dx * math.sin(heading) - dz * math.cos(heading),
					speed,
					10.4,
					TownTrafficMath.cornerSpeed(TownTrafficMath.path(route, progress))
				)
			end
			steer = Driving.approach(steer, want, 7, 1 / 60)
			speed = math.max(
				0,
				speed
					+ (
							if throttle < 0
								then -29
								elseif throttle > 0 then 9 / (1 + (speed / 23.1) ^ 2)
								else -speed * 0.65
						)
						/ 60
			)
			heading -= TownDriving.yaw(speed, steer, 10.4) / 60
			p.x += math.sin(heading) * speed / 60
			p.z -= math.cos(heading) * speed / 60
			travel += speed / 60
			local gap = Nav.distance(p, TownTrafficMath.sample(route, progress))
			if gap > maxGap then
				worst = string.format(
					"progress %.1f / xy %.1f %.1f / speed %.1f / steer %.2f",
					progress,
					p.x,
					p.z,
					speed,
					steer
				)
				maxGap = gap
			end
			if travel > route.length + 50 then
				break
			end
		end
		assert(travel > route.length, "traffic must complete a loop")

		assert(maxGap < 10, "traffic must remain close to its lane: " .. worst)
	end
end)

test("lap rewards require a full continuous circuit in either direction", function()
	for _, direction in { 1, -1 } do
		local state = Lap.new()
		local count, elapsed = 0, 0
		for i = 0, 200 do
			local complete, seconds = Lap.step(state, (990 + direction * i * 10) % 1000, 1000, 0.1, true)
			if complete then
				count += 1
				elapsed = seconds
			end
		end
		assert(
			count == 2 and math.abs(elapsed - 10) < 0.001,
			"two full laps cross the route seam without duplicate rewards"
		)
	end
end)
test("lap rewards reject teleports, abandoned attempts and back-and-forth farming", function()
	local state = Lap.new()
	Lap.step(state, 0, 1000, 0.1, true)
	Lap.step(state, 400, 1000, 0.1, true)
	assert(state.travel == 0 and state.previous == nil, "teleport resets")
	for i = 0, 60 do
		Lap.step(state, i * 10, 1000, 0.1, true)
	end
	Lap.step(state, 600, 1000, 0.1, false)
	assert(state.travel == 0 and state.previous == nil, "leaving road or car resets progress")
	for _ = 1, 10 do
		for i = 0, 50 do
			assert(not Lap.step(state, i * 10, 1000, 0.1, true), "half lap cannot pay")
		end
		for i = 50, 0, -1 do
			assert(not Lap.step(state, i * 10, 1000, 0.1, true), "retracing cannot pay")
		end
	end
end)
test("rush hour headway queue clears after a stopped lead car moves", function()
	local positions, speeds = {}, {}
	for i = 1, 18 do
		positions[i] = (i - 1) * 32
		speeds[i] = 0
	end
	local minimumGap = math.huge
	for frame = 1, 1800 do
		local nextSpeeds = {}
		for i = 1, 18 do
			local gap = if i == 18 then math.huge else positions[i + 1] - positions[i]
			minimumGap = math.min(minimumGap, gap)
			local target = if i == 18 and frame < 100 then 0 else TownTrafficMath.followSpeed(gap)
			nextSpeeds[i] = math.max(0, speeds[i] + math.clamp(target - speeds[i], -29 * 0.1, 9 * 0.1))
		end
		for i = 1, 18 do
			speeds[i] = nextSpeeds[i]
			positions[i] += speeds[i] * 0.1
		end
	end
	assert(minimumGap >= 27.5, "braking must preserve space between bodies")
	for i = 1, 18 do
		assert(speeds[i] > 35, "every queued car must resume")
	end
end)

test("pursuit advances its cached path and can accelerate above patrol speed", function()
	local path: { Nav.Point } = { { x = 0, z = 0 }, { x = 0, z = -100 }, { x = 100, z = -100 } }
	local remaining = Nav.remaining(path, { x = 0, z = -80 })
	local target = Nav.ahead(remaining, 30)
	assert(
		target and target.x == 10 and target.z == -100,
		"lookahead advances around bend instead of aiming behind"
	)
	local throttle = Nav.controls(0, 60, 90, 10.4, 120)
	assert(throttle > 0, "pursuit cruise must not be silently limited to 78")
	assert(Nav.cornerSpeed(remaining, 120) < 120, "higher pursuit speed still brakes before town bends")
end)

local ProfileRules = require("../src/shared/ProfileRules")
local Variants = require("../src/shared/MissionVariants")
local Materials = require("../src/shared/VehicleMaterials")
local Tactics = require("../src/shared/PoliceTactics")
local Samples = require("../src/shared/PerformanceSamples")
test("profile locks reject concurrent joins and obsolete saves after takeover", function()
	local first = assert(
		ProfileRules.acquire(nil, "A", 100),
		"profile locks reject concurrent joins and obsolete saves after takeover"
	)
	assert(
		ProfileRules.acquire(first, "B", 110) == nil,
		"profile locks reject concurrent joins and obsolete saves after takeover"
	)
	local renew = assert(
		ProfileRules.acquire(first, "A", 120),
		"profile locks reject concurrent joins and obsolete saves after takeover"
	)
	assert(renew.expires == 300, "profile locks reject concurrent joins and obsolete saves after takeover")
	local second = assert(
		ProfileRules.acquire(renew, "B", 301),
		"profile locks reject concurrent joins and obsolete saves after takeover"
	)
	assert(
		ProfileRules.commit(second, "A", 302, first.data, false) == nil,
		"profile locks reject concurrent joins and obsolete saves after takeover"
	)
	local release = assert(
		ProfileRules.commit(second, "B", 303, second.data, true),
		"profile locks reject concurrent joins and obsolete saves after takeover"
	)
	assert(
		release.owner == "" and ProfileRules.acquire(release, "C", 304) ~= nil,
		"profile locks reject concurrent joins and obsolete saves after takeover"
	)
end)
test("invalid or future profiles never turn into empty replacement saves", function()
	local bad: any = ProfileRules.new()
	bad.version = 2
	assert(
		ProfileRules.decode(bad) == nil,
		"invalid or future profiles never turn into empty replacement saves"
	)
	assert(
		ProfileRules.acquire({ data = bad, owner = "", expires = 0, revision = 0 }, "A", 100) == nil,
		"invalid or future profiles never turn into empty replacement saves"
	)
	bad = ProfileRules.new()
	bad.cash = 0 / 0
	assert(
		ProfileRules.decode(bad) == nil,
		"invalid or future profiles never turn into empty replacement saves"
	)
	bad = ProfileRules.new()
	bad.upgrades.Sport = { Power = 4 }
	assert(
		ProfileRules.decode(bad) == nil,
		"invalid or future profiles never turn into empty replacement saves"
	)
	assert(
		ProfileRules.commit({ owner = "A" }, "A", 100, ProfileRules.new(), false) == nil,
		"invalid or future profiles never turn into empty replacement saves"
	)
end)
test("cash and garage changes persist atomically in the same record", function()
	local record = assert(
		ProfileRules.acquire(nil, "A", 100),
		"cash and garage changes persist atomically in the same record"
	)
	record.data.cash = 650
	record.data.selected = "Sport"
	record.data.upgrades.Sport = { Power = 1, Brakes = 2, Tyres = 0, Suspension = 0 }
	record.data.cosmetics.Paint_Slate = true
	record.data.equipped.Sport = { Paint = "Paint_Slate" }
	record.data.discoveries.Library = true
	local saved = assert(
		ProfileRules.commit(record, "A", 110, record.data, true),
		"cash and garage changes persist atomically in the same record"
	)
	local loaded = assert(
		ProfileRules.acquire(saved, "B", 120),
		"cash and garage changes persist atomically in the same record"
	)
	assert(
		loaded.data.cash == 650 and loaded.data.upgrades.Sport.Brakes == 2,
		"cash and garage changes persist atomically in the same record"
	)
	assert(
		loaded.data.cosmetics.Paint_Slate and loaded.data.equipped.Sport.Paint == "Paint_Slate",
		"cash and garage changes persist atomically in the same record"
	)
	assert(
		loaded.data.discoveries.Library and loaded.revision == 1,
		"cash and garage changes persist atomically in the same record"
	)
end)
test("fragile cargo degrades only on new impacts after pickup, never repairs into free value", function()
	local v = Variants.new("cargo", 0, 2)
	Variants.damage(v, 5)
	assert(
		v.quality == 100,
		"fragile cargo degrades only on new impacts after pickup, never repairs into free value"
	)
	Variants.pickup(v, true, 0)
	Variants.damage(v, 15)
	assert(
		v.quality == 80 and Variants.payout(v, 1000) == 800,
		"fragile cargo degrades only on new impacts after pickup, never repairs into free value"
	)
	Variants.damage(v, 15)
	assert(
		v.quality == 80,
		"fragile cargo degrades only on new impacts after pickup, never repairs into free value"
	)
	Variants.damage(v, 0)
	Variants.damage(v, 15)
	assert(
		v.quality == 80,
		"fragile cargo degrades only on new impacts after pickup, never repairs into free value"
	)
	Variants.damage(v, 100)
	assert(
		Variants.payout(v, 1000) == 0,
		"fragile cargo degrades only on new impacts after pickup, never repairs into free value"
	)
end)
test("heat decisions cannot be replayed and banking preserves the earned haul", function()
	local v = Variants.new("heat", 0, 1)
	assert(
		not Variants.choose(v, "continue"),
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
	Variants.pickup(v, true, 10)
	assert(
		v.choice and v.deadline == 22,
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
	assert(
		not Variants.choose(v, "cheat"),
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
	assert(
		Variants.choose(v, "continue") and v.heat == 2,
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
	assert(
		not Variants.choose(v, "continue") and v.heat == 2,
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
	Variants.pickup(v, true, 30)
	assert(
		Variants.choose(v, "bank"),
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
	assert(
		v.heat == 2 and not v.choice and Variants.base(v, 350) == 700,
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
	Variants.pickup(v, false, 50)
	assert(
		not v.choice and not Variants.choose(v, "continue"),
		"heat decisions cannot be replayed and banking preserves the earned haul"
	)
end)
test("paint classification preserves glass, tyres, trim and police lamps", function()
	for _, name in { "body", "front_bumper", "left_door", "trrunk", "hood" } do
		assert(
			Materials.slot(name) == "Paint",
			"paint classification preserves glass, tyres, trim and police lamps"
		)
	end
	for _, name in { "glass", "tire", "headlight", "grill", "window_trim", "PoliceRed" } do
		assert(
			Materials.slot(name) == nil,
			"paint classification preserves glass, tyres, trim and police lamps"
		)
	end
	assert(
		Materials.slot("front_wheel") == "Wheels" and Materials.slot("interior") == "Interior",
		"paint classification preserves glass, tyres, trim and police lamps"
	)
end)
test("interception uses bounded last-known velocity and stays on roads", function()
	local graph: Nav.Graph = { { x = 0, z = 0, links = { 2 } }, { x = 500, z = 0, links = { 1 } } }
	local follow = Tactics.target(graph, { x = 100, z = 0 }, { x = 100, z = 0 }, "follow")
	local lead = Tactics.target(graph, { x = 100, z = 0 }, { x = 100, z = 0 }, "intercept")
	assert(
		follow.x == 100 and lead.x == 280 and lead.z == 0,
		"interception uses bounded last-known velocity and stays on roads"
	)
	local search = Tactics.target(graph, { x = 100, z = 0 }, { x = 100, z = 0 }, "search")
	assert(search.x == follow.x, "interception uses bounded last-known velocity and stays on roads")
	assert(
		not Tactics.spawnSafe(120, false, false),
		"interception uses bounded last-known velocity and stays on roads"
	)
	assert(
		not Tactics.spawnSafe(300, true, false),
		"interception uses bounded last-known velocity and stays on roads"
	)
	assert(
		not Tactics.spawnSafe(300, false, true),
		"interception uses bounded last-known velocity and stays on roads"
	)
	assert(
		Tactics.spawnSafe(400, false, false),
		"interception uses bounded last-known velocity and stays on roads"
	)
end)
test("performance percentiles preserve samples and expose slow frames", function()
	local data = { 16, 16, 16, 40, 16, 16, 16, 16, 16, 16 }
	assert(
		Samples.percentile(data, 0.5) == 16 and Samples.percentile(data, 0.95) == 40,
		"performance percentiles preserve samples and expose slow frames"
	)
	assert(
		data[4] == 40 and Samples.percentile({}, 0.95) == 0,
		"performance percentiles preserve samples and expose slow frames"
	)
end)

test("only terminal runs permit retry recovery", function()
	local job = GetawayRules.new(1, 240, 1)
	for _, phase in { "idle", "pickup", "run", "escape", "deliver" } do
		job.phase = phase
		assert(not GetawayRules.recoverable(job), "active/unknown runs cannot use terminal teleport")
	end
	for _, phase in { "busted", "failed", "complete" } do
		job.phase = phase
		assert(GetawayRules.recoverable(job), "bust, wreck/timeout and completion all offer recovery")
	end
end)
test("busted runs can start fresh without repeating a reward or bust", function()
	local old = GetawayRules.new(1, 240, 1)
	local s = sample()
	s.atCheckpoint = true
	GetawayRules.step(old, 0.1, s)
	s.nearCop, s.slow = true, true
	for _ = 1, 20 do
		GetawayRules.step(old, 0.25, s)
	end
	assert(old.phase == "busted" and GetawayRules.recoverable(old), "caught player can recover")
	local fresh = GetawayRules.new(1, 240, 1)
	assert(
		fresh.busted == 0 and fresh.escape == 0 and fresh.remaining == 240,
		"fresh attempt clears previous pursuit counters"
	)
	assert(not GetawayRules.recoverable(fresh), "duplicate retry cannot teleport an active attempt")
	assert(GetawayRules.step(old, 0.25, s) == nil, "finished run cannot award again")
	assert(
		GetawayRules.step(fresh, 0.1, sample()) == nil and fresh.phase == "pickup",
		"new attempt waits for pickup"
	)
end)
test("road headlights provide several seconds of preview at driving speeds", function()
	local roadTune = { RoadMinRange = 120, RoadMaxRange = 1400, PreviewSeconds = 3 }
	local previous = 0
	for _, kmh in { 0, 50, 100, 180, 240, 300, 400 } do
		local speed = Units.fromKmh(kmh)
		local reach = HeadlightMath.roadReach(speed, roadTune)
		assert(
			reach >= previous and reach <= roadTune.RoadMaxRange,
			"range grows without exceeding effect budget"
		)
		if speed > 0 then
			assert(reach / speed >= 3, "clear straight road has at least three seconds preview")
		end
		previous = reach
	end
	assert(
		HeadlightMath.roadReach(-200, roadTune) == HeadlightMath.roadReach(200, roadTune),
		"reverse velocity remains bounded"
	)
	assert(
		HeadlightMath.roadReach(10000, roadTune) == 1400,
		"abnormal speed cannot allocate unlimited projection"
	)
end)
test("a close obstacle clips the road light without blanking its near field", function()
	for _, reach in { 3, 12, 120, 1400 } do
		local previous = 0
		for i = 1, 16 do
			local d = HeadlightMath.sampleDistance(reach, i, 16)
			assert(d > previous and d <= reach, "samples cover the clipped distance in order")
			previous = d
		end
		assert(previous == reach, "last segment reaches the obstruction")
	end
	assert(HeadlightMath.sampleDistance(1400, 1, 16) < 6, "long beam preserves useful bumper detail")
	assert(HeadlightMath.sampleDistance(0, 1, 16) == 0, "blocked origin has zero reach")
end)
local CockpitFit = require("../src/shared/CockpitFit")
test("bundled car eyes sit inside their windshield instead of below the dashboard", function()
	-- Measured chassis-local bounds from the bundled assets (Y, height, fitted seat Y).
	for _, bounds in
		{
			{ 2.0278473, 1.3162537, -0.686035 },
			{ 1.4739075, 1.0087891, -1.044083 },
			{ 3.608673, 1.3331909, 1.254776 },
		}
	do
		local y, minimum, maximum = CockpitFit.height(bounds[3], bounds[1], bounds[2])
		assert(y > minimum and y < maximum, "eye has clearance above dash and below roof")
		assert(y > bounds[3] + 1.8, "does not reuse the too-low generic offset")
		assert(
			CockpitFit.adjust(y, -100, minimum, maximum) == minimum,
			"low setting cannot move below windshield"
		)
		assert(CockpitFit.adjust(y, 100, minimum, maximum) == maximum, "high setting cannot move into roof")
	end
end)
test("prototype cockpit remains usable without imported glass", function()
	local y, minimum, maximum = CockpitFit.height(0.2, nil, nil)
	assert(y == 2 and minimum < y and maximum > y, "procedural car gets bounded fallback view")
end)
print(string.format("%d logic tests passed (no Roblox physics/services simulated)", passed))
