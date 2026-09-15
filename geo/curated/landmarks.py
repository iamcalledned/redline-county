"""Hand-authored landmark/garage recipe. Geography regeneration never writes this file."""
from bake_hopedale import Bake,world,S,Y,math,Polygon,LineString,unary_union,ROOT

from scenery import landmarks,display_asset

def bake(c,g,output_root=ROOT):
 b=Bake('HopedaleLandmarks');nodes=g['nodes'];hall=next(v for v in g['buildings'] if v['id']==c['town_hall_way']);poly=Polygon(hall['points']);center=poly.centroid
 street=unary_union([LineString([nodes[a],nodes[d]]) for r in g['roads'] if r['name']=='Hopedale Street' for a,d in r['segments']]);near=street.interpolate(street.project(center));dx,dn=near.x-center.x,near.y-center.y;yaw=math.atan2(-dx,dn)
 # Front faces the nearest Hopedale Street frontage; 23.2 x 21.4m footprint from OSM.
 town=b.model(b.top,'HistoricTownHall');w,depth=23.2,21.4
 def pos(x,y,z):
  # local front is -Z. Inputs are metres, origin at the mapped footprint centre.
  return world((center.x+math.cos(yaw)*x+math.sin(yaw)*z,center.y+math.sin(yaw)*x-math.cos(yaw)*z),y)
 def part(name,x,y,z,sx,sy,sz,col,angle=0,cls='Part'):
  if name in ['EntryDoor','EntryLeftJamb','EntryRightJamb','ArchStone','Shopfront','EntranceSteps','ArchShadow']:x=-x
  return b.part(town,name,pos(x,y,z),(sx/S,sy/S,sz/S),col,yaw+angle,cls=cls,collide=name in ['StoneBody','EntranceSteps'],material=832 if name=='StoneBody' else 256)
 stone=(.63,.60,.51);sand=(.46,.29,.23);slate=(.24,.27,.28);glass=(.19,.26,.29)
 part('StoneBody',0,5.2,0,w,10.4,depth,stone)
 for y in [.4,4.3,5.4,10.1]:part('SandstoneBand',0,y,-depth/2-.08,w+.12,.22,.18,sand)
 # Reference: broad low hipped roof with a central street-facing gable, paired chimneys.
 part('Roof',0,10.6,0,w+1,.35,depth+1,slate)
 for side in [-1,1]:
  slope=side*math.atan2(2.8,depth/2);ca,sa=math.cos(yaw),math.sin(yaw);cr,sr=math.cos(slope),math.sin(slope)
  rot=((ca,sa*sr,sa*cr),(0,cr,-sr),(-sa,ca*sr,ca*cr))
  b.part(town,'SlateRoofSlope',pos(0,11.8,side*depth/4),((w+1)/S,.28/S,math.hypot(depth/2,2.8)/S+1),slate,rot=rot,collide=False)
 part('CentralGable',-1.75,12.6,-depth/2-.7,.8,4.4,3.5,stone,math.pi/2,'WedgePart');part('CentralGable',1.75,12.6,-depth/2-.7,.8,4.4,3.5,stone,-math.pi/2,'WedgePart')
 for x in [-4,4]:part('Chimney',x,13.1,-2,.7,4,.8,stone)
 for x in [-10.9,-6.4,-3.7,3.7,6.4,10.9]:part('RusticatedTrim',x,7.2,-depth/2-.13,.26,5.6,.25,sand)
 for x in [-9,-6.8,-1.2,1.2,6.8,9]:
  part('UpperWindowTrim',x,7.3,-depth/2-.2,1.6,4,.23,sand)
  part('UpperWindow',x,7.3,-depth/2-.34,1.22,3.6,.08,glass)
  part('Sash',x,7.2,-depth/2-.4,1.22,.10,.09,stone)
 for x in [-1.1,1.1]:part('GableWindow',x,11.4,-depth/2-1.16,1,1.7,.12,glass)
 # Large arched entry on the right; shopfront rhythm below the central/left windows.
 for x in [-9,-6.4,-2.8,0,2.4]:part('Shopfront',x,2.05,-depth/2-.17,2.15,3.35,.12,glass)
 shadow=part('ArchShadow',6,3.2,-depth/2-.2,.12,2.6,2.6,(.18,.15,.12),math.pi/2);b.prop(shadow,'token','shape',2)
 part('EntryDoor',6,1.7,-depth/2-.19,2.6,3.4,.15,(.18,.15,.12))
 part('EntryLeftJamb',4.4,1.6,-depth/2-.27,.42,3.2,.45,sand);part('EntryRightJamb',7.6,1.6,-depth/2-.27,.42,3.2,.45,sand)
 for i in range(17):
  a=math.pi*i/16;part('ArchStone',6+1.6*math.cos(a),3.2+1.6*math.sin(a),-depth/2-.29,.47,.42,.45,sand)
 for x in [-1.2,1.2]:
  for i in range(9):
   a=math.pi*i/8;part('UpperArch',x+.9*math.cos(a),9.1+.9*math.sin(a),-depth/2-.29,.33,.33,.25,sand)
 b.sign(town,'HOPEDALE TOWN HALL',pos(0,4.7,-depth/2-.3),(8/S,.42/S,.10/S),yaw,color=stone)
 b.sign(town,'HISTORIC TOWN HALL · 78 HOPEDALE ST\nReference-based exterior; proportions approximate',pos(0,1,-depth/2-3),(15,3,.2),yaw)
 # Ground-level arrival apron; avoid stairs in the street's collision surface.
 part('EntranceSteps',6,.10,-depth/2-1.1,4,.2,2,stone)
 # Fictional property, with fixed dimensions and door clearance documented in metres.
 home=b.model(b.top,'HomeBase');cx,cn=g['garage']['center'];base=world((cx,cn-8));roof=(.20,.24,.25);clap=(.57,.62,.60);trim=(.91,.87,.76)
 def hp(name,x,y,z,sx,sy,sz,col=clap,collide=True):return b.part(home,name,(base[0]+x,Y+y,base[2]+z),(sx,sy,sz),col,collide=collide)
 hp('GarageFloor',0,-.12,0,82,.24,46,(.43,.43,.40))
 hp('BackWall',0,10,23,82,20,1.4);hp('WestWall',-41,10,0,1.4,20,46);hp('EastWall',41,10,0,1.4,20,46)
 hp('Header',0,19,-23,82,4,1.4,trim)
 for x in [-41,-13.7,13.7,41]:hp('DoorPier',x,9,-23,1.5,18,1.4,trim)
 hp('Roof',0,21,0,87,2,51,roof)
 for side in [-1,1]:
  angle=side*math.atan2(7,25.5);rot=((1,0,0),(0,math.cos(angle),-math.sin(angle)),(0,math.sin(angle),math.cos(angle)))
  b.part(home,'GabledRoof',(base[0],Y+24.5,base[2]+side*12.75),(87,.7,math.hypot(25.5,7)),roof,rot=rot,collide=False)
 for x in [-27,0,27]:
  hp('Door_'+str(int(x)),x,8.5,-23,24,17,.65,(.77,.78,.71))
  # Door buttons stay on the fixed jamb, not the moving panel.
  hp('DoorButton_'+str(int(x)),x+12.4,4.5,-24,.65,1,.4,(.24,.42,.37),False)
  lamp=hp('InteriorLamp',x,18,0,10,.3,2,(.95,.88,.66),False)
  light=b.item(lamp,'PointLight','WarmLight');b.prop(light,'float','Range',35);b.prop(light,'float','Brightness',1.4);b.prop(light,'bool','Shadows',False)
  for yy in [4,8,12]:hp('DoorWindow_'+str(int(x)),x,yy,-23.4,20,.15,.10,trim,False)
 b.sign(home,'REDLINE WORKSHOP\nFICTIONAL PLAYER HOME', (base[0],Y+19,base[2]-24),(33,4,.3))
 # Furnished walkable back strip; bays have clear access down either side.
 hp('Workbench',-26,3,18,22,1,5,(.42,.31,.19));hp('ToolCabinet',-38,4,17,4,8,6,(.41,.17,.13));hp('Pegboard',-25,8,22,20,6,.3,(.48,.39,.28),False)
 for x in range(-32,-17,3):hp('Tool',x,8,21.6,.4,3,.4,(.22,.24,.25),False)
 hp('Sofa',26,2.5,17,18,3,5,(.22,.34,.33));hp('SofaBack',26,5,20,18,4,1,(.22,.34,.33));hp('PlanningTable',7,2.6,17,8,.6,5,(.56,.43,.29))
 b.sign(home,'HOPEDALE CENTER\nTown Hall loop · 917 m\nOSM contributors / ODbL 1.0', (base[0]+7,Y+10,base[2]+22),(16,7,.2),math.pi)
 # Clear side aisles, with six studs behind each arrival for the walking camera.
 # Runtime uses these baked markers too, so spawn coordinates cannot drift from the room.
 for i,(x,z) in enumerate([(-13.5,6),(13.5,6),(35,0)],1):
  arrival=hp('Arrival_'+str(i),x,4,z,.5,.5,.5,(1,1,1),False);arrival.find("Properties/float[@name='Transparency']").text='1'
 spawn=hp('HomeSpawn',-13.5,.3,6,5,.6,5,(.56,.62,.48),False);spawn.set('class','SpawnLocation');b.prop(spawn,'bool','Neutral',True);b.prop(spawn,'float','Duration',0);spawn.find("Properties/float[@name='Transparency']").text='1'
 # Collection displays stay anchored and contain no driving/ownership logic.
 for x,kind,length,width,color in [(-27,'Pickup',20,7.5,(.42,.51,.46)),(0,'Electric',17,7,(.75,.76,.71)),(27,'Sport',16,7,(.65,.25,.16))]:
  display=b.model(home,'Display_'+kind);loc=(base[0]+x,Y+2.3,base[2]+2)
  display_asset(b,display,kind,loc)
  b.sign(display,{'Pickup':'PICKUP TRUCK','Electric':'ELECTRIC SEDAN','Sport':'SPORTS COUPE'}[kind]+'\nSELECT · FREE ROBLOX VEHICLE', (loc[0],Y+9,loc[2]-length/2-1),(21,3,.25))
  marker=hp('Select_'+kind,x+width/2+2.5,3,2,1,1,1,(.18,.42,.34),False)
 for x in [-34,34]:
  hp('GardenTreeTrunk',x,6,35,1.2,12,1.2,(.34,.27,.19))
  canopy=hp('GardenTreeCanopy',x,15,35,14,16,14,(.29,.40,.24),False);b.prop(canopy,'token','shape',0)
 # Static diagnostic lane away from roads, adjacent to the fictional driveway apron.
 b.sign(home,'GARAGE ACCESS\nFictional private drive',world(g['garage']['road'],2),(13,4,.4))
 landmarks(b,c,g)
 b.save(output_root/'assets/generated/HopedaleLandmarks.rbxmx')
 return b.count
