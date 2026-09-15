--!strict
-- Reviewed geometry from Roblox's free endorsed vehicle pack, bundled in the place.
local Storage = game:GetService("ServerStorage")
local Cockpit = require(script.Parent.Cockpit)
local Finish = require(script.Parent.VehicleFinish)
local Bundled = {}
export type Wheel = { motor: Motor6D, rest: CFrame, front: boolean }
function Bundled.attach(model: Model, body: Part, key: string, wheels: { Wheel }, driver: boolean): Model?
	local folder = Storage:FindFirstChild("VehicleAssets")
	local template = if folder then folder:FindFirstChild(key) else nil
	if not template or not template:IsA("Model") then
		return nil
	end
	local visual = template:Clone()
	-- Capture chassis-local glass bounds before the visual is moved into the world.
	local glass = visual:FindFirstChild("glass")
	local windowY = if glass and glass:IsA("BasePart") then glass.Position.Y else nil
	local windowHeight = if glass and glass:IsA("BasePart") then glass.Size.Y else nil
	for _, item in model:GetChildren() do
		if item:IsA("BasePart") and item ~= body and item.Name ~= "DriverSeat" then
			item:Destroy()
		end
	end
	body.Transparency = 1
	table.clear(wheels)
	for _, item in visual:GetChildren() do
		if not item:IsA("BasePart") then
			continue
		end
		local rest = item.CFrame
		item.CFrame = body.CFrame * rest
		item.Anchored = false
		item.Massless = true
		item.CanCollide = false
		item.CanTouch = false
		item.CanQuery = false
		local corner = item:GetAttribute("WheelCorner")
		if typeof(corner) == "string" then
			local center = CFrame.new(visual:GetAttribute("Wheel_" .. corner) :: Vector3)
			local motor = Instance.new("Motor6D")
			motor.Part0 = body
			motor.Part1 = item
			motor.C0 = center
			motor.C1 = rest:Inverse() * center
			motor.Parent = item
			table.insert(wheels, { motor = motor, rest = center, front = corner:sub(1, 1) == "F" })
		else
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = body
			weld.Part1 = item
			weld.Parent = item
		end
		if key == "Police" and item.Name == "light_rack_red" then
			item.Name = "PoliceRed"
			item.Material = Enum.Material.Neon
		end
		if key == "Police" and item.Name == "light_rack_blue" then
			item.Name = "PoliceBlue"
			item.Material = Enum.Material.Neon
		end
	end
	visual.Name = "ImportedCarAppearance"
	visual.Parent = model
	Finish.prepare(visual, key == "Police")
	Finish.apply(visual, "Paint", body.Color)
	Finish.apply(visual, "Wheels", Color3.fromRGB(139, 145, 150))
	Finish.apply(visual, "Interior", Color3.fromRGB(42, 43, 45))
	body:GetPropertyChangedSignal("Color"):Connect(function()
		Finish.apply(visual, "Paint", body.Color)
	end)
	local corners = {
		visual:GetAttribute("Wheel_FL"),
		visual:GetAttribute("Wheel_FR"),
		visual:GetAttribute("Wheel_RL"),
		visual:GetAttribute("Wheel_RR"),
	}
	local springs = {}
	for _, item in body:GetChildren() do
		if item:IsA("VectorForce") and item.Name == "Suspension" then
			table.insert(springs, item)
		end
	end
	for i, spring in springs do
		local p = corners[i]
		if typeof(p) == "Vector3" and spring.Attachment0 then
			spring.Attachment0.Position = Vector3.new(p.X, 0, p.Z)
		end
	end
	if driver then
		Cockpit.install(model, body, visual:GetAttribute("DriverOffset") :: Vector3, windowY, windowHeight)
	end
	model:SetAttribute("AppearanceAssetId", visual:GetAttribute("AppearanceAssetId"))
	model:SetAttribute("AppearanceStatus", "Bundled Roblox model")
	model:SetAttribute("BundledVehicle", true)
	return visual
end
return Bundled
