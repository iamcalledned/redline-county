--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Progression = require(Shared.Progression)
local Config = require(Shared.Config)
local Vehicle = require(script.Parent.Vehicle)
local Metrics = require(script.Parent.PlaytestMetrics)
local Workshop = {}
local Store = require(script.Parent.ProfileStore)
local Finish = require(script.Parent.VehicleFinish)
local Cosmetics = require(Shared.Cosmetics)
function Workshop.init(player: Player): boolean
	if not Store.load(player) then
		return false
	end
	local p = Store.get(player)
	if not p then
		return false
	end
	player:SetAttribute("GetawayCash", p.cash)
	Metrics.mark(player, "join", nil, true)
	if p.wins > 0 then
		Metrics.mark(player, "returning", nil, true)
	end
	player:SetAttribute("GetawayWins", p.wins)
	player:SetAttribute("SelectedCar", p.selected)
	player:SetAttribute("CircuitLaps", p.laps)
	if p.bestLap > 0 then
		player:SetAttribute("BestLapSeconds", p.bestLap)
	end
	for id, owned in p.cosmetics do
		player:SetAttribute("Owned_" .. id, owned)
	end
	return true
end
function Workshop.remove(_player: Player) end -- ProfileStore owns serialized leave/shutdown saves.
function Workshop.win(player: Player)
	local p = Store.get(player)
	if p then
		p.wins += 1
		player:SetAttribute("GetawayWins", p.wins)
		Store.changed(player)
	end
end
function Workshop.lap(player: Player, seconds: number)
	local p = Store.get(player)
	if p then
		p.laps += 1
		p.bestLap = if p.bestLap == 0 then seconds else math.min(p.bestLap, seconds)
		player:SetAttribute("CircuitLaps", p.laps)
		player:SetAttribute("BestLapSeconds", p.bestLap)
		Store.changed(player)
	end
end
function Workshop.credit(player: Player, amount: number)
	local p = Store.get(player)
	if p and amount > 0 and amount == amount and amount < 100000 then
		p.cash = math.min(100000000, p.cash + math.floor(amount))
		player:SetAttribute("GetawayCash", p.cash)
		Store.changed(player)
	end
end
function Workshop.discover(player: Player, id: string): boolean
	local p = Store.get(player)
	if not p or p.discoveries[id] then
		return false
	end
	p.discoveries[id] = true
	Workshop.credit(player, 150)
	return true
end
function Workshop.apply(player: Player, car: Vehicle.Car)
	local p = Store.get(player)
	if not p then
		return
	end
	local kind = car.Model:GetAttribute("Kind") :: string
	local levels = (p.upgrades[kind] or Progression.levels()) :: Progression.Levels
	local factors = Progression.factors(levels)
	local base = (Config.Cars :: any)[kind]
	car.Tune = table.clone(base)
	car.Tune.Acceleration = base.Acceleration * factors.Acceleration
	car.Tune.TopSpeed = base.TopSpeed * factors.TopSpeed
	car.Tune.Brake = base.Brake * factors.Brake
	car.Tune.Grip = base.Grip * factors.Grip
	car.Tune.DriftGrip = base.DriftGrip * factors.DriftGrip
	car.Suspension = table.clone(Config.Suspension)
	car.Suspension.Spring *= factors.Spring
	car.Suspension.Damping *= factors.Damping
	for _, u in Progression.Catalog do
		local level = (levels :: any)[u.Id]
		player:SetAttribute("Upgrade_" .. kind .. "_" .. u.Id, level)
		car.Model:SetAttribute("Upgrade_" .. u.Id, level)
	end
	if p.selected ~= kind then
		Store.changed(player)
	end
	p.selected = kind
	player:SetAttribute("SelectedCar", kind)
	for _, item in Cosmetics do
		if p.equipped[kind] and p.equipped[kind][item.Slot] == item.Id then
			Finish.apply(car.Model, item.Slot, Color3.fromRGB(item.RGB[1], item.RGB[2], item.RGB[3]))
		end
	end
	player:SetAttribute("WorkshopCar", kind)
	car.Model:SetAttribute("TunedTopSpeed", car.Tune.TopSpeed)
	car.Model:SetAttribute("TunedBrake", car.Tune.Brake)
	car.Model:SetAttribute("TunedGrip", car.Tune.Grip)
end
function Workshop.buy(player: Player, car: Vehicle.Car, id: string, atHome: boolean, onJob: boolean): string
	local p = Store.get(player)
	if not p then
		return "Profile unavailable."
	end
	local kind = car.Model:GetAttribute("Kind") :: string
	if car.Model:GetAttribute("OwnerId") ~= player.UserId then
		return "Choose your own car."
	end
	local levels = (p.upgrades[kind] or Progression.levels()) :: Progression.Levels
	local newCash, message = Progression.buy(p.cash, levels, id, atHome, onJob)
	if newCash < p.cash then
		Metrics.mark(player, "purchase", { id = id, kind = kind, amount = p.cash - newCash })
		p.cash = newCash
		p.upgrades[kind] = levels :: any
		player:SetAttribute("GetawayCash", p.cash)
		Workshop.apply(player, car)
		Store.changed(player)
	end
	return message
end
function Workshop.cosmetic(
	player: Player,
	car: Vehicle.Car,
	id: string,
	atHome: boolean,
	onJob: boolean
): string
	local p = Store.get(player)
	if not p or not atHome or onJob or car.Model:GetAttribute("OwnerId") ~= player.UserId then
		return "Park your car at home after the job."
	end
	for _, item in Cosmetics do
		if item.Id ~= id then
			continue
		end
		if not p.cosmetics[id] and p.cash < item.Price then
			return "Need $" .. (item.Price - p.cash) .. " more."
		end
		if not p.cosmetics[id] then
			Metrics.mark(player, "cosmetic", { id = id, amount = item.Price })
			p.cash -= item.Price
			p.cosmetics[id] = true
		end
		local kind = car.Model:GetAttribute("Kind") :: string
		p.equipped[kind] = p.equipped[kind] or {}
		p.equipped[kind][item.Slot] = id
		Finish.apply(car.Model, item.Slot, Color3.fromRGB(item.RGB[1], item.RGB[2], item.RGB[3]))
		player:SetAttribute("GetawayCash", p.cash)
		player:SetAttribute("Owned_" .. id, true)
		Store.changed(player)
		return "Fitted " .. item.Name .. "."
	end
	return "Unknown finish."
end
return Workshop
