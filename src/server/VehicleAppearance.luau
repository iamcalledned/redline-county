--!strict
-- Import geometry only. Asset scripts, joints, seats and controllers never enter Workspace.
local AssetService = game:GetService("AssetService")
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local ModelFit = require(game:GetService("ReplicatedStorage").Shared.ModelFit)
local Cockpit = require(script.Parent.Cockpit)
local Appearance = {}
local template: Model? = nil
local pending: { [Model]: BasePart } = {}
local failure: string? = nil

local function prepare(source: Model): Model
	local visual = Instance.new("Model")
	visual.Name = "ImportedCarAppearance"
	local seat = source:FindFirstChildWhichIsA("VehicleSeat", true)
	-- Prefer the authored driver seat when a model contains multiple seats.
	for _, item in source:GetDescendants() do
		if item:IsA("VehicleSeat") and (item.Name == "DriveSeat" or item.Name == "DriverSeat") then
			seat = item
			break
		end
	end
	local bounds = source:GetBoundingBox()
	local orientation = if seat then seat.CFrame.Rotation else bounds.Rotation
	orientation *= CFrame.Angles(0, math.rad(Config.DefaultCarAppearance.YawDegrees), 0)
	for _, item in source:GetDescendants() do
		if
			item:IsA("BasePart")
			and not item:IsA("Seat")
			and not item:IsA("VehicleSeat")
			and item.Transparency < 1
		then
			local part = item:Clone() :: BasePart
			part:ClearAllChildren()
			for _, child in item:GetChildren() do
				if child:IsA("DataModelMesh") or child:IsA("Decal") or child:IsA("SurfaceAppearance") then
					local decoration: Instance = (child :: Instance):Clone()
					decoration:ClearAllChildren()
					decoration.Parent = part
				end
			end
			local partName = string.lower(item.Name)
			if
				item.Material == Enum.Material.Glass
				or string.find(partName, "windshield", 1, true)
				or string.find(partName, "windscreen", 1, true)
			then
				part.Transparency = math.max(part.Transparency, 0.65)
			end
			local ancestor: Instance? = item
			while ancestor and ancestor ~= source do
				local name = string.lower(ancestor.Name):gsub("[%s_]", "")
				if string.find(name, "steeringwheel", 1, true) or name == "steer" then
					part.Transparency = 1
				end
				ancestor = ancestor.Parent
			end
			part.CFrame = orientation:Inverse() * item.CFrame
			part.Anchored, part.Massless = true, true
			part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
			part.CollisionGroup = "Cars"
			part.Parent = visual
		end
	end
	assert(#visual:GetChildren() > 0, "Asset contains no visible car parts")
	local originalBox, size = visual:GetBoundingBox()
	-- Fix the pivot explicitly so the seat and all cloned geometry share one transform.
	local pivot = originalBox.Position
	visual.WorldPivot = CFrame.new(pivot)
	assert(size.X > 0 and size.Z > 0, "Asset has invalid bounds")
	local scale =
		math.min(Config.DefaultCarAppearance.Width / size.X, Config.DefaultCarAppearance.Length / size.Z)
	visual:ScaleTo(scale)
	local box, fitted = visual:GetBoundingBox()
	-- Centre on our chassis and align tyre bottoms to the existing suspension geometry.
	local offset = Vector3.new(box.Position.X, box.Position.Y - fitted.Y / 2 + 2, box.Position.Z)
	for _, item in visual:GetChildren() do
		local part = item :: BasePart
		part.CFrame = CFrame.new(-offset) * part.CFrame
	end
	local driver = Vector3.new(-fitted.X * 0.23, 0.4, 0.5)
	if seat then
		local authored = (orientation:Inverse() * seat.CFrame).Position
		driver = Vector3.new(
			ModelFit.coordinate(authored.X, pivot.X, scale, offset.X),
			ModelFit.coordinate(authored.Y, pivot.Y, scale, offset.Y),
			ModelFit.coordinate(authored.Z, pivot.Z, scale, offset.Z)
		)
	end
	visual:SetAttribute("DriverOffset", driver + Config.DefaultCarAppearance.SeatAdjustment)
	visual:SetAttribute("HullSize", Vector3.new(fitted.X * 0.92, 1.1, fitted.Z * 0.96))
	return visual
end

local function apply(model: Model, body: BasePart)
	local ready = template
	if not ready or not model.Parent or not body.Parent or model:GetAttribute("Crashed") then
		return
	end
	local visual = ready:Clone()
	for _, item in visual:GetChildren() do
		local part = item :: BasePart
		part.CFrame = body.CFrame * part.CFrame
		part.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = body, part
		weld.Parent = part
	end
	-- Preserve chassis, native headlight mounts and seat, but hide the placeholder shell.
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") then
			item.Transparency = 1
		end
	end
	visual.Parent = model
	body.Size = visual:GetAttribute("HullSize") :: Vector3
	for _, item in body:GetChildren() do
		if item:IsA("VectorForce") and item.Name == "Suspension" and item.Attachment0 then
			local mount = item.Attachment0
			mount.Position = Vector3.new(
				math.sign(mount.Position.X) * body.Size.X * 0.42,
				0,
				math.sign(mount.Position.Z) * body.Size.Z * 0.34
			)
		end
		if item:IsA("Attachment") and item.Name == "HeadlightMount" then
			item.Position =
				Vector3.new(math.sign(item.Position.X) * body.Size.X * 0.33, 0.2, -body.Size.Z / 2 - 0.17)
		end
	end
	Cockpit.install(model, body, visual:GetAttribute("DriverOffset") :: Vector3)
	model:SetAttribute("AppearanceAssetId", Config.DefaultCarAppearance.AssetId)
	model:SetAttribute("AppearanceStatus", "Loaded")
end

function Appearance.attach(model: Model, body: BasePart, kind: string)
	if kind ~= "Compact" then
		return
	end
	model:SetAttribute("RequestedAppearanceAssetId", Config.DefaultCarAppearance.AssetId)
	if template then
		apply(model, body)
	elseif failure then
		model:SetAttribute("AppearanceStatus", "Failed: " .. failure)
	else
		model:SetAttribute("AppearanceStatus", "Loading")
		pending[model] = body
	end
end

-- One request per server, independent of spawning and driving. A failed load keeps the starter usable.
task.spawn(function()
	local loaded: Instance? = nil
	local ok, result = pcall(function()
		loaded = AssetService:LoadAssetAsync(Config.DefaultCarAppearance.AssetId)
		assert(loaded and loaded:IsA("Model"), "Asset is not a Model")
		return prepare(loaded :: Model)
	end)
	if loaded then
		loaded:Destroy()
	end
	if ok then
		template = result :: Model
	else
		failure = tostring(result)
		warn(
			"Default car asset "
				.. Config.DefaultCarAppearance.AssetId
				.. " could not load: "
				.. tostring(failure)
		)
	end
	for model, body in pending do
		if ok then
			apply(model, body)
		elseif model.Parent then
			model:SetAttribute("AppearanceStatus", "Failed: " .. tostring(failure))
		end
	end
	table.clear(pending)
end)

return Appearance
