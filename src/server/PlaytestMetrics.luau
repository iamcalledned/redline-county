--!strict
-- Aggregate session counters and anonymous run records in Studio Output only.
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local Metrics = {}
local starts: { [Player]: number } = {}
local once: { [Player]: { [string]: boolean } } = {}
function Metrics.mark(player: Player, event: string, details: { [string]: any }?, unique: boolean?)
	if not RunService:IsStudio() then
		return
	end
	starts[player] = starts[player] or os.clock()
	once[player] = once[player] or {}
	if unique and once[player][event] then
		return
	end
	once[player][event] = true
	local key = "Funnel_" .. event
	workspace:SetAttribute(key, ((workspace:GetAttribute(key) :: number?) or 0) + 1)
	print("[REDLINE PLAYTEST] " .. HttpService:JSONEncode({
		event = event,
		seconds = math.floor(os.clock() - starts[player]),
		details = details or {},
	}))
end
function Metrics.remove(player: Player)
	starts[player] = nil
	once[player] = nil
end
return Metrics
