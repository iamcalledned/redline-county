--!strict
local Debris = game:GetService("Debris")
local CrashEffect = {}

function CrashEffect.show(model: Model, body: BasePart)
	local explosion = Instance.new("Explosion")
	explosion.Position = body.Position
	explosion.BlastRadius = 14
	explosion.BlastPressure = 0
	explosion.DestroyJointRadiusPercent = 0
	explosion.ExplosionType = Enum.ExplosionType.NoCraters
	explosion.Parent = workspace
	Debris:AddItem(explosion, 3)
	-- Explicitly destroy only the crashed car; the visual blast never damages bystanders or roads.
	for _, item in model:GetDescendants() do
		if item:IsA("Light") then
			item.Enabled = false
		end
		if item:IsA("BasePart") then
			item.Color = Color3.fromRGB(38, 34, 32)
		end
	end
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat, fire.Parent = 10, 6, body
	local smoke = Instance.new("Smoke")
	smoke.Size, smoke.RiseVelocity, smoke.Opacity, smoke.Parent = 9, 12, 0.6, body
	for i = 1, 6 do
		local fragment = Instance.new("Part")
		fragment.Name, fragment.Size = "CrashFragment", Vector3.new(1.5, 0.5, 2)
		fragment.CFrame = body.CFrame * CFrame.new((i % 3 - 1) * 2, 2, math.floor(i / 3) * 2 - 2)
		fragment.Color = Color3.fromRGB(60, 66, 72)
		fragment.CanCollide, fragment.CanTouch, fragment.CanQuery = false, false, false
		fragment.Parent = workspace
		fragment:SetNetworkOwner(nil)
		fragment.AssemblyLinearVelocity = Vector3.new(math.cos(i) * 25, 25 + i * 3, math.sin(i) * 25)
		Debris:AddItem(fragment, 2)
	end
end

return CrashEffect
