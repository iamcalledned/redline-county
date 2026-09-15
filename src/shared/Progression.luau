--!strict
local Progression = {}
export type Levels = { Power: number, Brakes: number, Tyres: number, Suspension: number }
Progression.Catalog = {
	{
		Id = "Power",
		Name = "Powertrain",
		Prices = { 500, 1100, 2200 },
		Effect = "Each level: +12% acceleration, +5% top speed",
	},
	{
		Id = "Brakes",
		Name = "Brakes",
		Prices = { 350, 800, 1600 },
		Effect = "Each level: +18% braking force",
	},
	{
		Id = "Tyres",
		Name = "Performance tyres",
		Prices = { 450, 950, 1900 },
		Effect = "Each level: +12% corner grip, +8% sliding grip",
	},
	{
		Id = "Suspension",
		Name = "Suspension",
		Prices = { 400, 900, 1800 },
		Effect = "Each level: +8% spring rate, +16% damping",
	},
}
Progression.Difficulties = {
	{ Id = "light", Name = "Light", Traffic = 6, Multiplier = 1 },
	{ Id = "busy", Name = "Busy", Traffic = 12, Multiplier = 1.5 },
	{ Id = "rush", Name = "Rush hour", Traffic = 18, Multiplier = 2.2 },
}
function Progression.levels(): Levels
	return { Power = 0, Brakes = 0, Tyres = 0, Suspension = 0 }
end
function Progression.difficulty(id: any): typeof(Progression.Difficulties[1])?
	for _, d in Progression.Difficulties do
		if d.Id == id then
			return d
		end
	end
	return nil
end
function Progression.price(levels: Levels, id: string): number?
	for _, upgrade in Progression.Catalog do
		if upgrade.Id == id then
			return upgrade.Prices[(levels :: any)[id] + 1]
		end
	end
	return nil
end
function Progression.buy(
	cash: number,
	levels: Levels,
	id: string,
	atWorkshop: boolean,
	onJob: boolean
): (number, string)
	if not atWorkshop or onJob then
		return cash, "Stop at home after your job to fit upgrades."
	end
	local price = Progression.price(levels, id)
	if not price then
		return cash, "Upgrade unavailable or already at level 3."
	end
	if cash < price then
		return cash, "Need $" .. (price - cash) .. " more."
	end
	(levels :: any)[id] += 1
	return cash - price, "Installed " .. id .. " level " .. (levels :: any)[id] .. "."
end
function Progression.factors(levels: Levels)
	return {
		Acceleration = 1 + 0.12 * levels.Power,
		TopSpeed = 1 + 0.05 * levels.Power,
		Brake = 1 + 0.18 * levels.Brakes,
		Grip = 1 + 0.12 * levels.Tyres,
		DriftGrip = 1 + 0.08 * levels.Tyres,
		Spring = 1 + 0.08 * levels.Suspension,
		Damping = 1 + 0.16 * levels.Suspension,
	}
end
function Progression.payout(base: number, seconds: number, difficulty: string, damage: number): number
	local d = Progression.difficulty(difficulty)
	if not d then
		return 0
	end
	return math.floor(
		(base + math.max(0, math.floor(seconds)) * 2) * d.Multiplier * (if damage == 0 then 1.2 else 1)
	)
end
function Progression.spring(
	rest: number,
	distance: number,
	verticalSpeed: number,
	gravity: number,
	rate: number,
	damping: number,
	dt: number?
): number
	local step = math.clamp(dt or 0, 0, 0.1)
	-- Implicit spring/damper response keeps four supports stable at low update rates.
	local response = ((rest - distance) * rate - verticalSpeed * damping)
		/ (1 + 4 * damping * step + 4 * rate * step * step)
	return math.clamp(gravity / 4 + response, 0, gravity)
end
return Progression
