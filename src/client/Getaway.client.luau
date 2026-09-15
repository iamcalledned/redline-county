--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Input = game:GetService("UserInputService")
local UI = require(script.Parent.Interface)
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Nav = require(Shared.RoadNavigation)
local RoadGraph = require(Shared.RoadGraph)
local Graph = RoadGraph.Nodes
local Contracts = require(Shared.Contracts)
local Progression = require(Shared.Progression)
local player = Players.LocalPlayer
local request = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("VehicleRequest") :: RemoteEvent
local content = UI.modal("jobs", "GETAWAY JOBS")
local difficulty = "light"
local difficultyRow = UI.row(content, 46)
local difficultyButtons: { TextButton } = {}
for i, option in Progression.Difficulties do
	local b = UI.button(
		difficultyRow,
		option.Name .. " " .. option.Multiplier .. "×",
		UDim2.new(1 / 3, -6, 1, 0),
		UDim2.fromScale((i - 1) / 3, 0),
		function()
			difficulty = option.Id
		end
	)
	table.insert(difficultyButtons, b)
end
UI.label(
	UI.row(content, 48),
	"Denser traffic earns more. Bank the haul, then improve your car.",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	14
)
for _, contract in Contracts do
	local row = UI.row(content, 108)
	UI.label(
		row,
		contract.Name .. " · $" .. contract.Reward .. "+",
		UDim2.new(1, -100, 0, 32),
		UDim2.new(),
		17
	).TextColor3 =
		UI.Gold
	UI.label(row, contract.Brief, UDim2.new(1, -100, 0, 68), UDim2.fromOffset(0, 34), 13)
	UI.button(row, "START", UDim2.fromOffset(90, 48), UDim2.new(1, -90, 0, 28), function()
		request:FireServer("Mission", contract.Id, difficulty)
	end)
end
local welcome = UI.modal("welcome", "WELCOME TO REDLINE COUNTY")
UI.label(
	UI.row(welcome, 120),
	"Your car. Your route. Your getaway.\n\nCollect a package, lose the police, and bring the money home.",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	20
)
UI.button(UI.row(welcome, 56), "START FIRST GETAWAY", UDim2.fromScale(1, 1), UDim2.new(), function()
	request:FireServer("Mission", "first", "light")
end)
UI.button(UI.row(welcome, 48), "Explore my garage", UDim2.fromScale(1, 1), UDim2.new(), function()
	UI.open("cars")
end)
UI.label(
	UI.row(welcome, 70),
	"Your bay opens and you are seated automatically. Follow the gold pickup and cyan road guidance.",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	14
)
local results = UI.modal("results", "RUN RESULTS")
local resultTitle = UI.label(UI.row(results, 60), "", UDim2.fromScale(1, 1), UDim2.new(), 26)
local resultDetail = UI.label(UI.row(results, 140), "", UDim2.fromScale(1, 1), UDim2.new(), 17)
UI.button(UI.row(results, 54), "RETRY THIS JOB", UDim2.fromScale(1, 1), UDim2.new(), function()
	request:FireServer("RetryMission")
end)
UI.button(UI.row(results, 50), "FIT YOUR NEXT UPGRADE", UDim2.fromScale(1, 1), UDim2.new(), function()
	request:FireServer("ReturnHome", "workshop")
end)
UI.button(UI.row(results, 50), "CHOOSE ANOTHER JOB", UDim2.fromScale(1, 1), UDim2.new(), function()
	request:FireServer("ReturnHome", "jobs")
end)
UI.button(UI.row(results, 46), "Return to driving", UDim2.fromScale(1, 1), UDim2.new(), function()
	UI.open("")
end)
local decisions = UI.frame(UI.Gui, UDim2.fromOffset(290, 60), UDim2.new(0.5, -145, 0, 98))
decisions.Visible = false
UI.button(decisions, "BANK [B]", UDim2.new(0.5, -8, 1, -12), UDim2.fromOffset(6, 6), function()
	request:FireServer("HeatChoice", "bank")
end)
UI.button(decisions, "CONTINUE [C]", UDim2.new(0.5, -8, 1, -12), UDim2.new(0.5, 2, 0, 6), function()
	request:FireServer("HeatChoice", "continue")
end)
Input.InputBegan:Connect(function(input, processed)
	if processed or UI.Name ~= "" or not player:GetAttribute("MissionChoice") then
		return
	end
	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonB then
		request:FireServer("HeatChoice", "bank")
	end
	if input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.ButtonA then
		request:FireServer("HeatChoice", "continue")
	end
end)
game:GetService("ContextActionService")
	:BindActionAtPriority(
		"RedlineHeatChoice",
		function(_: string, state: Enum.UserInputState, input: InputObject)
			if UI.Name ~= "" then
				return Enum.ContextActionResult.Pass
			end
			local humanoid = if player.Character
				then player.Character:FindFirstChildOfClass("Humanoid")
				else nil
			if not humanoid or not humanoid.SeatPart then
				return Enum.ContextActionResult.Pass
			end
			if state == Enum.UserInputState.Begin and player:GetAttribute("MissionChoice") then
				request:FireServer(
					"HeatChoice",
					if input.KeyCode == Enum.KeyCode.ButtonA then "continue" else "bank"
				)
			end
			return Enum.ContextActionResult.Sink -- A must not also jump out of the driver's seat.
		end,
		false,
		4000,
		Enum.KeyCode.ButtonA,
		Enum.KeyCode.ButtonB
	)
local overviewContent = UI.modal("map", "HOPEDALE · DISTRICT MAP")
local overview = UI.frame(UI.row(overviewContent, 390), UDim2.fromScale(1, 1), UDim2.new())
overview.ClipsDescendants = true
UI.label(
	UI.row(overviewContent, 60),
	"Green: route · Gold: pickup · Red: police\nTown blocks · Parkway · Mill roads\nMap © OpenStreetMap contributors · ODbL 1.0",
	UDim2.fromScale(1, 1),
	UDim2.new(),
	14
)
local small = UI.frame(UI.Map, UDim2.new(1, 0, 1, -32), UDim2.new())
small.ClipsDescendants = true
small.BackgroundTransparency = 1
local minX, minZ, maxX, maxZ = math.huge, math.huge, -math.huge, -math.huge
local edges: { { Nav.Point } } = {}
for i, node in Graph do
	minX = math.min(minX, node.x)
	minZ = math.min(minZ, node.z)
	maxX = math.max(maxX, node.x)
	maxZ = math.max(maxZ, node.z)
	for _, j in node.links do
		if i < j or not table.find(Graph[j].links, i) then
			table.insert(edges, { { x = node.x, z = node.z }, { x = Graph[j].x, z = Graph[j].z } })
		end
	end
end
type View = { frame: Frame, lines: { Frame }, dots: { TextLabel } }
local views: { View } =
	{ { frame = small, lines = {}, dots = {} }, { frame = overview, lines = {}, dots = {} } }
local path: { Nav.Point } = {}
local function line(view: View, index: number, a: Vector2, b: Vector2, color: Color3, width: number)
	if not view.lines[index] then
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0, 0.5)
		f.BorderSizePixel = 0
		f.Parent = view.frame
		view.lines[index] = f
	end
	local f = view.lines[index]
	f.Position = UDim2.fromOffset(a.X, a.Y)
	f.Size = UDim2.fromOffset((b - a).Magnitude, width)
	f.Rotation = math.deg(math.atan2(b.Y - a.Y, b.X - a.X))
	f.BackgroundColor3 = color
	f.Visible = true
end
local function dot(view: View, index: number, p: Vector2, text: string, color: Color3)
	if not view.dots[index] then
		local label = UI.label(view.frame, text, UDim2.fromOffset(18, 18), UDim2.new(), 17)
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.TextXAlignment = Enum.TextXAlignment.Center
		label.ZIndex = 3
		view.dots[index] = label
	end
	local label = view.dots[index]
	label.Position = UDim2.fromOffset(p.X, p.Y)
	label.Text = text
	label.TextColor3 = color
	label.Visible = true
end
local function draw(view: View, root: BasePart, full: boolean)
	local w, h = view.frame.AbsoluteSize.X, view.frame.AbsoluteSize.Y
	if w < 10 or h < 10 then
		return
	end
	local scale = if full then math.min((w - 24) / (maxX - minX), (h - 24) / (maxZ - minZ)) else 0.2
	local function project(p: Nav.Point): Vector2
		if full then
			return Vector2.new(12 + (p.x - minX) * scale, 12 + (p.z - minZ) * scale)
		end
		local localPoint = root.CFrame:PointToObjectSpace(Vector3.new(p.x, root.Position.Y, p.z))
		return Vector2.new(w / 2 + localPoint.X * scale, h * 0.62 + localPoint.Z * scale)
	end
	local count = 0
	local function segment(a: Nav.Point, b: Nav.Point, color: Color3, width: number)
		local aa, bb = project(a), project(b)
		if
			not full
			and (
				math.max(aa.X, bb.X) < 0
				or math.min(aa.X, bb.X) > w
				or math.max(aa.Y, bb.Y) < 0
				or math.min(aa.Y, bb.Y) > h
			)
		then
			return
		end
		count += 1
		line(view, count, aa, bb, color, width)
	end
	for _, edge in edges do
		segment(edge[1], edge[2], Color3.fromRGB(74, 95, 105), 3)
	end
	for i = 1, #path - 1 do
		segment(path[i], path[i + 1], UI.Accent, 4)
	end
	for i = count + 1, #view.lines do
		view.lines[i].Visible = false
	end
	local dots = 1
	dot(view, dots, project({ x = root.Position.X, z = root.Position.Z }), "▲", UI.Text)
	dots += 1
	dot(view, dots, project(Graph[RoadGraph.Home]), "H", UI.Accent)
	local block = player:GetAttribute("RoadblockPosition")
	if typeof(block) == "Vector3" then
		dots += 1
		dot(view, dots, project({ x = block.X, z = block.Z }), "×", Color3.fromRGB(245, 104, 88))
	end
	local target = player:GetAttribute("MissionTarget")
	if typeof(target) == "Vector3" then
		dots += 1
		dot(view, dots, project({ x = target.X, z = target.Z }), "●", UI.Gold)
	end
	for _, name in { "PolicePatrols", "TownTraffic" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			for _, car in folder:GetChildren() do
				if
					car:IsA("Model")
					and car.PrimaryPart
					and car:GetAttribute("Police")
					and (car.PrimaryPart.Position - root.Position).Magnitude < 500
				then
					dots += 1
					dot(
						view,
						dots,
						project({ x = car.PrimaryPart.Position.X, z = car.PrimaryPart.Position.Z }),
						"●",
						Color3.fromRGB(245, 104, 88)
					)
				end
			end
		end
	end
	for i = dots + 1, #view.dots do
		view.dots[i].Visible = false
	end
end
local visuals = Instance.new("Folder")
visuals.Name = "LocalMissionGuidance"
visuals.Parent = workspace
local function visual(name: string): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = UI.Accent
	p.Parent = visuals
	return p
end
local marker = visual("Pickup")
marker.Shape = Enum.PartType.Cylinder
marker.Size = Vector3.new(0.16, 32, 32)
local markerLabel = Instance.new("BillboardGui")
markerLabel.Size = UDim2.fromOffset(200, 45)
markerLabel.StudsOffset = Vector3.new(0, 10, 0)
markerLabel.MaxDistance = 350
markerLabel.AlwaysOnTop = true
markerLabel.Parent = marker
local markerText = UI.label(markerLabel, "PICKUP", UDim2.fromScale(1, 1), UDim2.new(), 16)
markerText.TextXAlignment = Enum.TextXAlignment.Center
markerText.TextColor3 = UI.Gold
local crumbs: { Part } = {}
for i = 1, 18 do
	local part = visual("Route" .. i)
	part.Size = Vector3.new(0.45, 0.08, 4)
	table.insert(crumbs, part)
end
local clock, routeClock = 0, 0
local priorPhase = ""
local initialized = false
local resultSequence = 0
RunService.Heartbeat:Connect(function(dt)
	clock += dt
	routeClock += dt
	if clock < 0.15 then
		return
	end
	clock = 0
	if not initialized and player:GetAttribute("ProfileReady") then
		initialized = true
		UI.open(if (player:GetAttribute("GetawayWins") :: number? or 0) == 0 then "welcome" else "jobs")
	end
	local phase = (player:GetAttribute("MissionPhase") :: string?) or "idle"
	local active = phase == "pickup" or phase == "run" or phase == "escape" or phase == "deliver"
	if
		active
		and priorPhase ~= phase
		and (UI.Name == "jobs" or UI.Name == "welcome" or UI.Name == "results")
	then
		UI.open("")
	end
	priorPhase = phase
	local sequence = (player:GetAttribute("ResultSequence") :: number?) or 0
	if sequence ~= resultSequence then
		resultSequence = sequence
		resultTitle.Text = if phase == "complete"
			then (if (player:GetAttribute("LastReward") :: number? or 0) > 0
				then "ESCAPED & BANKED"
				else "ESCAPED")
			else "NEXT TIME, A DIFFERENT ROUTE"
		local kind = tostring(player:GetAttribute("SelectedCar") or "Electric")
		local level = (player:GetAttribute("Upgrade_" .. kind .. "_Brakes") :: number?) or 0
		local nextPrice = Progression.Catalog[2].Prices[level + 1]
		local goal = if nextPrice
			then "Next brakes: $" .. nextPrice .. " · need $" .. math.max(
				0,
				nextPrice - ((player:GetAttribute("GetawayCash") :: number?) or 0)
			)
			else "Brakes complete · try another workshop part."
		resultDetail.Text = tostring(player:GetAttribute("MissionMessage") or "")
			.. "\nHaul: $"
			.. tostring(player:GetAttribute("LastReward") or 0)
			.. " (clean bonus $"
			.. tostring(player:GetAttribute("LastCleanBonus") or 0)
			.. ")"
			.. " · "
			.. tostring(player:GetAttribute("LastRunSeconds") or 0)
			.. " s\nBank: $"
			.. tostring(player:GetAttribute("GetawayCash") or 0)
			.. "\n"
			.. goal
		UI.open("results")
	end
	for i, b in difficultyButtons do
		b.BackgroundColor3 = if Progression.Difficulties[i].Id == difficulty then UI.Gold else UI.Accent
	end
	decisions.Visible = player:GetAttribute("MissionChoice") == true and UI.Name == ""
	local remaining = (player:GetAttribute("MissionRemaining") :: number?) or 0
	UI.Title.Text = if active
		then tostring(player:GetAttribute("MissionName")) .. string.format(
			" · %d:%02d",
			remaining // 60,
			remaining % 60
		)
		else "REDLINE COUNTY"
	local cargo = player:GetAttribute("CargoQuality")
	UI.Objective.Text = if decisions.Visible
		then "Haul $" .. tostring(player:GetAttribute("UnbankedHaul") or 0) .. " · Bank or continue? [B / C]"
		elseif phase == "pickup" and not player:GetAttribute("HasDriven") then (if Input.TouchEnabled
			then "GAS: accelerate · arrows: steer · BRAKE: slow"
			elseif Input.GamepadEnabled then "RT: gas · LT: brake · left stick: steer"
			else "W / S: gas / brake · A / D: steer")
		elseif phase == "escape" then (if player:GetAttribute("PoliceSeeing")
			then "Break police sight: use corners and cover."
			else "SEARCHING · Escape " .. tostring(player:GetAttribute("MissionEscape") or 0) .. " / 10 s")
		elseif phase == "deliver" then "Return home and stop to bank your haul."
		elseif active and typeof(cargo) == "number" then "FRAGILE · Cargo " .. cargo .. "% · Avoid impacts."
		elseif active then "Follow the cyan route to the gold package."
		else "J: jobs · U: upgrades · E: enter car"
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if
		humanoid
		and humanoid.SeatPart
		and humanoid.SeatPart.Parent
		and humanoid.SeatPart.Parent:IsA("Model")
	then
		root = humanoid.SeatPart.Parent.PrimaryPart or root
	end
	local target = player:GetAttribute("MissionTarget")
	local hasTarget = active and typeof(target) == "Vector3"
	marker.Transparency = if hasTarget then 0.45 else 1
	markerLabel.Enabled = hasTarget
	if hasTarget and typeof(target) == "Vector3" then
		marker.CFrame = CFrame.new(target + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		markerText.Text = if phase == "deliver" then "SAFEHOUSE · STOP" else "PICKUP"
	end
	if routeClock >= 0.5 then
		routeClock = 0
		path = if root
				and hasTarget
				and typeof(target) == "Vector3"
			then Nav.route(
				Graph,
				{ x = root.Position.X, z = root.Position.Z },
				{ x = target.X, z = target.Z }
			)
			else {}
		for i, crumb in crumbs do
			local a, b = Nav.ahead(path, i * 14), Nav.ahead(path, i * 14 + 4)
			local usable = a ~= nil and b ~= nil and Nav.distance(a, b) > 0.1
			crumb.Transparency = if usable then 0.25 else 1
			if usable and a and b then
				crumb.CFrame = CFrame.lookAt(Vector3.new(a.x, 32.35, a.z), Vector3.new(b.x, 32.35, b.z))
			end
		end
	end
	if root then
		if UI.Name == "" then
			draw(views[1], root, false)
		elseif UI.Name == "map" then
			draw(views[2], root, true)
		end
	end
end)
