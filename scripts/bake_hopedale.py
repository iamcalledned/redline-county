"""Editor-visible bake. Writes only assets/generated and geo/generated; curated code is read-only."""
from hopedale_geo import *
from shapely import constrained_delaunay_triangles
import random
S=.28;Y=32

def sub(a,b):return tuple(x-y for x,y in zip(a,b))
def add(a,b):return tuple(x+y for x,y in zip(a,b))
def mul(a,s):return tuple(x*s for x in a)
def dot(a,b):return sum(x*y for x,y in zip(a,b))
def cross(a,b):return(a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
def unit(a):return mul(a,1/math.sqrt(dot(a,a)))
def world(p,h=0):return(p[0]/S,Y+h/S,-p[1]/S)
class Bake:
 def __init__(self,name):
  self.root=ET.Element('roblox',{'version':'4'});self.top=self.item(self.root,'Model',name);self.count=0
 def prop(self,item,typ,name,value):
  props=item.find('Properties');e=ET.SubElement(props,typ,{'name':name})
  if typ in ['Vector3','Color3']:
   for n,v in zip(['X','Y','Z'] if typ=='Vector3' else ['R','G','B'],value):ET.SubElement(e,n).text=f'{v:.6f}'
  elif typ=='CoordinateFrame':
   pos,rot=value
   for n,v in zip(['X','Y','Z'],pos):ET.SubElement(e,n).text=f'{v:.6f}'
   for i in range(3):
    for j in range(3):ET.SubElement(e,f'R{i}{j}').text=f'{rot[i][j]:.8f}'
  elif typ=='UDim2':
   for n,v in zip(['XS','XO','YS','YO'],value):ET.SubElement(e,n).text=str(v)
  else:e.text=str(value).lower() if isinstance(value,bool) else str(value)
 def item(self,parent,cls,name):
  i=ET.SubElement(parent,'Item',{'class':cls});ET.SubElement(i,'Properties');self.prop(i,'string','Name',name);return i
 def model(self,parent,name,atomic=True):
  m=self.item(parent,'Model',name)
  if atomic:self.prop(m,'token','ModelStreamingMode',1)
  return m
 def part(self,parent,name,pos,size,color=(.4,.4,.4),yaw=0,rot=None,collide=True,material=256,cls='Part',trans=0):
  self.count+=1;p=self.item(parent,cls,name)
  if rot is None:rot=((math.cos(yaw),0,math.sin(yaw)),(0,1,0),(-math.sin(yaw),0,math.cos(yaw)))
  for typ,key,val in [('Vector3','size',size),('CoordinateFrame','CFrame',(pos,rot)),('Color3','Color',color),('bool','Anchored',True),('bool','CanCollide',collide),('bool','CanTouch',False),('bool','CanQuery',collide),('token','Material',material),('float','Transparency',trans),('token','TopSurface',0),('token','BottomSurface',0)]:self.prop(p,typ,key,val)
  return p
 def sign(self,parent,text,pos,size,yaw=0,color=(.12,.23,.23)):
  p=self.part(parent,'Sign',pos,size,color,yaw,collide=False)
  gui=self.item(p,'SurfaceGui','Lettering');self.prop(gui,'token','Face',5);self.prop(gui,'float','PixelsPerStud',35)
  lab=self.item(gui,'TextLabel','Text');self.prop(lab,'UDim2','Size',(1,0,1,0));self.prop(lab,'float','BackgroundTransparency',1);self.prop(lab,'string','Text',text);self.prop(lab,'bool','TextScaled',True);self.prop(lab,'bool','TextWrapped',True);self.prop(lab,'Color3','TextColor3',(.96,.93,.8));self.prop(lab,'token','Font',19)
  return p
 def line(self,parent,name,a,b,width,height,color,ground=0,collide=False):
  dx,dy=b[0]-a[0],b[1]-a[1];l=math.hypot(dx,dy)
  return self.part(parent,name,world(((a[0]+b[0])/2,(a[1]+b[1])/2),ground), (width/S,height/S,l/S),color,math.atan2(-dx,dy),collide=collide)
 def fill(self,parent,poly,color,ground):
  triangles=list(constrained_delaunay_triangles(poly).geoms)
  assert poly.symmetric_difference(unary_union(triangles)).area < 1e-5, 'Road surface triangulation left a gap'
  for t in triangles:
   if not poly.covers(t.representative_point()):continue
   # Clip exterior Delaunay triangles to preserve holes/curb cuts.
   if not poly.covers(t):continue
   pts=[world(v,ground) for v in list(t.exterior.coords)[:3]]
   a,b,c=max(((pts[0],pts[1],pts[2]),(pts[1],pts[2],pts[0]),(pts[2],pts[0],pts[1])),key=lambda p:dot(sub(p[1],p[0]),sub(p[1],p[0])))
   ab=sub(b,a);foot=add(a,mul(ab,dot(sub(c,a),ab)/dot(ab,ab)));up=sub(c,foot);height=math.sqrt(dot(up,up))
   if height<.01:continue
   up=unit(up)
   for end in [a,b]:
    vec=sub(foot,end);depth=math.sqrt(dot(vec,vec))
    if depth<.01:continue
    back=unit(vec);right=cross(up,back);rot=tuple(zip(right,up,back))
    self.part(parent,'Surface',mul(add(end,c),.5),(.10,height,depth),color,rot=rot,collide=False,cls='WedgePart')
 def save(self,path):
  ET.indent(self.root);ET.ElementTree(self.root).write(path,encoding='utf-8',xml_declaration=True)

def build(output_root=ROOT):
 c,g=load();nodes=g['nodes'];b=Bake('HopedaleGenerated');area=box(*g['play_bounds'])
 ground=b.model(b.top,'LevelTerrain_Provisional',False)
 x0,y0,x1,y1=g['play_bounds']
 cx,cy=g['garage']['center'];home_floor=box(cx-41*S,cy-8-23*S,cx+41*S,cy-8+23*S)
 xs=sorted(set(list(range(int(x0),int(x1),64))+[x1,home_floor.bounds[0],home_floor.bounds[2]]))
 ys=sorted(set(list(range(int(y0),int(y1),64))+[y1,home_floor.bounds[1],home_floor.bounds[3]]))
 for x,xx in zip(xs,xs[1:]):
  for n,nn in zip(ys,ys[1:]):
   if home_floor.covers(Point((x+xx)/2,(n+nn)/2)):continue
   b.part(ground,'GroundTile',world(((x+xx)/2,(n+nn)/2),-.28),((xx-x)/S,2,(nn-n)/S),(.36,.44,.26),material=1280)
 roads=b.model(b.top,'Roads',False)
 lines=[LineString([nodes[a],nodes[d]]) for r in g['roads'] for a,d in r['segments']]
 surface=unary_union([LineString([nodes[a],nodes[d]]).buffer(r['tags'].get('half_width',6) if r['tags'].get('fictional') else 3.6,quad_segs=2) for r in g['roads'] for a,d in r['segments']]).simplify(.18)
 garage=g['garage'];drive=LineString([garage['center'],garage['road']]).buffer(3.8,quad_segs=2)
 apron=box(garage['center'][0]-18,garage['center'][1]-8,garage['center'][0]+18,garage['center'][1]+17)
 surface=unary_union([surface,drive,apron]).intersection(area).difference(home_floor)
 sidewalk=unary_union([l.buffer(5.3,quad_segs=2) for l in lines]).difference(surface).intersection(area).difference(home_floor)
 # Split meshes into tile-sized atomic groups for streaming and bounded draw cost.
 for x in range(int(x0),int(x1),80):
  for n in range(int(y0),int(y1),80):
   tile=box(x,n,x+80,n+80);m=b.model(roads,f'Tile_{x}_{n}')
   for geom,col,h in [(surface,(.17,.19,.20),.018),(sidewalk,(.63,.61,.55),.035)]:
    cut=geom.intersection(tile);polys=list(cut.geoms) if hasattr(cut,'geoms') else [cut]
    for p in polys:
     if p.geom_type=='Polygon':b.fill(m,p,col,h)
 # Mapped shoreline and walk-only Parklands paths. The datum remains provisional.
 water=b.model(b.top,'HopedalePond',False)
 water_polys=[Polygon(v['points'],v['holes']) for v in g['water']]
 for poly in water_polys:
  cut=poly.difference(surface.buffer(.5))
  for piece in (list(cut.geoms) if hasattr(cut,'geoms') else [cut]):
   if piece.geom_type=='Polygon':b.fill(water,piece.simplify(.5),(.17,.36,.39),.10)
 paths=b.model(b.top,'ParklandsPaths',False)
 for data in g['paths']:
  path=LineString(data['points']).intersection(area).difference(surface)
  for line in (list(path.geoms) if hasattr(path,'geoms') else [path]):
   if line.geom_type!='LineString':continue
   pts=list(line.simplify(.8).coords)
   for a,d in zip(pts,pts[1:]):
    if math.dist(a,d)>.3:b.line(paths,'Footpath',a,d,1.5,.08,(.66,.58,.43),.15)
 # Freedom Street bridge is explicitly curated, with a continuous flat road deck.
 bridge=b.model(b.top,'FreedomStreetBridge')
 a,d=(-413.0199743,443.5378707),(-388.4905122,458.8307352)
 dx,dn=d[0]-a[0],d[1]-a[1];length=math.hypot(dx,dn)
 b.line(bridge,'BridgeDeck',a,d,10,.3,(.48,.48,.44),-.15,True)
 for side in [-1,1]:
  offset=(dn/length*4.8*side,-dx/length*4.8*side)
  aa=(a[0]+offset[0],a[1]+offset[1]);dd=(d[0]+offset[0],d[1]+offset[1])
  b.line(bridge,'StoneParapet',aa,dd,.45,1,(.56,.56,.50),.5,True)
 junctionpts=[Point(nodes[n]) for n in g['junctions']]
 for road in g['roads']:
  m=b.model(roads,road['name']+' markings')
  for a,d in road['segments']:
   ln=LineString([nodes[a],nodes[d]])
   for dist in range(0,int(ln.length),9):
    p=ln.interpolate(dist);q=ln.interpolate(min(dist+3,ln.length))
    if p.distance(q)>.4 and all(p.distance(j)>9 for j in junctionpts):b.line(m,'Centerline',(p.x,p.y),(q.x,q.y),.12,.02,(.88,.70,.31),.05)
 for n in g['junctions']:
  pt=nodes[n];near=[r['name'] for r in g['roads'] if any(n in seg for seg in r['segments'])];name=' / '.join(dict.fromkeys(near));m=b.model(roads,'Junction_'+str(n))
  candidates=[(pt[0]+math.cos(angle)*8,pt[1]+math.sin(angle)*8) for angle in [i*math.pi/8 for i in range(16)]]
  post=max(candidates,key=lambda v:Point(v).distance(surface))
  b.part(m,'StreetPost',world(post,1.5),(.4,3/S,.4),(.23,.26,.25));b.sign(m,name,world(post,3),(13,2.5,.25))
  # Navigation crossings are design annotations, not claims of surveyed paint/sign placement.
  if n in c['route_nodes']:
   b.sign(m,'TOWN LOOP',world((pt[0]-6,pt[1]-6),2),(8,2,.25),color=(.46,.24,.09))
 # Zebra placement follows tagged OSM crossing nodes; marking dimensions are provisional.
 for n in g['crossings']:
  p=Point(nodes[n]);ln=min(lines,key=lambda l:l.distance(p))
  if ln.distance(p)>5:continue
  a,d=list(ln.coords)[0],list(ln.coords)[-1];dx,dn=d[0]-a[0],d[1]-a[1];length=math.hypot(dx,dn);dx/=length;dn/=length
  m=b.model(roads,'Crosswalk_'+str(n))
  for offset in [-3,-2.4,-1.8,-1.2,-.6,0,.6,1.2,1.8,2.4,3]:
   x,y=nodes[n][0]+dn*offset,nodes[n][1]-dx*offset
   b.line(m,'Zebra',(x-dx,y-dn),(x+dx,y+dn),.35,.015,(.90,.89,.81),.055)
 # Mark the full closed loop on the road, with directional chevrons visible from a car.
 guide=b.model(roads,'GetawayLoopGuide',False)
 for a,d in zip(g['route'],g['route'][1:]):
  ln=LineString([nodes[a],nodes[d]]);dx=nodes[d][0]-nodes[a][0];dn=nodes[d][1]-nodes[a][1];length=ln.length
  ux,un=dx/length,dn/length
  for distance in range(4,int(length),18):
   pt=ln.interpolate(distance);tip=(pt.x+ux*1.5+un,pt.y+un*1.5-ux)
   for side in [-1,1]:
    tail=(tip[0]-ux*2+un*.8*side,tip[1]-un*2-ux*.8*side)
    b.line(guide,'LoopChevron',tail,tip,.18,.018,(.20,.84,.71),.075)
 # Course entry and repeated lap/direction signs use original game geography.
 circuit=b.model(b.top,'ParkwayGuide',False)
 for i in range(0,96,12):
  pt=nodes[g['course'][i]];q=nodes[g['course'][(i+1)%96]]
  dx,dn=q[0]-pt[0],q[1]-pt[1];ll=math.hypot(dx,dn)
  site=(pt[0]+dn/ll*9,pt[1]-dx/ll*9)
  lamp=b.part(circuit,'CourseLantern',world(site,5),(2,1,2),(.92,.85,.65),collide=False,material=288)
  light=b.item(lamp,'PointLight','MapLamp');b.prop(light,'float','Range',65);b.prop(light,'float','Brightness',1.5);b.prop(light,'bool','Shadows',False);b.prop(light,'bool','Enabled',False)
  b.sign(circuit,'REDLINE PARKWAY\nCONTINUOUS CIRCUIT',world(site,2.8),(28,6,.3),math.atan2(-dx,dn))
 b.sign(circuit,'PARKWAY CIRCUIT →\nWide bends · traffic · lap runs',world((410,142),2.5),(32,6,.3))
 # Unfinished exits have solid, advance-visible road closures, not an open drop.
 ends={}
 for r in g['roads']:
  for a,d in r['segments']:
   ends.setdefault(a,set()).add(d);ends.setdefault(d,set()).add(a)
 for n,links in ends.items():
  if len(links)==1:
   p=nodes[n];neighbor=nodes[next(iter(links))];dx,dn=p[0]-neighbor[0],p[1]-neighbor[1];length=math.hypot(dx,dn);ux,un=dx/length,dn/length
   m=b.model(roads,'RoadClosure_'+str(n));q=(p[0]-ux*2,p[1]-un*2);yaw=math.atan2(-ux,un)
   b.part(m,'ClosureBarrier',world(q,.7),(8.5/S,1.4/S,.6/S),(.85,.42,.12),yaw)
   b.sign(m,'ROAD CLOSED\nTURN BACK TO TOWN',world((q[0]-ux*.5,q[1]-un*.5),2.2),(25,5,.3),yaw,color=(.35,.19,.08))
   for side in [-1,1]:
    b.part(m,'WarningBeacon',world((q[0]+un*side*3.5,q[1]-ux*side*3.5),1.6),(1,1,1),(.98,.57,.12),collide=False,material=288)
 # Perimeter fence prevents driving off the finite terrain; all route streets stay inside.
 fence=b.model(b.top,'DistrictBoundary',False)
 for x in [x0+.4,x1-.4]:b.part(fence,'BoundaryFence',world((x,(y0+y1)/2),1.2),(.4/S,2.4/S,(y1-y0)/S),(.30,.35,.33))
 for y in [y0+.4,y1-.4]:b.part(fence,'BoundaryFence',world(((x0+x1)/2,y),1.2),((x1-x0)/S,2.4/S,.4/S),(.30,.35,.33))
 # Footprint-aligned generic shells. Facade/height are intentionally not survey claims.
 scenery=b.model(b.top,'FootprintBuildings',False)
 detailed_ids={d['id'] for d in sorted(g['buildings'],key=lambda d:Polygon(d['points']).distance(Point(0,100)))[:18]}
 for data in g['buildings']:
  if data['id'] in [c['town_hall_way']]+c['landmark_ways']:continue
  poly=Polygon(data['points']);rect=list(poly.minimum_rotated_rectangle.exterior.coords);a,d=rect[0],rect[1];w=math.dist(a,d);depth=math.dist(d,rect[2]);center=poly.minimum_rotated_rectangle.centroid;angle=math.atan2(-(d[0]-a[0]),d[1]-a[1])+math.pi/2
  m=b.model(scenery,'OSM_'+str(data['id']));rng=random.Random(data['id']);height=6.2 if poly.area<220 else 8
  col=rng.choice([(.72,.69,.61),(.66,.69,.65),(.61,.64,.62),(.65,.46,.37)])
  b.part(m,'Shell',world((center.x,center.y),height/2),(w/S,height/S,depth/S),col,angle,material=512)
  b.part(m,'Roof',world((center.x,center.y),height+.3),((w+.8)/S,.8/S,(depth+.8)/S),(.22,.25,.26),angle,collide=False,material=816)
  # Reusable two-plane gable roof, kept separate from the simple collision shell.
  rise=min(2.6,depth*.25);slope=math.atan2(rise,depth/2)
  for side in [-1,1]:
   z=side*depth/4;roofpos=world((center.x+math.sin(angle)*z,center.y-math.cos(angle)*z),height+rise/2)
   ca,sa=math.cos(angle),math.sin(angle);cr,sr=math.cos(side*slope),math.sin(side*slope)
   rot=((ca,sa*sr,sa*cr),(0,cr,-sr),(-sa,ca*sr,ca*cr))
   b.part(m,'RoofSlope',roofpos,((w+1)/S,.25/S,math.hypot(depth/2,rise)/S+.8),(.23,.25,.26),rot=rot,collide=False)
  # Generic facade rhythm is curated, not inferred from footprint/height data.
  if poly.distance(surface)<50:
   for u in [-.27,.27]:
    for level in [.37,.75]:
     x=u*w;z=-depth/2-.06;wp=world((center.x+math.cos(angle)*x+math.sin(angle)*z,center.y+math.sin(angle)*x-math.cos(angle)*z),height*level)
     b.part(m,'WindowTrim',wp,(1.3/S,1.65/S,.12/S),(.86,.83,.75),angle,collide=False)
     gp=(wp[0]-math.sin(angle)*.25,wp[1],wp[2]-math.cos(angle)*.25)
     b.part(m,'Window',gp,(1.05/S,1.4/S,.12/S),(.22,.30,.33),angle,collide=False)
  if data['id'] in detailed_ids:
   def facade(x,h,z,name,size,col):
    return b.part(m,name,world((center.x+math.cos(angle)*x+math.sin(angle)*z,center.y+math.sin(angle)*x-math.cos(angle)*z),h),tuple(v/S for v in size),col,angle,collide=False)
   for side in [-1,1]:
    z=side*(depth/2+.09)
    facade(0,1.25,z,'EntryDoor',(1.05,2.3,.16),(.27,.25,.20))
    facade(0,2.6,z,'DoorCanopy',(1.8,.2,1),(.81,.78,.67))
    for x in [-w/2+.1,w/2-.1]:facade(x,height/2,z,'CornerBoard',(.18,height,.18),(.86,.83,.75))
    for x in [-w*.27,w*.27]:
     for level in [.37,.75]:
      facade(x,height*level,z+side*.13,'WindowSash',(1.2,.09,.1),(.86,.83,.75))
      for edge in [-.8,.8]:facade(x+edge,height*level,z,'Shutter',(.3,1.65,.14),(.25,.32,.30))
   facade(w*.3,height+rise,depth*.2,'BrickChimney',(.6,2,.65),(.43,.27,.23))
  if data['tags'].get('name'):b.sign(m,data['tags']['name']+'\nApproximate facade',world((center.x,center.y),height+2),(min(w/S,45),4,.3),angle)
 # Trees only within mapped green areas, not invented private-property boundaries.
 foliage=b.model(b.top,'MappedGreenery',False);rng=random.Random(842)
 blocked=surface.buffer(2).union(unary_union([Polygon(d['points']) for d in g['buildings']])).union(box(*garage['reserve'])).union(unary_union(water_polys))
 for green in g['greenery']:
  p=Polygon(green['points']).intersection(area)
  if green['tags'].get('natural')=='water':continue
  if p.is_empty:continue
  gx,gy,xx,yy=p.bounds
  for _ in range(min(55,int(p.area/150))):
   v=(rng.uniform(gx,xx),rng.uniform(gy,yy));pt=Point(v)
   if not p.contains(pt) or blocked.intersects(pt):continue
   m=b.model(foliage,'Tree');b.part(m,'Trunk',world(v,2),(.9,4/S,.9),(.30,.24,.17))
   for dx,dn,h in [(-1,0,4),(1,.7,4.5),(0,-.3,6)]:
    can=b.part(m,'Canopy',world((v[0]+dx,v[1]+dn),h),(4/S,4.5/S,4/S),rng.choice([(.27,.39,.24),(.33,.43,.23),(.25,.36,.27)]),collide=False);b.prop(can,'token','shape',0)
 # Authored landscaping for the fictional parkway, kept outside its clear verge.
 parkway_green=b.model(b.top,'ParkwayLandscaping',False)
 for i in range(0,96,2):
  pt=nodes[g['course'][i]];q=nodes[g['course'][(i+1)%96]]
  dx,dn=q[0]-pt[0],q[1]-pt[1];length=math.hypot(dx,dn)
  off=(20+(i%5)*3)*(1 if i%4==0 else -1)
  site=(pt[0]+dn/length*off,pt[1]-dx/length*off)
  if not area.contains(Point(site).buffer(4)) or blocked.intersects(Point(site).buffer(3)):continue
  m=b.model(parkway_green,'ParkwayTree');height=5+(i%4)
  b.part(m,'Trunk',world(site,height/3),(1.6,height/S,1.6),(.29,.23,.16))
  for shift,h in [(-1,height),(1,height+1.5)]:
   canopy=b.part(m,'Canopy',world((site[0]+shift,site[1]),h),(6/S,5/S,5/S),(.24+.01*(i%5),.36,.23),collide=False)
   b.prop(canopy,'token','shape',0)
 # Sparse street lamps: curated generic street furniture rather than surveyed pole locations.
 poles=b.model(b.top,'StreetFurniture',False)
 for r in g['roads']:
  for a,d in r['segments']:
   ln=LineString([nodes[a],nodes[d]])
   if ln.length<30:continue
   p=ln.interpolate(.5,normalized=True);dx,dn=nodes[d][0]-nodes[a][0],nodes[d][1]-nodes[a][1];verge=r['tags'].get('half_width',6)+2 if r['tags'].get('fictional') else 5.6;offset=(dn/ln.length*verge,-dx/ln.length*verge);site=(p.x+offset[0],p.y+offset[1]);m=b.model(poles,'Lamp');b.part(m,'Pole',world(site,3),(.7,6/S,.7),(.20,.22,.21));lamp=b.part(m,'Lantern',world(site,6),(2,1.3,2),(.92,.83,.56),collide=False,material=288)
   light=b.item(lamp,'PointLight','MapLamp');b.prop(light,'float','Range',50);b.prop(light,'float','Brightness',1.2);b.prop(light,'bool','Shadows',False);b.prop(light,'bool','Enabled',False)
 # Fictional mill yard: strong silhouettes and sight-breaking cover, modest part budget.
 mill=b.model(b.top,'FictionalMillYard',False)
 for x,y,w,d in [(376,550,17,36),(424,560,16,40)]:
  m=b.model(mill,'MillWorkshop')
  b.part(m,'BrickWorkshop',world((x,y),4),(w/S,8/S,d/S),(.48,.30,.23),material=848)
  b.part(m,'MetalRoof',world((x,y),8.2),((w+1)/S,.35/S,(d+1)/S),(.27,.30,.29),collide=False,material=1072)
  for side in [-1,1]:
   for oy in [-12,0,12]:
    b.part(m,'IndustrialWindow',world((x+side*(w/2+.04),y+oy),5.5),(.1/S,1.7/S,3/S),(.34,.43,.43),collide=False)
  b.sign(m,'REDLINE WORKS',world((x,y-d/2-.12),6),(w/S,3,.2))
  for dx in [-w*.25,w*.25]:b.part(m,'LoadingDoor',world((x+dx,y-d/2-.1),2),(5/S,4/S,.16/S),(.29,.33,.31),collide=False,material=1072)
 for site,text in [((348,570),'← TOWN BLOCKS'),((445,642),'PARKWAY →'),((399,676),'MILL YARD\nTIGHT CUT-THROUGH')]:
  b.sign(mill,text,world(site,2.5),(25,5,.3))
 b.save(output_root/'assets/generated/Hopedale.rbxmx')
 g['part_count']=b.count
 (output_root/'geo/generated/hopedale.json').write_text(json.dumps(g,indent=2,sort_keys=True)+'\n')
 # Small runtime configuration rather than replicating the source database.
 text='--!strict\n-- Generated by scripts/bake_hopedale.py; geographic coordinates are metres.\nreturn {\n'
 text+=f' Origin = Vector3.new(0,32,0),\n Garage = Vector3.new({garage["center"][0]/S:.5f},32,{-garage["center"][1]/S:.5f}),\n RouteLengthMetres = {g["route_length_m"]},\n'
 text+=f' CourseLengthMetres = {g["course_length_m"]},\n'
 text+=' Course = {\n'+''.join(f' Vector3.new({nodes[n][0]/S:.5f},32,{-nodes[n][1]/S:.5f}),\n' for n in g['course'])+' },\n'
 text+=' ServiceRoute = {\n'+''.join(f' Vector3.new({nodes[n][0]/S:.5f},32,{-nodes[n][1]/S:.5f}),\n' for n in g['service_route'])+' },\n'
 text+=' Junctions = {\n'+''.join(f'  Vector3.new({nodes[n][0]/S:.5f},32,{-nodes[n][1]/S:.5f}),\n' for n in g['junctions'])+' },\n'
 text+=' Discoveries = {\n'
 for name,point in [('Ballou Park',Polygon(next(v['points'] for v in g['greenery'] if v['id']==657661755)).centroid),('Bancroft Library',Polygon(next(v['points'] for v in g['buildings'] if v['id']==213632098)).centroid),('Little Red Shop',Polygon(next(v['points'] for v in g['buildings'] if v['id']==213632360)).centroid),('Parklands Entrance',Point(-362,551))]:
  point=unary_union(lines).interpolate(unary_union(lines).project(point))
  text+=f'  {{Name="{name}", Position=Vector3.new({point.x/S:.5f},32,{-point.y/S:.5f})}},\n'
 text+=' },\n'
 text+=' Route = {\n'+''.join(f'  Vector3.new({nodes[n][0]/S:.5f},32,{-nodes[n][1]/S:.5f}),\n' for n in g['route'])+' },\n}\n'
 (output_root/'src/shared/TownMap.luau').write_text(text)
 # Compact directed street graph for mission guidance and police path planning.
 ids=sorted({n for e in g['lane_edges'] for n in [e['from'],e['to']]});index={n:i+1 for i,n in enumerate(ids)}
 graph=[{'x':nodes[n][0]/S,'z':-nodes[n][1]/S,'links':sorted({index[e['to']] for e in g['lane_edges'] if e['from']==n})} for n in ids]
 # Split the actual Adin segment at the private driveway; no straight-line shortcut through houses.
 road_point=Point(garage['road'])
 a,d=min((seg for road in g['roads'] if road['name']=='Adin Street' for seg in road['segments']),key=lambda seg:LineString([nodes[v] for v in seg]).distance(road_point))
 ai,di=index[a],index[d];junction=len(graph)+1;home_index=junction+1
 graph.append({'x':garage['road'][0]/S,'z':-garage['road'][1]/S,'links':[home_index]})
 for start,finish in [(ai,di),(di,ai)]:
  if finish in graph[start-1]['links']:
   graph[start-1]['links'].remove(finish);graph[start-1]['links'].append(junction);graph[junction-1]['links'].append(finish)
 graph.append({'x':garage['center'][0]/S,'z':-garage['center'][1]/S,'links':[junction]})
 graphtext='--!strict\n-- Generated from OSM (ODbL 1.0) plus fictional parkway and private driveway. X/Z studs.\nlocal nodes: {{x:number,z:number,links:{number}}} = {}\n'
 for i,node in enumerate(graph,1):graphtext+=f' nodes[{i}] = {{x={node["x"]:.6f}, z={node["z"]:.6f}, links={{{", ".join(str(i) for i in sorted(node["links"]))}}}}}\n'
 graphtext+=f' return {{Nodes=nodes, Course={{{", ".join(str(index[n]) for n in g["course"])}}},\n Home = {home_index},\n ServiceRoute = {{{", ".join(str(index[n]) for n in g["service_route"])}}},\n Route = {{{", ".join(str(index[n]) for n in g["route"])}}},\n}}\n'
 (output_root/'src/shared/RoadGraph.luau').write_text(graphtext)

 return c,g
if __name__=='__main__':
 c,g=build();print(f'Baked Hopedale: {g["part_count"]} parts; {g["route_length_m"]}m loop')
