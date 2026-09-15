--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ContextActionService = game:GetService("ContextActionService")
local UserInputService = game:GetService("UserInputService")
local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local Units = require(ReplicatedStorage.Shared.Units)
local Metrics = require(ReplicatedStorage.Shared.DrivingMetrics)
local CockpitFit = require(ReplicatedStorage.Shared.CockpitFit)
local TownMap = require(ReplicatedStorage.Shared.TownMap)
local metric = Metrics.new()
local cockpit = false
local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local driveInput = remotes:WaitForChild("DriveInput") :: RemoteEvent
local request = remotes:WaitForChild("VehicleRequest") :: RemoteEvent
local notice = remotes:WaitForChild("Notice") :: RemoteEvent

local UI = require(script.Parent.Interface)
local diagnosticLabel = UI.Diagnostic
local speed = UI.Speed
notice.OnClientEvent:Connect(function(message: string, destination: string?)
	UI.notify(message)
	if destination == "jobs" or destination == "workshop" then
		UI.open(destination)
	end
end)
local held: { [string]: boolean } = {}
local active: BasePart? = nil
local elapsed = 0
local cameraPosition: Vector3? = nil
local previousBodyPosition: Vector3? = nil
local previousType: Enum.CameraType? = nil
local previousFov = 70
local arrivalCharacter: Model? = nil
local controls = {
	{
		name = "Forward",
		title = "GAS",
		keys = { Enum.KeyCode.W, Enum.KeyCode.Up, Enum.KeyCode.ButtonR2 },
		position = UDim2.new(1, -90, 1, -195),
	},
	{
		name = "Reverse",
		title = "BRAKE",
		keys = { Enum.KeyCode.S, Enum.KeyCode.Down, Enum.KeyCode.ButtonL2 },
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
		keys = { Enum.KeyCode.Space, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonX },
		position = UDim2.new(0.5, -32, 1, -195),
	},
	{
		name = "Exit",
		title = "EXIT",
		keys = { Enum.KeyCode.F, Enum.KeyCode.ButtonY },
		position = UDim2.new(0, 22, 1, -195),
	},
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

local gamepadSteer = 0
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		gamepadSteer = if math.abs(input.Position.X) > 0.12 then input.Position.X else 0
	end
end)
local hiddenParts: { [BasePart]: number } = {}
local windows: { [BasePart]: number } = {}
local avatarConnection: RBXScriptConnection? = nil
local windowConnection: RBXScriptConnection? = nil
local function hideAvatar(part: Instance)
	if part:IsA("BasePart") then
		if hiddenParts[part] == nil then
			hiddenParts[part] = part.LocalTransparencyModifier
		end
		part.LocalTransparencyModifier = 1
	end
end
local function cacheWindow(part: Instance)
	local name = part.Name:lower()
	if
		part:IsA("BasePart")
		and (name == "glass" or name:find("door_glass", 1, true) or name:find("windshield", 1, true))
	then
		windows[part] = part.LocalTransparencyModifier
	end
end
local function stopControls()
	if avatarConnection then
		avatarConnection:Disconnect()
		avatarConnection = nil
	end
	if windowConnection then
		windowConnection:Disconnect()
		windowConnection = nil
	end
	for part, transparency in windows do
		if part.Parent then
			part.LocalTransparencyModifier = transparency
		end
	end
	table.clear(windows)
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
	local character = player.Character
	if character then
		for _, part in character:GetDescendants() do
			hideAvatar(part)
		end
		avatarConnection = character.DescendantAdded:Connect(hideAvatar)
	end
	if active and active.Parent then
		for _, part in active.Parent:GetDescendants() do
			cacheWindow(part)
		end
		windowConnection = active.Parent.DescendantAdded:Connect(cacheWindow)
	end
	metric = Metrics.new()
	local camera = workspace.CurrentCamera
	if camera then
		previousType, previousFov = camera.CameraType, camera.FieldOfView
	end
	for _, control in controls do
		ContextActionService:BindActionAtPriority(
			"Redline" .. control.name,
			function(_: string, state: Enum.UserInputState)
				if UI.Name ~= "" then
					held[control.name] = false
					return Enum.ContextActionResult.Pass
				end
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

local function layoutControls()
	local wide = player:GetAttribute("WideTouchControls") == true
	for _, control in controls do
		local button = ContextActionService:GetButton("Redline" .. control.name)
		if button then
			button.Visible = UI.Name == ""
			button.Size = UDim2.fromOffset(if wide then 76 else 64, if wide then 76 else 64)
			local pos = control.position
			ContextActionService:SetPosition(
				"Redline" .. control.name,
				UDim2.new(
					pos.X.Scale,
					pos.X.Offset + (if wide and pos.X.Scale == 0 then 16 else 0),
					pos.Y.Scale,
					pos.Y.Offset
				)
			)
		end
	end
end
UI.Changed.Event:Connect(function()
	table.clear(held)
	gamepadSteer = 0
	layoutControls()
end)
player:GetAttributeChangedSignal("WideTouchControls"):Connect(layoutControls)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		player:SetAttribute("CockpitView", not player:GetAttribute("CockpitView"))
	elseif input.KeyCode == Enum.KeyCode.G then
		player:SetAttribute("Diagnostics", not player:GetAttribute("Diagnostics"))
		metric = Metrics.new()
	end
end)
ContextActionService:BindAction("RedlineTurbo", function(_: string, state: Enum.UserInputState)
	if UI.Name ~= "" then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin and ownBody() then
		request:FireServer("Turbo")
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.T)

ContextActionService:BindAction("RedlineRecover", function(_: string, state: Enum.UserInputState)
	if UI.Name ~= "" and UI.Name ~= "results" then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Begin then
		request:FireServer(if UI.Name == "results" then "ReturnHome" else "Reset")
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
	cockpit = player:GetAttribute("CockpitView") == true
	diagnosticLabel.Visible = player:GetAttribute("Diagnostics") == true and body ~= nil and UI.Name == ""
	if body ~= active then
		if active then
			stopControls()
		end
		active = body
		if active then
			startControls()
			layoutControls()
		end
	end
	if not body then
		speed.Text = "GARAGE"
		local camera = workspace.CurrentCamera
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if camera and character and humanoid and root then
			camera.CameraType = Enum.CameraType.Custom
			camera.CameraSubject = humanoid
			player.CameraMinZoomDistance = 0.5
			local homeCenter = TownMap.Garage + Vector3.new(0, 0, 8 / 0.28)
			player.CameraMaxZoomDistance = if (root.Position - homeCenter).Magnitude < 85 then 8 else 24
			local arrival = character:GetAttribute("GarageArrival")
			-- Wait for the server's relocation to reach this client before setting the
			-- initial view. Do this once per character, leaving mouse orbit/zoom free.
			if
				arrivalCharacter ~= character
				and typeof(arrival) == "CFrame"
				and (root.Position - arrival.Position).Magnitude < 5
			then
				local focus = root.Position + Vector3.new(0, 1.5, 0)
				camera.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 3, 6), focus)
				camera.Focus = CFrame.new(focus)
				camera.FieldOfView = 70
				arrivalCharacter = character
			end
		end
		return
	end
	local typing = UserInputService:GetFocusedTextBox() ~= nil or UI.Name ~= ""
	local throttle = if typing then 0 else (if held.Forward then 1 else 0) - (if held.Reverse then 1 else 0)
	local steer = if typing
		then 0
		else math.clamp(
			(if held.Right then 1 else 0) - (if held.Left then 1 else 0) + gamepadSteer,
			-1,
			1
		)
	elapsed += dt
	if elapsed >= 1 / Config.InputHz then
		elapsed = 0
		driveInput:FireServer(throttle, steer, not typing and held.Drift == true)
	end
	local velocity = body.AssemblyLinearVelocity
	local model = body.Parent :: Model
	local horizontalKmh = Units.kmh((velocity * Vector3.new(1, 0, 1)).Magnitude)
	Metrics.step(metric, horizontalKmh, throttle, dt)
	diagnosticLabel.Text = string.format(
		"Steer %.1f° · ground %d/4 · damage %d%%\n0–50: %s s · last stop: %s m from %s km/h",
		(model:GetAttribute("SteeringAngle") :: number?) or 0,
		(model:GetAttribute("GroundedWheels") :: number?) or 0,
		(model:GetAttribute("Damage") :: number?) or 0,
		if metric.zeroTo50 then string.format("%.1f", metric.zeroTo50) else "—",
		if metric.lastStop then string.format("%.1f", metric.lastStop) else "—",
		if metric.lastFrom then string.format("%.0f", metric.lastFrom) else "—"
	)
	local boost = (model:GetAttribute("Boost") :: number?) or 0
	local heat = (model:GetAttribute("TurboHeat") :: number?) or 0
	local turboState = if model:GetAttribute("TurboOverheated")
		then "COOLING"
		elseif model:GetAttribute("TurboEnabled") then "TURBO"
		else "TURBO OFF"
	speed.Text = string.format(
		"%03d km/h · %03d mph\n%s %02d%% · TEMP %02d%%\nDAMAGE %02d%% · %s",
		math.floor(horizontalKmh),
		math.floor(Units.mph((velocity * Vector3.new(1, 0, 1)).Magnitude)),
		turboState,
		boost * 100,
		heat * 100,
		(model:GetAttribute("Damage") :: number?) or 0,
		if model:GetAttribute("Drifting")
			then "DRIFT " .. tostring(model:GetAttribute("DriftPoints") or 0)
			else "GRIP"
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
	for part in hiddenParts do
		if part.Parent then
			part.LocalTransparencyModifier = 1
		end
	end
	for part, transparency in windows do
		if part.Parent then
			part.LocalTransparencyModifier = if cockpit then 0.9 else transparency
		end
	end
	local eye = body:FindFirstChild("CockpitEye")
	if cockpit and eye and eye:IsA("Attachment") and not model:GetAttribute("Crashed") then
		local height = CockpitFit.adjust(
			eye.Position.Y,
			(player:GetAttribute("CockpitHeight") :: number?) or 0,
			(eye:GetAttribute("MinHeight") :: number?) or eye.Position.Y,
			(eye:GetAttribute("MaxHeight") :: number?) or eye.Position.Y
		)
		local position = body.CFrame:PointToWorldSpace(Vector3.new(eye.Position.X, height, eye.Position.Z))
		local forward = body.CFrame.LookVector
		-- No delayed position following, and no chassis roll on the horizon.
		local up = if math.abs(forward.Y) < 0.98 then Vector3.yAxis else body.CFrame.UpVector
		camera.CFrame = CFrame.lookAt(position, position + forward * 40, up)
		camera.Focus = camera.CFrame * CFrame.new(0, 0, -40)
		camera.FieldOfView = 72
		cameraPosition = nil
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
	camera.FieldOfView += ((if player:GetAttribute("ReducedMotion")
		then 70
		else 70 + math.min(velocity.Magnitude / 10, 10)) - camera.FieldOfView) * alpha
end)
print("[REDLINE COUNTY] Driving HUD, keyboard/touch controls and chase camera ready.")
