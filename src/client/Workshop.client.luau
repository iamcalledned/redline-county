--!strict
local Shared = game:GetService("ReplicatedStorage").Shared
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UI = require(script.Parent.Interface)
local Progression = require(Shared.Progression)
local Cosmetics = require(Shared.Cosmetics)
local player = Players.LocalPlayer
local request = Shared.Parent:WaitForChild("Remotes"):WaitForChild("VehicleRequest") :: RemoteEvent
local content = UI.modal("workshop", "YOUR WORKSHOP")
local balance = UI.label(UI.row(content, 58), "", UDim2.fromScale(1, 1), UDim2.new(), 16)
local feedback = UI.label(
	UI.row(content, 48),
	"Park at home to fit parts. Your three starter cars are free.",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	13
)
local rows: { { label: TextLabel, button: TextButton, id: string, prices: { number }, name: string } } = {}
for _, upgrade in Progression.Catalog do
	local row = UI.row(content, 90)
	local label = UI.label(row, upgrade.Name, UDim2.new(1, -110, 0, 28), UDim2.new(), 16)
	UI.label(row, upgrade.Effect, UDim2.new(1, -110, 0, 56), UDim2.fromOffset(0, 29), 13)
	local button = UI.button(row, "BUY", UDim2.fromOffset(98, 46), UDim2.new(1, -98, 0, 18), function()
		request:FireServer("Upgrade", upgrade.Id)
	end)
	table.insert(
		rows,
		{ label = label, button = button, id = upgrade.Id, prices = upgrade.Prices, name = upgrade.Name }
	)
end
UI.label(UI.row(content, 38), "PAINT · WHEELS · INTERIOR", UDim2.fromScale(1, 1), UDim2.new(), 17).TextColor3 =
	UI.Gold
local finishes: { { button: TextButton, id: string, price: number } } = {}
for _, item in Cosmetics do
	local row = UI.row(content, 64)
	local swatch = UI.frame(row, UDim2.fromOffset(24, 24), UDim2.fromOffset(0, 16))
	swatch.BackgroundColor3 = Color3.fromRGB(item.RGB[1], item.RGB[2], item.RGB[3])
	swatch.BackgroundTransparency = 0
	UI.label(row, item.Name, UDim2.new(1, -152, 1, 0), UDim2.fromOffset(34, 0), 14)
	local b = UI.button(
		row,
		"$" .. item.Price,
		UDim2.fromOffset(108, 44),
		UDim2.new(1, -108, 0, 10),
		function()
			request:FireServer("Cosmetic", item.Id)
		end
	)
	table.insert(finishes, { button = b, id = item.Id, price = item.Price })
end
local cars = UI.modal("cars", "YOUR GARAGE")
for _, entry in
	{
		{ "Electric", "Everyday sedan", "Predictable grip · 180 km/h · electric" },
		{ "Sport", "Sport coupe", "Agile handling · 210 km/h · turbo available" },
		{ "Pickup", "Utility pickup", "Long wheelbase · stable platform · 150 km/h" },
	}
do
	local kind = entry[1]
	local row = UI.row(cars, 108)
	UI.label(row, entry[2], UDim2.new(1, -110, 0, 32), UDim2.new(), 18)
	UI.label(row, entry[3], UDim2.new(1, -110, 0, 64), UDim2.fromOffset(0, 34), 13)
	UI.button(row, "SELECT", UDim2.fromOffset(102, 46), UDim2.new(1, -102, 0, 24), function()
		request:FireServer("Spawn", kind)
	end)
end
UI.label(
	UI.row(cars, 60),
	"Select at home, open your bay door, then press E beside the car. Starting a job seats you automatically.",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	14
)
local notice = Shared.Parent.Remotes:WaitForChild("Notice") :: RemoteEvent
notice.OnClientEvent:Connect(function(text: string)
	feedback.Text = text
end)
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < 0.2 or UI.Name ~= "workshop" then
		return
	end
	clock = 0
	local kind = (player:GetAttribute("WorkshopCar") :: string?) or "Select a car"
	local cash = (player:GetAttribute("GetawayCash") :: number?) or 0
	balance.Text = kind .. " · $" .. cash .. "\n" .. tostring(player:GetAttribute("SaveStatus") or "Loading")
	for _, row in rows do
		local level = (player:GetAttribute("Upgrade_" .. kind .. "_" .. row.id) :: number?) or 0
		local price = row.prices[level + 1]
		row.label.Text = row.name .. " · " .. level .. "/3"
		row.button.Text = if price then "$" .. price else "FITTED"
		row.button.BackgroundColor3 = if price and cash >= price
			then UI.Accent
			else Color3.fromRGB(132, 144, 146)
	end
	for _, item in finishes do
		item.button.Text = if player:GetAttribute("Owned_" .. item.id) then "FIT OWNED" else "$" .. item.price
	end
end)
