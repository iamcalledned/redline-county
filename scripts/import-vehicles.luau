-- Offline importer: lune run scripts/import-vehicles.luau /path/to/downloads
-- Input files: redline-{sport,pickup,sedan,police}.rbxm. No asset code is executed.
local fs = require('@lune/fs')
local rb = require('@lune/roblox')
local process = require('@lune/process')
local V, CF = rb.Vector3, rb.CFrame
local sourceDir = process.args[1] or '/tmp'
for _, spec in {
 {'Sport','sport',6433323089,7,16}, {'Pickup','pickup',6418225759,7.5,20},
 {'Electric','sedan',6418239833,7,17}, {'Police','police',6418230807,7,17},
} do
 local roots=rb.deserializeModel(fs.readFile(sourceDir..'/redline-'..spec[2]..'.rbxm'))
 local source=roots[1]
 local body=assert(source:FindFirstChild('Body'),'Missing visual Body')
 local seat=assert(source:FindFirstChildWhichIsA('VehicleSeat',true),'Missing driver seat')
 local orientation=seat.CFrame.Rotation
 local min,max=V.new(math.huge,math.huge,math.huge),V.new(-math.huge,-math.huge,-math.huge)
 local parts={}
 for _,item in body:GetDescendants() do
  if item:IsA('BasePart') and item.Transparency<1 then
   local cf=orientation:Inverse()*item.CFrame
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    local p=cf*V.new(x*item.Size.X/2,y*item.Size.Y/2,z*item.Size.Z/2)
    min=V.new(math.min(min.X,p.X),math.min(min.Y,p.Y),math.min(min.Z,p.Z))
    max=V.new(math.max(max.X,p.X),math.max(max.Y,p.Y),math.max(max.Z,p.Z))
   end end end
   table.insert(parts,item)
  end
 end
 local size=max-min
 local factor=math.min(spec[4]/size.X,spec[5]/size.Z)
 local origin=V.new((max.X+min.X)/2,min.Y,(max.Z+min.Z)/2)
 local function fitted(cf)
  local localCF=orientation:Inverse()*cf
  return CF.new((localCF.Position-origin)*factor+V.new(0,-2.25,0))*localCF.Rotation
 end
 local visual=rb.Instance.new('Model');visual.Name=spec[1]
 visual:SetAttribute('AppearanceAssetId',spec[3])
 visual:SetAttribute('DriverOffset',fitted(seat.CFrame).Position)
 visual:SetAttribute('VisualHeight',size.Y*factor)
 local corners={}
 for _,name in {'FL','FR','RL','RR'} do
  local group=body:FindFirstChild(name)
  local tire=group and group:FindFirstChild('tire')
  if tire then
   local centre=fitted(tire.CFrame).Position
   visual:SetAttribute('Wheel_'..name,centre)
   visual:SetAttribute('WheelRadius',math.max(tire.Size.Y,tire.Size.Z)*factor/2)
   corners[name]=centre
  end
 end
 for _,item in parts do
  local part=item:Clone();part:ClearAllChildren()
  for _,child in item:GetChildren() do
   if child:IsA('DataModelMesh') or child:IsA('Decal') or child:IsA('SurfaceAppearance') then
    local copy=child:Clone();copy:ClearAllChildren();copy.Parent=part
   end
  end
  local ancestor=item.Parent
  while ancestor and ancestor~=body do
   if corners[ancestor.Name] then part:SetAttribute('WheelCorner',ancestor.Name);break end
   ancestor=ancestor.Parent
  end
  part.CFrame=fitted(item.CFrame);part.Size=item.Size*factor
  part.Anchored=true;part.Massless=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false
  part.CastShadow=true
  if string.find(string.lower(part.Name),'glass',1,true) then part.Transparency=math.max(.65,part.Transparency) end
  part.Parent=visual
 end
 fs.writeFile('assets/vehicles/'..spec[1]..'.rbxmx',rb.serializeModel({visual},true))
 print(spec[1],#parts,'parts','size',size*factor,'seat',visual:GetAttribute('DriverOffset'))
end
