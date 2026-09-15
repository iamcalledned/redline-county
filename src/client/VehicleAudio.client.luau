--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Audio = require(game:GetService("ReplicatedStorage").Shared.AudioCatalog)
local UI = require(script.Parent.Interface)
local player = Players.LocalPlayer
local function sound(parent: Instance, name: string, id: string, loop: boolean, distance: number): Sound
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Looped = loop
	s.Volume = 0
	s.RollOffMode = Enum.RollOffMode.InverseTapered
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = distance
	s.Parent = parent
	return s
end
type Voice = {
	body: BasePart,
	engine: Sound,
	high: Sound,
	skid: Sound,
	impact: Sound,
	siren: Sound,
	damage: number,
	lamps: { BasePart },
}
local voices: { [Model]: Voice } = {}
local dispatch = sound(SoundService, "RedlineDispatch", Audio.Dispatch, false, 0)
local lastCue = 0
player:GetAttributeChangedSignal("MissionMessage"):Connect(function()
	local message = tostring(player:GetAttribute("MissionMessage") or "")
	if
		player:GetAttribute("Wanted")
		and (player:GetAttribute("Wanted") :: number) > 0
		and os.clock() - lastCue > 3
	then
		lastCue = os.clock()
		dispatch.Volume = 0.25 * ((player:GetAttribute("SirenVolume") :: number?) or 0.5)
		dispatch:Play()
		UI.notify(message)
	end
end)
local function destroy(v: Voice)
	for _, s in { v.engine, v.high, v.skid, v.impact, v.siren } do
		s:Destroy()
	end
end
player:GetAttributeChangedSignal("Wanted"):Connect(function()
	if ((player:GetAttribute("Wanted") :: number?) or 0) > 0 and os.clock() - lastCue > 3 then
		lastCue = os.clock()
		dispatch.Volume = 0.25 * ((player:GetAttribute("SirenVolume") :: number?) or 0.5)
		dispatch:Play()
		UI.notify("POLICE ALERTED · Use corners and buildings to break sight.")
	end
end)
local scan, clock = 0, 0
RunService.Heartbeat:Connect(function(dt)
	scan += dt
	clock += dt
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if scan >= 0.5 then
		scan = 0
		local near: { { model: Model, distance: number } } = {}
		for _, name in { "Vehicles", "TownTraffic", "PolicePatrols" } do
			local folder = workspace:FindFirstChild(name)
			if folder then
				for _, m in folder:GetChildren() do
					if m:IsA("Model") and m.PrimaryPart then
						local distance = (m.PrimaryPart.Position - camera.CFrame.Position).Magnitude
						if distance < 550 then
							table.insert(near, { model = m, distance = distance })
						end
					end
				end
			end
		end
		table.sort(near, function(a, b)
			return a.distance < b.distance
		end)
		local keep: { [Model]: boolean } = {}
		for i = 1, math.min(8, #near) do
			keep[near[i].model] = true
		end
		for model, v in voices do
			if not keep[model] then
				destroy(v)
				voices[model] = nil
			end
		end
		for model in keep do
			if not voices[model] and model.PrimaryPart then
				local body = model.PrimaryPart
				local v: Voice = {
					body = body,
					engine = sound(body, "EngineLow", Audio.Engine, true, 200),
					high = sound(body, "EngineHigh", Audio.EngineHigh, true, 200),
					skid = sound(body, "TyreSlip", Audio.Skid, true, 130),
					impact = sound(body, "Impact", Audio.Impact, false, 220),
					siren = sound(body, "Siren", Audio.Siren, true, 550),
					damage = (model:GetAttribute("Damage") :: number?) or 0,
					lamps = {},
				}
				if model:GetAttribute("Police") then
					for _, part in model:GetDescendants() do
						if
							part:IsA("BasePart") and (part.Name == "PoliceRed" or part.Name == "PoliceBlue")
						then
							table.insert(v.lamps, part)
						end
					end
				end
				voices[model] = v
				v.engine:Play()
				v.high:Play()
				v.skid:Play()
			end
		end
	end
	if clock < 0.05 then
		return
	end
	clock = 0
	for model, v in voices do
		if not model.Parent then
			continue
		end
		local speed = math.abs(v.body.AssemblyLinearVelocity:Dot(v.body.CFrame.LookVector))
		local load = math.max(0, (model:GetAttribute("Throttle") :: number?) or 0)
		local localVelocity = v.body.CFrame:VectorToObjectSpace(v.body.AssemblyLinearVelocity)
		local slip = math.abs(math.deg(math.atan2(localVelocity.X, math.max(2, math.abs(localVelocity.Z)))))
		local moving = speed > 1 or model:GetAttribute("OwnerId") == player.UserId
		local rpm = 0.75 + math.min(1.5, speed / 90) + load * 0.16
		v.engine.PlaybackSpeed = rpm
		v.high.PlaybackSpeed = 0.8 + speed / 150
		v.engine.Volume = if moving then 0.12 + 0.14 * load else 0.06
		v.high.Volume = if moving then math.clamp((speed - 25) / 150, 0, 0.23) * (0.4 + 0.6 * load) else 0
		v.skid.Volume = if speed > 16
				and ((model:GetAttribute("GroundedWheels") :: number?) or 0) >= 2
			then math.clamp((slip - 8) / 45, 0, 0.35)
			else 0
		local damage = (model:GetAttribute("Damage") :: number?) or 0
		if damage > v.damage + 1 then
			v.impact.Volume = math.clamp((damage - v.damage) / 50, 0.12, 0.65)
			v.impact:Play()
		end
		v.damage = damage
		local chasing = model:GetAttribute("TargetUserId") ~= nil
		v.siren.Volume = if chasing
			then 0.65 * ((player:GetAttribute("SirenVolume") :: number?) or 0.5)
			else 0
		if chasing and not v.siren.IsPlaying then
			v.siren:Play()
		elseif not chasing and v.siren.IsPlaying then
			v.siren:Stop()
		end
		for _, lamp in v.lamps do
			lamp.Transparency = if not chasing
				then 0.5
				elseif player:GetAttribute("ReducedFlashing") then 0
				elseif (math.floor(os.clock() * 3) % 2 == 0) == (lamp.Name == "PoliceRed") then 0
				else 0.8
		end
	end
end)
