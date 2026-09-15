--!strict
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
print(string.format("%d logic tests passed (no Roblox physics/services simulated)", passed))
