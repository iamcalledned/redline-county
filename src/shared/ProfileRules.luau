--!strict
-- Serializable player data and lease rules, also exercised without Roblox services.
local Rules = {}
export type Profile = {
	version: number,
	cash: number,
	wins: number,
	selected: string,
	upgrades: { [string]: { [string]: number } },
	discoveries: { [string]: boolean },
	cosmetics: { [string]: boolean },
	equipped: { [string]: { [string]: string } },
	laps: number,
	bestLap: number,
}
export type Record = { data: Profile, owner: string, expires: number, revision: number }
local kinds =
	{ Sport = true, Pickup = true, Electric = true, Compact = true, Coupe = true, Interceptor = true }
function Rules.new(): Profile
	return {
		version = 1,
		cash = 0,
		wins = 0,
		selected = "Electric",
		upgrades = {},
		discoveries = {},
		cosmetics = {},
		equipped = {},
		laps = 0,
		bestLap = 0,
	}
end
local function number(value: any, maximum: number): boolean
	return type(value) == "number" and value == value and value >= 0 and value <= maximum
end
function Rules.decode(value: any): Profile?
	if
		type(value) ~= "table"
		or value.version ~= 1
		or not number(value.cash, 100000000)
		or not number(value.wins, 1000000)
		or not kinds[value.selected]
	then
		return nil
	end
	if
		type(value.upgrades) ~= "table"
		or type(value.discoveries) ~= "table"
		or type(value.cosmetics) ~= "table"
		or type(value.equipped) ~= "table"
	then
		return nil
	end
	for kind, levels in value.upgrades do
		if not kinds[kind] or type(levels) ~= "table" then
			return nil
		end
		for key, level in levels do
			if
				not table.find({ "Power", "Brakes", "Tyres", "Suspension" }, key)
				or not number(level, 3)
				or level % 1 ~= 0
			then
				return nil
			end
		end
	end
	for key, flag in value.discoveries do
		if type(key) ~= "string" or type(flag) ~= "boolean" then
			return nil
		end
	end
	for key, flag in value.cosmetics do
		if type(key) ~= "string" or type(flag) ~= "boolean" then
			return nil
		end
	end
	for kind, items in value.equipped do
		if not kinds[kind] or type(items) ~= "table" then
			return nil
		end
		for key, item in items do
			if
				not table.find({ "Paint", "Wheels", "Interior" }, key)
				or type(item) ~= "string"
				or #item > 40
			then
				return nil
			end
		end
	end
	if not number(value.laps, 1000000) or not number(value.bestLap, 86400) then
		return nil
	end
	return value :: Profile
end
function Rules.acquire(old: any, token: string, now: number): Record?
	if old == nil then
		return { data = Rules.new(), owner = token, expires = now + 180, revision = 0 }
	end
	if
		type(old) ~= "table"
		or not Rules.decode(old.data)
		or type(old.owner) ~= "string"
		or not number(old.expires, 1e12)
		or not number(old.revision, 1e12)
	then
		return nil
	end
	if old.owner ~= "" and old.owner ~= token and old.expires > now then
		return nil
	end
	return { data = old.data, owner = token, expires = now + 180, revision = old.revision }
end
function Rules.commit(old: any, token: string, now: number, data: Profile, release: boolean): Record?
	if
		type(old) ~= "table"
		or old.owner ~= token
		or not number(old.revision, 1e12)
		or not Rules.decode(data)
	then
		return nil
	end
	return {
		data = data,
		owner = if release then "" else token,
		expires = if release then 0 else now + 180,
		revision = old.revision + 1,
	}
end
return Rules
