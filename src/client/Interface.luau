--!strict
-- One owner for HUD layout, modals and local accessibility settings.
local Players = game:GetService("Players")
local Input = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local UI = {
	Name = "",
	Ink = Color3.fromRGB(17, 27, 35),
	Text = Color3.fromRGB(235, 237, 228),
	Accent = Color3.fromRGB(118, 215, 182),
	Gold = Color3.fromRGB(235, 189, 112),
}
local gui = Instance.new("ScreenGui")
gui.Name = "RedlineInterface"
gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.DisplayOrder = 5
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")
UI.Gui = gui
function UI.frame(parent: Instance, size: UDim2, pos: UDim2): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.BackgroundColor3 = UI.Ink
	f.BackgroundTransparency = 0.06
	f.BorderSizePixel = 0
	f.Parent = parent
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 9)
	c.Parent = f
	return f
end
function UI.label(parent: Instance, text: string, size: UDim2, pos: UDim2, fontSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Size = size
	l.Position = pos
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextSize = fontSize
	l.TextWrapped = true
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Font = Enum.Font.GothamMedium
	l.TextColor3 = UI.Text
	l.Parent = parent
	return l
end
function UI.button(parent: Instance, text: string, size: UDim2, pos: UDim2, callback: () -> ()): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
	b.Text = text
	b.TextSize = 15
	b.TextWrapped = true
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = UI.Ink
	b.BackgroundColor3 = UI.Accent
	b.BorderSizePixel = 0
	b.AutoButtonColor = true
	b.Parent = parent
	b.Activated:Connect(callback)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 7)
	c.Parent = b
	return b
end
local modals: { [string]: Frame } = {}
local shade = UI.frame(gui, UDim2.fromScale(1, 1), UDim2.new())
shade.BackgroundTransparency = 0.2
shade.Visible = false
shade.ZIndex = 10
UI.Changed = Instance.new("BindableEvent")
function UI.open(name: string)
	UI.Name = name
	player:SetAttribute("UIOpen", name ~= "")
	shade.Visible = name ~= ""
	for key, panel in modals do
		panel.Visible = key == name
	end
	GuiService.SelectedObject = nil
	if Input.GamepadEnabled and modals[name] then
		local content = modals[name]:FindFirstChild("Content")
		if content then
			for _, item in content:GetDescendants() do
				if item:IsA("TextButton") then
					GuiService.SelectedObject = item
					break
				end
			end
		end
	end
	UI.Changed:Fire(name)
end
function UI.toggle(name: string)
	UI.open(if UI.Name == name then "" else name)
end
function UI.modal(name: string, title: string): ScrollingFrame
	local panel = UI.frame(shade, UDim2.new(0, 590, 1, -32), UDim2.fromScale(0.5, 0.5))
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Visible = false
	panel.ZIndex = 11
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(620, 660)
	constraint.Parent = panel
	UI.label(panel, title, UDim2.new(1, -76, 0, 48), UDim2.fromOffset(18, 8), 22).ZIndex = 12
	UI.button(panel, "×", UDim2.fromOffset(44, 44), UDim2.new(1, -54, 0, 10), function()
		UI.open("")
	end).ZIndex =
		12
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Content"
	scroll.Size = UDim2.new(1, -32, 1, -78)
	scroll.Position = UDim2.fromOffset(16, 65)
	scroll.CanvasSize = UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 4
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ZIndex = 12
	scroll.Parent = panel
	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 12)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = scroll
	modals[name] = panel
	return scroll
end
function UI.row(parent: Instance, height: number): Frame
	local row = UI.frame(parent, UDim2.new(1, -6, 0, height), UDim2.new())
	row.BackgroundTransparency = 1
	row.ZIndex = 12
	return row
end
local objective = UI.frame(gui, UDim2.fromOffset(340, 80), UDim2.fromOffset(12, 12))
UI.Title = UI.label(objective, "REDLINE COUNTY", UDim2.new(1, -24, 0, 24), UDim2.fromOffset(12, 5), 16)
UI.Title.TextColor3 = UI.Accent
UI.Objective = UI.label(objective, "Start a getaway", UDim2.new(1, -24, 0, 42), UDim2.fromOffset(12, 30), 14)
UI.Alert = UI.label(gui, "", UDim2.new(0.7, 0, 0, 44), UDim2.new(0.15, 0, 0, 98), 14)
UI.Alert.TextXAlignment = Enum.TextXAlignment.Center
UI.Alert.BackgroundColor3 = UI.Ink
UI.Alert.BackgroundTransparency = 0.05
UI.Alert.Visible = false
UI.Wallet = UI.label(gui, "$0", UDim2.fromOffset(138, 28), UDim2.new(1, -150, 0, 12), 18)
UI.Wallet.TextXAlignment = Enum.TextXAlignment.Right
local menu = UI.button(gui, "MENU [M]", UDim2.fromOffset(118, 40), UDim2.new(1, -130, 0, 48), function()
	UI.toggle("menu")
end)
UI.Speed = UI.label(gui, "", UDim2.fromOffset(205, 80), UDim2.new(1, -220, 1, -106), 17)
UI.Speed.TextXAlignment = Enum.TextXAlignment.Right
UI.Diagnostic = UI.label(gui, "", UDim2.new(0.7, 0, 0, 80), UDim2.new(0.15, 0, 0, 145), 13)
UI.Diagnostic.BackgroundColor3 = UI.Ink
UI.Diagnostic.BackgroundTransparency = 0.05
UI.Diagnostic.Visible = false
UI.Toast = UI.label(gui, "", UDim2.new(0.7, 0, 0, 42), UDim2.new(0.15, 0, 1, -58), 14)
UI.Toast.TextXAlignment = Enum.TextXAlignment.Center
UI.Toast.ZIndex = 30
UI.Toast.BackgroundColor3 = UI.Ink
UI.Toast.BackgroundTransparency = 0.05
local toastUntil = 0
function UI.notify(text: string)
	UI.Toast.Text = text
	toastUntil = os.clock() + 5
end
UI.Map = UI.frame(gui, UDim2.fromOffset(192, 192), UDim2.new(0, 12, 1, -216))
UI.Map.ClipsDescendants = true
local mapButton = UI.button(UI.Map, "MAP [P]", UDim2.new(1, 0, 0, 32), UDim2.new(0, 0, 1, -32), function()
	UI.toggle("map")
end)
mapButton.ZIndex = 4
local menuContent = UI.modal("menu", "REDLINE COUNTY")
for _, entry in
	{
		{ "jobs", "Getaway jobs [J]" },
		{ "cars", "Your garage" },
		{ "workshop", "Workshop [U]" },
		{ "settings", "Driving & accessibility" },
		{ "map", "District map [P]" },
	}
do
	local name = entry[1]
	UI.button(UI.row(menuContent, 48), entry[2], UDim2.fromScale(1, 1), UDim2.new(), function()
		UI.open(name)
	end).ZIndex =
		13
end
local request =
	game:GetService("ReplicatedStorage"):WaitForChild("Remotes"):WaitForChild("VehicleRequest") :: RemoteEvent
UI.button(UI.row(menuContent, 48), "Recover / repair at home", UDim2.fromScale(1, 1), UDim2.new(), function()
	request:FireServer("Reset")
	UI.open("")
end)
UI.button(UI.row(menuContent, 48), "Abandon current job", UDim2.fromScale(1, 1), UDim2.new(), function()
	request:FireServer("CancelMission")
	UI.open("")
end)
UI.button(UI.row(menuContent, 48), "Toggle turbo [T]", UDim2.fromScale(1, 1), UDim2.new(), function()
	request:FireServer("Turbo")
	UI.open("")
end)
local settings = UI.modal("settings", "DRIVING SETTINGS")
local function toggleSetting(attribute: string, title: string, default: boolean)
	if player:GetAttribute(attribute) == nil then
		player:SetAttribute(attribute, default)
	end
	local button: TextButton
	local function refresh()
		button.Text = title .. ": " .. (if player:GetAttribute(attribute) then "ON" else "OFF")
	end
	button = UI.button(UI.row(settings, 46), title, UDim2.fromScale(1, 1), UDim2.new(), function()
		player:SetAttribute(attribute, not player:GetAttribute(attribute))
		refresh()
	end)
	player:GetAttributeChangedSignal(attribute):Connect(refresh)
	refresh()
end
toggleSetting("NightPreference", "Night driving [N]", true)
toggleSetting("CockpitView", "Interior camera [V]", false)
player:SetAttribute("CockpitHeight", 0)
local heightButton: TextButton
heightButton = UI.button(
	UI.row(settings, 46),
	"Interior eye height: NORMAL",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	function()
		local current = (player:GetAttribute("CockpitHeight") :: number?) or 0
		local nextHeight = if current == 0 then 0.2 elseif current > 0 then -0.2 else 0
		player:SetAttribute("CockpitHeight", nextHeight)
		heightButton.Text = "Interior eye height: "
			.. (if nextHeight == 0 then "NORMAL" elseif nextHeight > 0 then "HIGH" else "LOW")
	end
)
toggleSetting("ReducedFlashing", "Reduced flashing", true)
toggleSetting("ReducedMotion", "Steady camera", false)
toggleSetting("HeadlightsEnabled", "Headlights [H]", true)
player:SetAttribute("NativeHeadlights", false) -- Studio-only A/B diagnostic attribute; H always controls ON/OFF.
toggleSetting("WideTouchControls", "Wider touch controls", false)
player:SetAttribute("SirenVolume", 0.5)
local siren: TextButton
siren = UI.button(UI.row(settings, 46), "Siren volume: 50%", UDim2.fromScale(1, 1), UDim2.new(), function()
	local current = (player:GetAttribute("SirenVolume") :: number?) or 0.5
	current = (math.floor(current * 4 + 1) % 5) / 4
	player:SetAttribute("SirenVolume", current)
	siren.Text = "Siren volume: " .. math.floor(current * 100) .. "%"
end)
local save = UI.label(UI.row(settings, 60), "", UDim2.fromScale(1, 1), UDim2.new(), 13)
UI.label(
	UI.row(settings, 35),
	"Map © OpenStreetMap contributors · ODbL 1.0",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	12
)
if RunService:IsStudio() then
	UI.button(UI.row(menuContent, 46), "Developer tools", UDim2.fromScale(1, 1), UDim2.new(), function()
		UI.open("developer")
	end)
	local dev = UI.modal("developer", "DEVELOPER TOOLS")
	for _, entry in
		{
			{ "Lab", "Handling lab" },
			{ "Highway", "Autobahn" },
			{ "Diagnostics", "Driving diagnostics" },
			{ "Profile", "Performance capture" },
		}
	do
		local action = entry[1]
		UI.button(UI.row(dev, 46), entry[2], UDim2.fromScale(1, 1), UDim2.new(), function()
			if action == "Diagnostics" or action == "Profile" then
				player:SetAttribute(action, not player:GetAttribute(action))
			else
				request:FireServer(action)
			end
			UI.open("")
		end)
	end
end
Input.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.M or key == Enum.KeyCode.ButtonStart then
		UI.toggle("menu")
	elseif key == Enum.KeyCode.J then
		UI.toggle("jobs")
	elseif key == Enum.KeyCode.U then
		UI.toggle("workshop")
	elseif key == Enum.KeyCode.P then
		UI.toggle("map")
	elseif key == Enum.KeyCode.ButtonB and UI.Name ~= "" then
		UI.open("")
	end
end)
local clock = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	if clock < 0.1 then
		return
	end
	clock = 0
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local w, h = shade.AbsoluteSize.X, shade.AbsoluteSize.Y
	for _, panel in modals do
		panel.Size = UDim2.fromOffset(math.min(590, w - 24), math.min(660, h - 24))
	end
	objective.Size = UDim2.fromOffset(math.min(340, math.max(144, w - 176)), 80)
	local touch = Input.TouchEnabled
	local compact = touch and h < 540
	local mapSize = if compact then 80 elseif w < 600 then 155 else 192
	UI.Map.Position = if compact
		then UDim2.fromOffset(12, 102)
		else UDim2.new(0, 12, 1, if touch then -365 else -216)
	UI.Map.Size = UDim2.fromOffset(mapSize, mapSize)
	UI.Speed.Position = if compact
		then UDim2.new(0.5, -85, 1, -80)
		else UDim2.new(1, if touch and w < 600 then -190 else -220, 1, if touch then -260 else -106)
	UI.Speed.Size =
		UDim2.fromOffset(if compact or (touch and w < 600) then 175 else 205, if compact then 65 else 80)
	UI.Speed.TextSize = if compact then 12 else 15
	UI.Speed.Visible = UI.Name == ""
	UI.Map.Visible = UI.Name == ""
	objective.Visible = UI.Name == ""
	UI.Alert.Visible = UI.Name == "" and UI.Alert.Text ~= ""
	UI.Alert.Position = UDim2.new(0.15, 0, 0, if player:GetAttribute("MissionChoice") then 162 else 98)
	UI.Toast.Visible = os.clock() < toastUntil
	UI.Wallet.Text = "$" .. tostring(player:GetAttribute("GetawayCash") or 0)
	save.Text = tostring(player:GetAttribute("SaveStatus") or "Loading garage")
	menu.Visible = UI.Name == ""
end)
return UI
