"""Offline GIS integration checks, never a substitute for a Studio driving test."""
import sys,json,tempfile,hashlib,unittest,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'scripts'),str(ROOT/'geo/curated')]
from hopedale_geo import load,Polygon,box,LineString,unary_union,Transformer
from bake_hopedale import build
from landmarks import bake
class GeographyTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):cls.c,cls.g=load()
 def test_metric_origin_and_axes(self):
  g=self.g;t=Transformer.from_crs(4326,26986,always_xy=True);e,n=t.transform(-71.5398681,42.1289534)
  self.assertAlmostEqual(e,196703.6893,3);self.assertAlmostEqual(n,875393.0276,3)
  self.assertLess(abs(g['nodes'][7241414065][0]),.001);self.assertLess(abs(g['nodes'][7241414065][1]),.001)
  north=t.transform(-71.5398681,42.1299534);east=t.transform(-71.5388681,42.1289534)
  self.assertTrue(110<north[1]-n<112);self.assertTrue(82<east[0]-e<84)
  self.assertAlmostEqual(28/g['metres_per_stud'],100)
 def test_loop_is_legal_connected_and_closed(self):
  g=self.g;self.assertEqual(g['route'][0],g['route'][-1]);edges={(e['from'],e['to']) for e in g['lane_edges']}
  self.assertTrue(all((a,b) in edges for a,b in zip(g['route'],g['route'][1:])))
  self.assertTrue(900<g['route_length_m']<940);self.assertGreaterEqual(len(g['junctions']),4)
  for e in g['lane_edges']:
   for n in e['next']:self.assertTrue(any(q['id']==n and q['from']==e['to'] for q in g['lane_edges']))
 def test_parkway_is_closed_clear_and_connected_to_town(self):
  g=self.g;nodes=g['nodes'];course=g['course'];self.assertEqual(course[0],course[-1])
  self.assertTrue(1600<g['course_length_m']<1800)
  edges={(e['from'],e['to']) for e in g['lane_edges']}
  for a,b in zip(course,course[1:]):self.assertIn((a,b),edges);self.assertIn((b,a),edges)
  fiction=unary_union([LineString([nodes[a],nodes[b]]) for road in g['roads'] if road['tags'].get('fictional') for a,b in road['segments']]).buffer(6)
  self.assertTrue(box(*g['play_bounds']).contains(fiction))
  self.assertFalse(fiction.intersects(unary_union([Polygon(v['points']) for v in g['buildings']])))
  reached={g['route'][0]};pending=list(reached)
  adjacency={}
  for a,b in edges:adjacency.setdefault(a,[]).append(b)
  while pending:
   for b in adjacency.get(pending.pop(),[]):
    if b not in reached:reached.add(b);pending.append(b)
  self.assertTrue(set(course).issubset(reached),'all parkway nodes reachable from town')
 def test_mill_circuit_and_independent_parkway_access(self):
  g=self.g;nodes=g['nodes'];service=g['service_route']
  self.assertEqual(service[0],service[-1])
  self.assertGreater(LineString([nodes[n] for n in service]).length,450)
  links={}
  for e in g['lane_edges']:links.setdefault(e['from'],set()).add(e['to'])
  def reached_without(removed):
   reached={g['route'][0]};pending=list(reached)
   while pending:
    for n in links.get(pending.pop(),set()):
     if n not in removed and n not in reached:reached.add(n);pending.append(n)
   return reached
  south=set(n for r in g['roads'] if r['name']=='Parkway Access' for seg in r['segments'] for n in seg)
  north=set(n for r in g['roads'] if r['name']=='North Parkway Access' for seg in r['segments'] for n in seg)
  self.assertGreater(len(set(g['course']) & reached_without(south)),80)
  self.assertGreater(len(set(g['course']) & reached_without(north)),80)
  self.assertTrue(set(service).issubset(reached_without(south)))
  obstacles=unary_union([Polygon(b['points']).minimum_rotated_rectangle for b in g['buildings']])
  for r in g['roads']:
   if r['id'] in [-3,-4,-5,-6]:
    for a,b in r['segments']:
     self.assertFalse(LineString([nodes[a],nodes[b]]).buffer(4).intersects(obstacles),r['name']+' crosses building')
 def test_garage_floor_has_no_coplanar_terrain_or_asphalt(self):
  # Read actual baked geometry: a hole under the floor prevents depth fighting.
  tree=ET.parse(ROOT/'assets/generated/Hopedale.rbxmx')
  cx,cy=self.g['garage']['center'];floor=box(cx-41*.28,cy-8-23*.28,cx+41*.28,cy-8+23*.28).buffer(-.002)
  for part in tree.findall('.//Item'):
   if part.attrib['class'] not in ['Part','WedgePart']:continue
   cf=part.find('Properties/CoordinateFrame');size=part.find('Properties/Vector3[@name="size"]')
   if cf is None or size is None:continue
   x,y,z=[float(cf.findtext(a)) for a in 'XYZ'];sx,sy,sz=[float(size.findtext(a)) for a in 'XYZ']
   name=part.findtext('Properties/string[@name="Name"]')
   if name=='GroundTile':
    self.assertFalse(box((x-sx/2)*.28,-(z+sz/2)*.28,(x+sx/2)*.28,-(z-sz/2)*.28).intersects(floor),'terrain overlaps floor')
   elif name=='Surface':
    # Surface wedges are rotated; projected triangle vertices describe the top.
    points=[]
    for yy,zz in [(-sy/2,-sz/2),(-sy/2,sz/2),(sy/2,sz/2)]:
     px=x+float(cf.findtext('R01'))*yy+float(cf.findtext('R02'))*zz
     pz=z+float(cf.findtext('R21'))*yy+float(cf.findtext('R22'))*zz
     points.append((px*.28,-pz*.28))
    if abs(y-32)<1:self.assertFalse(Polygon(points).intersects(floor),'road surface overlaps floor')
 def test_fictional_garage_clear_and_connected(self):
  garage=self.g['garage'];reserve=box(*garage['reserve']);foot=unary_union([Polygon(v['points']) for v in self.g['buildings']])
  self.assertFalse(reserve.intersects(foot))
  driveway=LineString([garage['center'],garage['road']]).buffer(3.8)
  self.assertFalse(driveway.intersects(foot),'fictional driveway must not cross a mapped building')
  adin=unary_union([LineString([self.g['nodes'][a],self.g['nodes'][b]]) for r in self.g['roads'] if r['name']=='Adin Street' for a,b in r['segments']])
  self.assertTrue(driveway.intersects(adin))
 def test_regeneration_and_handcrafted_preservation(self):
  sources=list((ROOT/'geo/curated').glob('*.json'))+list((ROOT/'geo/curated').glob('*.py'))+list((ROOT/'assets/handcrafted').glob('*'))
  before={str(p):p.read_bytes() for p in sources if p.is_file()}
  with tempfile.TemporaryDirectory() as folder:
   out=Path(folder)
   for path in ['assets/generated','geo/generated','src/shared']: (out/path).mkdir(parents=True)
   c,g=build(out);bake(c,g,out)
   first={str(p.relative_to(out)):p.read_bytes() for p in out.rglob('*') if p.is_file()}
   c,g=build(out);bake(c,g,out)
   self.assertEqual(first,{str(p.relative_to(out)):p.read_bytes() for p in out.rglob('*') if p.is_file()})
   self.assertLess(g['part_count']+sum(p.attrib['class'] in ['Part','MeshPart','WedgePart','SpawnLocation'] for p in ET.parse(out/'assets/generated/HopedaleLandmarks.rbxmx').findall('.//Item')),12000)
   tree=ET.parse(out/'assets/generated/HopedaleLandmarks.rbxmx')
   names=[p.text for p in tree.findall('.//string[@name="Name"]')]
   for required in ['HistoricTownHall','HomeBase','HomeSpawn','Display_Pickup','Display_Electric','Display_Sport','Door_-27','Door_0','Door_27']:self.assertIn(required,names)
  self.assertEqual(before,{p:Path(p).read_bytes() for p in before})
 def test_garage_arrivals_camera_and_selectors_are_clear(self):
  # Exercise the authored bake, not duplicated room coordinates. Transform probes
  # into each part's local frame so rotated furniture/walls remain covered.
  with tempfile.TemporaryDirectory() as folder:
   out=Path(folder);(out/'assets/generated').mkdir(parents=True);bake(self.c,self.g,out)
   tree=ET.parse(out/'assets/generated/HopedaleLandmarks.rbxmx')
   home=next(i for i in tree.findall('.//Item[@class="Model"]') if i.findtext('Properties/string[@name="Name"]')=='HomeBase')
   parts=[p for p in home.findall('.//Item') if p.attrib['class'] in ['Part','MeshPart','WedgePart']]
   def named(name):return next(p for p in parts if p.findtext('Properties/string[@name="Name"]')==name)
   def vector(p,prop):return tuple(float(p.findtext('Properties/'+prop+'/'+axis)) for axis in 'XYZ')
   def pos(p):return vector(p,'CoordinateFrame[@name="CFrame"]')
   def touches(point,radius,p):
    delta=[a-b for a,b in zip(point,pos(p))];size=vector(p,'Vector3[@name="size"]')
    cf=p.find('Properties/CoordinateFrame');local=[sum(delta[j]*float(cf.findtext(f'R{j}{i}')) for j in range(3)) for i in range(3)]
    return all(abs(v)<s/2+r for v,s,r in zip(local,size,radius))
   solid=[p for p in parts if p.findtext('Properties/bool[@name="CanCollide"]')=='true']
   visible=[p for p in parts if float(p.findtext('Properties/float[@name="Transparency"]','0'))<1]
   for i,kind in enumerate(['Pickup','Electric','Sport'],1):
    arrival=named('Arrival_'+str(i));point=pos(arrival)
    self.assertEqual(arrival.findtext('Properties/float[@name="Transparency"]'),'1')
    for p in solid:
     self.assertFalse(touches(point,(2,3,2),p),'arrival intersects '+p.findtext('Properties/string[@name="Name"]'))
    for step in range(25):
     t=step/24;camera=(point[0],point[1]+1.5+1.5*t,point[2]+6*t)
     for p in visible:self.assertFalse(touches(camera,(.4,.4,.4),p),'camera blocked by '+p.findtext('Properties/string[@name="Name"]'))
    selector=pos(named('Select_'+kind))
    self.assertLess(sum((a-b)**2 for a,b in zip(point,selector))**.5,12,'selection must be in prompt range on arrival')
    # Walk the direct approach to each selector without entering a display body.
    for step in range(25):
     t=step/24;walk=(point[0]+(selector[0]-point[0])*t,point[1],point[2]+(selector[2]-point[2])*t)
     for p in solid:self.assertFalse(touches(walk,(1,2.5,1),p),'selection approach blocked')
 def test_baked_loop_has_clear_driving_corridor_and_visible_closures(self):
  # Check actual collider transforms, not only GIS topology. A street post at the
  # Adin/Hopedale junction previously stood in the drivable corridor.
  with tempfile.TemporaryDirectory() as folder:
   out=Path(folder)
   for path in ['assets/generated','geo/generated','src/shared']:(out/path).mkdir(parents=True)
   c,g=build(out);tree=ET.parse(out/'assets/generated/Hopedale.rbxmx')
   corridor=unary_union([LineString([g['nodes'][n] for n in route]).buffer(width) for route,width in [(g['route'],3.1),(g['course'],5),(g['service_route'],3.7)]])
   corridor=unary_union([corridor]+[LineString([g['nodes'][n] for n in seg]).buffer(3.7) for r in g['roads'] if r['id'] in [-4,-5,-6] for seg in r['segments']])
   names=[];closures=0
   for part in tree.findall('.//Item[@class="Part"]'):
    name=part.findtext('Properties/string[@name="Name"]');names.append(name)
    if name=='ClosureBarrier':closures+=1
    if name=='GroundTile' or part.findtext('Properties/bool[@name="CanCollide"]')!='true':continue
    cf=part.find('Properties/CoordinateFrame');size=part.find('Properties/Vector3[@name="size"]')
    x,y,z=[float(cf.findtext(a)) for a in 'XYZ'];sx,sy,sz=[float(size.findtext(a)) for a in 'XYZ']
    if y-sy/2>38 or y+sy/2<32:continue
    points=[]
    for xx,zz in [(-sx/2,-sz/2),(sx/2,-sz/2),(sx/2,sz/2),(-sx/2,sz/2)]:
     px=x+float(cf.findtext('R00'))*xx+float(cf.findtext('R02'))*zz;pz=z+float(cf.findtext('R20'))*xx+float(cf.findtext('R22'))*zz
     points.append((px*.28,-pz*.28))
    self.assertFalse(Polygon(points).intersects(corridor),'baked collider blocks town loop: '+name)
   self.assertGreater(names.count('LoopChevron'),70)
   self.assertEqual(names.count('BoundaryFence'),4)
   degree={}
   for road in g['roads']:
    for a,b in road['segments']:degree.setdefault(a,set()).add(b);degree.setdefault(b,set()).add(a)
   self.assertEqual(closures,sum(len(links)==1 for links in degree.values()))
if __name__=='__main__':unittest.main()
