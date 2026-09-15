--!strict
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Rules = require(game:GetService("ReplicatedStorage").Shared.ProfileRules)
local Store = {}
type Session = {
	data: Rules.Profile,
	token: string,
	persistent: boolean,
	busy: boolean,
	closing: boolean,
	lease: number,
}
local sessions: { [Player]: Session } = {}
local backend: GlobalDataStore? = nil
if game.GameId > 0 then
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(
			if RunService:IsStudio() then "RedlineProfiles_Studio_v1" else "RedlineProfiles_v1"
		)
	end)
	if ok then
		backend = result
	end
end
local function copy(data: Rules.Profile): Rules.Profile
	return HttpService:JSONDecode(HttpService:JSONEncode(data)) :: Rules.Profile
end
function Store.get(player: Player): Rules.Profile?
	local session = sessions[player]
	if not session or session.closing then
		return nil
	end
	if session.persistent and os.time() >= session.lease then
		session.closing = true
		player:Kick("Your save connection expired. Rejoin to safely reload your garage.")
		return nil
	end
	return session.data
end
function Store.load(player: Player): boolean
	player:SetAttribute("SaveStatus", "Loading garage")
	local token = HttpService:GenerateGUID(false)
	local data: Rules.Profile? = nil
	local persistent = false
	if backend then
		for attempt = 1, 3 do
			local ok, result = pcall(function()
				return (backend :: GlobalDataStore):UpdateAsync("User_" .. player.UserId, function(old)
					return Rules.acquire(old, token, os.time())
				end)
			end)
			if ok and result and result.owner == token then
				data = result.data
				persistent = true
				break
			end
			if ok then
				break
			end -- locked/invalid profiles must never become a new empty save
			if attempt < 3 then
				task.wait(attempt + math.random())
			end
		end
	end
	if not data then
		if game.GameId > 0 then
			player:SetAttribute("SaveStatus", "Garage unavailable")
			player:Kick(
				"Your garage could not be safely loaded. Please retry. In Studio, enable API access for a published test experience."
			)
			return false
		end
		data = Rules.new() -- unpublished local files have no Roblox data store; never claim persistence
	end
	sessions[player] = {
		data = data :: Rules.Profile,
		token = token,
		persistent = persistent,
		busy = false,
		closing = false,
		lease = os.time() + 180,
	}
	player:SetAttribute(
		"SaveStatus",
		if persistent then "Saved garage" else "Local practice · saves unavailable"
	)
	if not player.Parent then
		task.defer(Store.save, player, true)
		return false
	end
	player:SetAttribute("ProfileReady", true)
	return true
end
function Store.save(player: Player, release: boolean?): boolean
	local s = sessions[player]
	if not s then
		return false
	end
	if release then
		s.closing = true
	end
	while s.busy do
		task.wait(0.05)
	end
	if not s.persistent then
		if release then
			sessions[player] = nil
		end
		return true
	end
	s.busy = true
	local snapshot = copy(s.data)
	local success = false
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return (backend :: GlobalDataStore):UpdateAsync("User_" .. player.UserId, function(old)
				return Rules.commit(old, s.token, os.time(), snapshot, release == true)
			end)
		end)
		if ok and result and (result.owner == s.token or release and result.owner == "") then
			success = true
			s.lease = os.time() + 180
			break
		end
		if ok then
			break
		end
		if attempt < 3 then
			task.wait(attempt + math.random())
		end
	end
	s.busy = false
	player:SetAttribute(
		"SaveStatus",
		if success then "Garage saved" else "Save pending · reconnect only after saved"
	)
	if release then
		sessions[player] = nil
	end
	return success
end
function Store.changed(player: Player)
	local s = sessions[player]
	if not s or s.closing then
		return
	end
	if s.persistent then
		player:SetAttribute("SaveStatus", "Saving garage")
	end
	-- Coalesce purchase/reward saves while serializing all writes to this profile.
	if player:GetAttribute("SaveQueued") then
		return
	end
	player:SetAttribute("SaveQueued", true)
	task.delay(2, function()
		player:SetAttribute("SaveQueued", false)
		if sessions[player] and not sessions[player].closing then
			Store.save(player)
		end
	end)
end
Players.PlayerRemoving:Connect(function(player)
	Store.save(player, true)
end)
task.spawn(function()
	while true do
		task.wait(40 + math.random() * 5)
		for player, s in sessions do
			if not s.closing then
				task.spawn(Store.save, player)
			end
		end
	end
end)
game:BindToClose(function()
	for player in sessions do
		task.spawn(Store.save, player, true)
	end
	local deadline = os.clock() + 25
	while next(sessions) and os.clock() < deadline do
		task.wait(0.1)
	end
end)
return Store
