--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Units = require(ReplicatedStorage.Shared.Units)
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local driveInput = remotes:WaitForChild("DriveInput") :: RemoteEvent
local request = remotes:WaitForChild("VehicleRequest") :: RemoteEvent
local notice = remotes:WaitForChild("Notice") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name, gui.ResetOnSpawn = "RedlineHUD", false
gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
gui.Parent = player:WaitForChild("PlayerGui")
local panel = Instance.new("Frame")
panel.Position, panel.Size = UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 184)
panel.BackgroundColor3, panel.BackgroundTransparency = Color3.fromRGB(18, 28, 42), 0.08
panel.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius, corner.Parent = UDim.new(0, 12), panel

local function label(text: string, y: number, height: number, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Position, l.Size = UDim2.fromOffset(12, y), UDim2.new(1, -24, 0, height)
	l.BackgroundTransparency = 1
	l.Text, l.TextSize, l.TextWrapped = text, size, true
	l.Font, l.TextColor3 = Enum.Font.GothamMedium, Color3.fromRGB(230, 241, 238)
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = panel
	return l
end
local title = label("REDLINE COUNTY  /  STARTING", 8, 24, 18)
title.TextColor3 = Color3.fromRGB(255, 144, 127)
local status = label("Loading your highway starting point…", 36, 32, 14)
label("WASD / arrows: drive · Space/Shift: drift · T: turbo · F: exit · R: recover", 70, 28, 13)
local buttons = Instance.new("Frame")
buttons.Position, buttons.Size = UDim2.fromOffset(12, 108), UDim2.new(1, -24, 0, 64)
buttons.BackgroundTransparency, buttons.Parent = 1, panel
local grid = Instance.new("UIGridLayout")
grid.CellSize, grid.CellPadding = UDim2.new(1 / 3, -4, 0.5, -3), UDim2.fromOffset(6, 0)
grid.Parent = buttons
for _, kind in { "Compact", "Coupe", "Interceptor", "Autobahn", "Turbo", "Recover" } do
	local button = Instance.new("TextButton")
	button.Text, button.TextSize = kind, 13
	button.Font = Enum.Font.GothamBold
	button.TextColor3, button.BackgroundColor3 = Color3.fromRGB(235, 246, 241), Color3.fromRGB(46, 85, 99)
	button.Parent = buttons
	button.Activated:Connect(function()
		if kind == "Recover" then
			request:FireServer("Reset")
		elseif kind == "Autobahn" then
			request:FireServer("Highway")
		elseif kind == "Turbo" then
			request:FireServer("Turbo")
		else
			request:FireServer("Spawn", kind)
		end
	end)
end
local speed = Instance.new("TextLabel")
speed.AnchorPoint, speed.Position = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14)
speed.Size = UDim2.fromOffset(270, 78)
speed.BackgroundColor3, speed.BackgroundTransparency = Color3.fromRGB(18, 28, 42), 0.15
speed.TextColor3, speed.TextSize, speed.Font = Color3.fromRGB(121, 239, 216), 16, Enum.Font.GothamBold
speed.Text, speed.Parent = "GARAGE", gui

notice.OnClientEvent:Connect(function(message: string)
	status.Text = message
end)
local initial = player:GetAttribute("GarageMessage")
if type(initial) == "string" then
	status.Text = initial
end

local held: { [string]: boolean } = {}
local active: BasePart? = nil
local elapsed = 0
local cameraPosition: Vector3? = nil
local previousBodyPosition: Vector3? = nil
local previousType: Enum.CameraType? = nil
local previousFov = 70
local controls = {
	{
		name = "Forward",
		title = "GAS",
		keys = { Enum.KeyCode.W, Enum.KeyCode.Up },
		position = UDim2.new(1, -90, 1, -195),
	},
	{
		name = "Reverse",
		title = "BRAKE",
		keys = { Enum.KeyCode.S, Enum.KeyCode.Down },
		position = UDim2.new(1, -90, 1, -115),
	},
	{
		name = "Left",
		title = "◀",
		keys = { Enum.KeyCode.A, Enum.KeyCode.Left },
		position = UDim2.new(0, 22, 1, -115),
	},
	{
		name = "Right",
		title = "▶",
		keys = { Enum.KeyCode.D, Enum.KeyCode.Right },
		position = UDim2.new(0, 102, 1, -115),
	},
	{
		name = "Drift",
		title = "DRIFT",
		keys = { Enum.KeyCode.Space, Enum.KeyCode.LeftShift },
		position = UDim2.new(1, -170, 1, -115),
	},
	{ name = "Exit", title = "EXIT", keys = { Enum.KeyCode.F }, position = UDim2.new(0, 22, 1, -195) },
}

local function ownBody(): BasePart?
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	local seat = if humanoid then humanoid.SeatPart else nil
	if not seat or not seat:IsA("VehicleSeat") then
		return nil
	end
	local model = seat.Parent
	if not model or not model:IsA("Model") or model:GetAttribute("OwnerId") ~= player.UserId then
		return nil
	end
	return model.PrimaryPart
end

local hiddenParts: { [BasePart]: number } = {}
local function stopControls()
	for part, transparency in hiddenParts do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(hiddenParts)
	for _, control in controls do
		ContextActionService:UnbindAction("Redline" .. control.name)
	end
	table.clear(held)
	driveInput:FireServer(0, 0, false)
	local camera = workspace.CurrentCamera
	if camera and previousType then
		camera.CameraType = previousType
		camera.FieldOfView = previousFov
		local humanoid = if player.Character then player.Character:FindFirstChildOfClass("Humanoid") else nil
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	previousType, cameraPosition, previousBodyPosition = nil, nil, nil
end

local function startControls()
	local camera = workspace.CurrentCamera
	if camera then
		previousType, previousFov = camera.CameraType, camera.FieldOfView
	end
	for _, control in controls do
		ContextActionService:BindActionAtPriority(
			"Redline" .. control.name,
			function(_: string, state: Enum.UserInputState)
				if state == Enum.UserInputState.Begin then
					held[control.name] = true
					if control.name == "Exit" then
						local humanoid = if player.Character
							then player.Character:FindFirstChildOfClass("Humanoid")
							else nil
						if humanoid then
							humanoid.Sit = false
						end
					end
				elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
					held[control.name] = false
				end
				return Enum.ContextActionResult.Sink
			end,
			true,
			3000,
			table.unpack(control.keys)
		)
		ContextActionService:SetTitle("Redline" .. control.name, control.title)
		ContextActionService:SetPosition("Redline" .. control.name, control.position)
	end
end

ContextActionService:BindAction("RedlineTurbo", function(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin and ownBody() then
		request:FireServer("Turbo")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.T)

ContextActionService:BindAction("RedlineRecover", function(_: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		request:FireServer("Reset")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.R)
UserInputService.WindowFocusReleased:Connect(function()
	table.clear(held)
	driveInput:FireServer(0, 0, false)
end)
UserInputService.TextBoxFocused:Connect(function()
	table.clear(held)
	driveInput:FireServer(0, 0, false)
end)

RunService:BindToRenderStep("RedlineCamera", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
	local body = ownBody()
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	title.Text = if root and math.abs(root.Position.X - Config.Highway.X) < 300
		then "REDLINE COUNTY / AUTOBAHN · TRAFFIC"
		else "REDLINE COUNTY / GARAGE · CLICK AUTOBAHN TO ENTER"
	if body ~= active then
		if active then
			stopControls()
		end
		active = body
		if active then
			startControls()
		end
	end
	if not body then
		speed.Text = "GARAGE"
		return
	end
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local throttle = if typing then 0 else (if held.Forward then 1 else 0) - (if held.Reverse then 1 else 0)
	local steer = if typing then 0 else (if held.Right then 1 else 0) - (if held.Left then 1 else 0)
	elapsed += dt
	if elapsed >= 1 / Config.InputHz then
		elapsed = 0
		driveInput:FireServer(throttle, steer, not typing and held.Drift == true)
	end
	local velocity = body.AssemblyLinearVelocity
	local model = body.Parent :: Model
	local boost = (model:GetAttribute("Boost") :: number?) or 0
	local heat = (model:GetAttribute("TurboHeat") :: number?) or 0
	local turboState = if model:GetAttribute("TurboOverheated")
		then "COOLING"
		elseif model:GetAttribute("TurboEnabled") then "TURBO"
		else "TURBO OFF"
	local trip = if model:GetAttribute("Highway")
		then string.format(
			"AUTOBAHN · %.2f km",
			Units.kilometres((model:GetAttribute("TripStuds") :: number?) or 0)
		)
		else "HANDLING LAB"
	speed.Text = string.format(
		"%03d km/h · %03d mph %s\n%s %02d%% · HEAT %02d%%\n%s",
		math.floor(Units.kmh((velocity * Vector3.new(1, 0, 1)).Magnitude)),
		math.floor(Units.mph((velocity * Vector3.new(1, 0, 1)).Magnitude)),
		if held.Drift then "SLIDE" else "",
		turboState,
		boost * 100,
		heat * 100,
		trip
	)
	-- Translate the chase camera with recycled highway space to preserve the view.
	if previousBodyPosition and cameraPosition then
		local delta = body.Position - previousBodyPosition
		if delta.Magnitude > 1000 then
			cameraPosition += delta
		end
	end
	previousBodyPosition = body.Position
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local eye = body:FindFirstChild("CockpitEye")
	if eye and eye:IsA("Attachment") and not model:GetAttribute("Crashed") then
		if character then
			for _, part in character:GetDescendants() do
				if part:IsA("BasePart") then
					if hiddenParts[part] == nil then
						hiddenParts[part] = part.LocalTransparencyModifier
					end
					part.LocalTransparencyModifier = 1
				end
			end
		end
		camera.CFrame = eye.WorldCFrame
		camera.Focus = camera.CFrame * CFrame.new(0, 0, -40)
		camera.FieldOfView = 80
		return
	end
	local facing = body.CFrame.LookVector * Vector3.new(1, 0, 1)
	if facing.Magnitude < 0.1 then
		facing = Vector3.new(0, 0, -1)
	end
	facing = facing.Unit
	local focus = body.Position + Vector3.new(0, 2, 0) + facing * math.min(velocity.Magnitude * 0.07, 7)
	local desired = body.Position - facing * Config.CameraDistance + Vector3.new(0, Config.CameraHeight, 0)
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.FilterDescendantsInstances = { body.Parent :: Instance }
	ray.CollisionGroup = "Cars"
	ray.RespectCanCollide = true
	ray.IgnoreWater = true
	local hit = workspace:Raycast(focus, desired - focus, ray)
	if hit then
		desired = hit.Position + hit.Normal * 1.2
	end
	local alpha = 1 - math.exp(-Config.CameraResponse * dt)
	local prior = cameraPosition
	cameraPosition = if prior and (prior - desired).Magnitude < 80
		then prior:Lerp(desired, alpha)
		else desired
	-- Check the interpolated position too, so smoothing cannot cut through a barrier.
	local obstruction = workspace:Raycast(focus, (cameraPosition :: Vector3) - focus, ray)
	if obstruction then
		cameraPosition = obstruction.Position + obstruction.Normal * 1.2
	end
	camera.CFrame = CFrame.lookAt(cameraPosition :: Vector3, focus)
	camera.Focus = CFrame.new(focus)
	camera.FieldOfView += (70 + math.min(velocity.Magnitude / 10, 10) - camera.FieldOfView) * alpha
end)
print("[REDLINE COUNTY] Driving HUD, keyboard/touch controls and chase camera ready.")
