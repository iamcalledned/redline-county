--!strict
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local tracked: { [Model]: { Trail } } = {}
RunService.Heartbeat:Connect(function()
	local folder = workspace:FindFirstChild("Vehicles")
	if not folder then
		return
	end
	for _, model in folder:GetChildren() do
		if
			not model:IsA("Model")
			or model:GetAttribute("OwnerId") ~= player.UserId
			or not model.PrimaryPart
		then
			continue
		end
		local body = model.PrimaryPart
		if not tracked[model] then
			local trails: { Trail } = {}
			local visual = model:FindFirstChild("ImportedCarAppearance")
			for _, side in { "RL", "RR" } do
				local offset = if visual then visual:GetAttribute("Wheel_" .. side) else nil
				local point = if typeof(offset) == "Vector3"
					then Vector3.new(offset.X, -2.2, offset.Z)
					else Vector3.new(
						(if side == "RL" then -1 else 1) * body.Size.X * 0.42,
						-2.2,
						body.Size.Z * 0.34
					)
				local a = Instance.new("Attachment")
				a.Position = point + Vector3.new(-0.25, 0, 0)
				a.Parent = body
				local b = Instance.new("Attachment")
				b.Position = point + Vector3.new(0.25, 0, 0)
				b.Parent = body
				local trail = Instance.new("Trail")
				trail.Attachment0 = a
				trail.Attachment1 = b
				trail.Lifetime = 3
				trail.MinLength = 0.05
				trail.Color = ColorSequence.new(Color3.fromRGB(28, 29, 29))
				trail.Transparency = NumberSequence.new(0.25, 1)
				trail.FaceCamera = false
				trail.Enabled = false
				trail.Parent = body
				table.insert(trails, trail)
			end
			tracked[model] = trails
		end
		local slip = math.abs(body.AssemblyLinearVelocity:Dot(body.CFrame.RightVector)) > 6
		for _, trail in tracked[model] do
			trail.Enabled = model:GetAttribute("Drifting") == true and slip
		end
	end
	for model in tracked do
		if not model.Parent then
			tracked[model] = nil
		end
	end
end)
