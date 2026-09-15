--!strict
local RunService = game:GetService("RunService")
if not RunService:IsStudio() then
	return
end
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")
local HttpService = game:GetService("HttpService")
local Samples = require(game:GetService("ReplicatedStorage").Shared.PerformanceSamples)
local UI = require(script.Parent.Interface)
local player = Players.LocalPlayer
local values: { number } = {}
local started = 0
local function report()
	if #values == 0 then
		return
	end
	local data = {
		seconds = math.floor(os.clock() - started),
		samples = #values,
		p50ms = Samples.percentile(values, 0.5),
		p95ms = Samples.percentile(values, 0.95),
		p99ms = Samples.percentile(values, 0.99),
		memoryMB = Stats:GetTotalMemoryUsageMb(),
		traffic = workspace:GetAttribute("TownTrafficCount"),
		night = player:GetAttribute("NightPreference"),
		touch = game:GetService("UserInputService").TouchEnabled,
		players = #Players:GetPlayers(),
	}
	print("[REDLINE PERFORMANCE] " .. HttpService:JSONEncode(data))
	UI.notify(string.format("Captured %d frames · p95 %.1f ms. Details in Output.", #values, data.p95ms))
	table.clear(values)
end
player:GetAttributeChangedSignal("Profile"):Connect(function()
	if player:GetAttribute("Profile") then
		table.clear(values)
		started = os.clock()
		UI.notify("Frame capture started. Toggle again to print the report.")
	else
		report()
	end
end)
RunService.RenderStepped:Connect(function(dt: number)
	if player:GetAttribute("Profile") then
		table.insert(values, dt * 1000)
		if #values >= 72000 then
			player:SetAttribute("Profile", false)
		end
	end
end)
