--!strict
local Materials = require(game:GetService("ReplicatedStorage").Shared.VehicleMaterials)
local Finish = {}
function Finish.prepare(visual: Model, police: boolean)
	for _, part in visual:GetDescendants() do
		if not part:IsA("BasePart") then
			continue
		end
		local slot = Materials.slot(part.Name)
		if slot and not (police and slot == "Paint") then
			part:SetAttribute("FinishSlot", slot)
			if part:IsA("MeshPart") then
				part.TextureID = ""
			end
			for _, child in part:GetChildren() do
				if child:IsA("SurfaceAppearance") or child:IsA("Decal") then
					-- Imported livery must not mask the selected finish. Map setters are plugin-only.
					child:Destroy()
				end
			end
			part.Material = if slot == "Interior" then Enum.Material.Fabric else Enum.Material.SmoothPlastic
			part.Reflectance = if slot == "Paint" then 0.12 elseif slot == "Wheels" then 0.2 else 0
		end
	end
end
function Finish.apply(model: Model, slot: string, color: Color3)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("FinishSlot") == slot then
			part.Color = color
		end
	end
	model:SetAttribute("Finish_" .. slot, color)
end
return Finish
