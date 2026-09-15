--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Map = require(Shared.TownMap)
local Math = require(Shared.TownTrafficMath)
local Nav = require(Shared.RoadNavigation)
local Rules = require(Shared.LapRules)
local Workshop = require(script.Parent.Workshop)
local Vehicle = require(script.Parent.Vehicle)
local Circuit = {}
local route: Math.Route = { points = {}, lengths = { 0 }, length = 0 }
for _, p in Map.Course do
	table.insert(route.points, { x = p.X, z = p.Z })
end
for i = 2, #route.points do
	route.length += Nav.distance(route.points[i - 1], route.points[i])
	table.insert(route.lengths, route.length)
end
local states: { [Player]: Rules.State } = {}
function Circuit.remove(player: Player)
	states[player] = nil
end
function Circuit.step(player: Player, car: Vehicle.Car?, dt: number, occupied: boolean): string?
	local s = states[player] or Rules.new()
	states[player] = s
	local p = if car then { x = car.Body.Position.X, z = car.Body.Position.Z } else { x = 0, z = 0 }
	local along = Math.project(route, p)
	local valid = car ~= nil
		and occupied
		and not car.Model:GetAttribute("Highway")
		and ((car.Model:GetAttribute("GroundedWheels") :: number?) or 0) >= 2
		and ((car.Model:GetAttribute("Damage") :: number?) or 0) < 100
		and Nav.distance(p, Math.sample(route, along)) < 24
	local complete, seconds = Rules.step(s, along, route.length, dt, valid)
	if not car or car.TelemetryClock == 0 then
		player:SetAttribute("LapProgress", if valid then math.floor(s.travel / route.length * 100) else nil)
	end
	if complete then
		local reward = 100 + math.max(0, 150 - math.floor(seconds / 2))
		Workshop.credit(player, reward)
		Workshop.lap(player, seconds)
		return string.format(
			"LAP COMPLETE · %.1f s · +$%d · Keep driving for another lap",
			seconds,
			reward
		)
	end
	return nil
end
return Circuit
