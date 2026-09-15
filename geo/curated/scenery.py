"""Reference-based local landmarks; simplified proportions, not surveyed facades."""
from bake_hopedale import world,S,math,Polygon,LineString,unary_union,ROOT
import xml.etree.ElementTree as ET
import copy

def landmarks(b,c,g):
 nodes=g['nodes'];streets=unary_union([LineString([nodes[a],nodes[d]]) for r in g['roads'] for a,d in r['segments']])
 for way,name,red in [(213632360,'LittleRedShop',True),(213632098,'BancroftLibrary',False)]:
  data=next(v for v in g['buildings'] if v['id']==way);poly=Polygon(data['points']);rect=list(poly.minimum_rotated_rectangle.exterior.coords);center=poly.centroid
  edges=[(math.dist(rect[i],rect[i+1]),rect[i],rect[i+1]) for i in range(4)]
  width,a,d=min(edges) if red else max(edges);depth=poly.minimum_rotated_rectangle.area/width
  width*=.96;depth*=.96;yaw=math.atan2(-(d[0]-a[0]),d[1]-a[1])+math.pi/2
  m=b.model(b.top,name);height=4.7 if red else 8;rise=3 if red else 4
  col=(.60,.25,.23) if red else (.56,.57,.53);trim=(.84,.79,.66);slate=(.20,.23,.25)
  def pos(x,y,z):return world((center.x+math.cos(yaw)*x+math.sin(yaw)*z,center.y+math.sin(yaw)*x-math.cos(yaw)*z),y)
  def part(n,x,y,z,sx,sy,sz,color,solid=False,material=256):return b.part(m,n,pos(x,y,z),(sx/S,sy/S,sz/S),color,yaw,collide=solid,material=material)
  part('MasonryFoundation',0,.4,0,width+0.15,.8,depth+.15,(.38,.38,.35),True,832)
  part('Clapboard' if red else 'GraniteWalls',0,height/2+.6,0,width,height,depth,col,True,512 if red else 832)
  # Roof ridge along the long axis, with a sheltered gable entrance.
  for side in [-1,1]:
   angle=side*math.atan2(rise,width/2);ca,sa=math.cos(yaw),math.sin(yaw);cr,sr=math.cos(angle),math.sin(angle)
   rot=((ca*cr,-ca*sr,sa),(sr,cr,0),(-sa*cr,sa*sr,ca))
   b.part(m,'SlateRoof',pos(side*width/4,height+.6+rise/2,0),(math.hypot(width/2,rise)/S+.8,.22/S,(depth+1)/S),slate,rot=rot,collide=False,material=816)
  for side in [-1,1]:
   part('EaveTrim',side*(width/2+.15),height+.5,0,.18,.25,depth+.8,trim)
   for index in range(6 if red else 5):
    z=-depth*.38+index*depth*.76/(5 if red else 4)
    part('SideWindowFrame',side*(width/2+.06),height*.57+.6,z,.16,2.4,1.25,trim)
    part('SideGlass',side*(width/2+.16),height*.57+.6,z,.10,2.13,1.04,(.19,.29,.33))
    part('Sash',side*(width/2+.23),height*.57+.6,z,.08,.09,1.1,trim)
  part('FrontDoor',-width*.18,1.7,-depth/2-.07,1.3,2.2,.16,(.22,.18,.14))
  part('FrontWindow',width*.22,2.9,-depth/2-.12,1.7,2.4,.15,trim)
  part('FrontGlass',width*.22,2.9,-depth/2-.22,1.4,2.15,.1,(.19,.29,.33))
  part('GableWindow',0,height+1.3,-depth/2-.08,1.1,1.5,.12,trim)
  part('PorchDeck',0,.4,-depth/2-1.1,width*.7,.35,2.2,(.47,.39,.29),True)
  for x in [-width*.32,width*.32]:
   part('PorchPost',x,1.4,-depth/2-2,.12,2,.12,trim)
  for side in [-1,1]:part('PorchRail',side*width*.24,1.55,-depth/2-2,width*.2,.14,.12,trim)
  for y in range(1,int(height*3)):
   if red:part('ClapboardReveal',0,y/3+.6,-depth/2-.02,width,.02,.05,(.48,.19,.17))
  part('Chimney',-width*.22,height+rise+.3,depth*.2,.75,2.8,.75,(.46,.29,.24),False,832)
  label='LITTLE RED SHOP\nDraper history museum' if red else 'BANCROFT MEMORIAL LIBRARY'
  b.sign(m,label,pos(0,3.8,-depth/2-.3),(width*.8/S,1.1/S,.2),yaw)
  if not red:
   for x in [-width*.43,0,width*.43]:part('GraniteButtress',x,height/2,-depth/2-.18,.5,height,.5,col)
   part('HopeFountainPlinth',width*.7,.5,-depth*.35,2,1,2,(.57,.59,.54))
   part('HopeFigure',width*.7,2,-depth*.35,.6,2,.5,(.39,.44,.38))
 # Ballou memorial in its mapped park. Scenic furniture stays off the road.
 park=next(v for v in g['greenery'] if v['id']==657661755);center=Polygon(park['points']).centroid
 m=b.model(b.top,'BallouMemorialPark');x,y=center.x,center.y
 b.part(m,'MemorialPlinth',world((x,y),.7),(2.4/S,1.4/S,2.4/S),(.60,.61,.55),material=832)
 b.part(m,'BallouFigure',world((x,y),2.3),(.7/S,1.9/S,.55/S),(.32,.38,.31),collide=False)
 head=b.part(m,'MemorialHead',world((x,y),3.5),(.5/S,.6/S,.5/S),(.32,.38,.31),collide=False);b.prop(head,'token','shape',0)
 b.sign(m,'ADIN BALLOU PARK',world((x,y-3),1),(22,3,.3))
 for dx,dn in [(-6,0),(6,0),(-6,8),(6,8)]:
  b.part(m,'ParkBench',world((x+dx,y+dn),.5),(2/S,.18/S,.6/S),(.43,.30,.18),collide=False)
  b.part(m,'BenchBack',world((x+dx,y+dn+.3),.85),(2/S,.6/S,.12/S),(.43,.30,.18),collide=False)
  for side in [-.75,.75]:b.part(m,'BenchLeg',world((x+dx+side,y+dn),.25),(.12/S,.5/S,.5/S),(.21,.24,.21),collide=False)
 # Parklands trailhead at the southern pond approach; only this slice is represented.
 m=b.model(b.top,'ParklandsTrailhead');site=(-371,555)
 b.sign(m,'HOPEDALE PARKLANDS\nPond walk · woodland paths',world(site,2.2),(32,7,.6),color=(.19,.29,.20))
 for dx in [-4,4]:b.part(m,'TrailheadPost',world((site[0]+dx,site[1]),1.1),(.5/S,2.2/S,.5/S),(.34,.26,.17))
 for i in range(3):
  p=(-380-i*8,569+i*7)
  b.part(m,'PicnicTop',world(p,.75),(1.8/S,.18/S,1.3/S),(.47,.34,.21),collide=False)
  for side in [-1,1]:b.part(m,'PicnicBench',world((p[0]+side,p[1]),.45),(.4/S,.14/S,1.8/S),(.47,.34,.21),collide=False)

def display_asset(b,display,kind,loc):
 # Geometry is already fitted to the chassis. Keep editor previews consistent with play.
 root=ET.parse(ROOT/'assets/vehicles'/f'{kind}.rbxmx').find('Item')
 for item in root.findall('Item'):
  part=copy.deepcopy(item);part.attrib.pop('referent',None)
  props=part.find('Properties')
  for field in list(props):
   if field.tag=='SharedString':props.remove(field)
  cf=part.find('Properties/CoordinateFrame[@name="CFrame"]')
  if cf is None:continue
  for axis,offset in zip('XYZ',loc):cf.find(axis).text=str(float(cf.findtext(axis))+offset)
  b.count+=1;display.append(part)
