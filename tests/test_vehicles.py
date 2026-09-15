"""Check the bundled visual assets without executing any downloaded asset code."""
import unittest, json, re, xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
class VehicleAssets(unittest.TestCase):
 def test_four_local_models_are_geometry_only_and_bounded(self):
  for kind in ['Pickup','Electric','Sport','Police']:
   tree=ET.parse(ROOT/'assets/vehicles'/f'{kind}.rbxmx')
   model=tree.find('Item')
   self.assertEqual(model.attrib['class'],'Model')
   self.assertEqual(model.findtext('Properties/string[@name="Name"]'),kind)
   parts=[]
   for item in tree.findall('.//Item'):
    cls=item.attrib['class']
    self.assertIn(cls,['Model','MeshPart','Part','Decal','SurfaceAppearance','SpecialMesh','BlockMesh','CylinderMesh'])
    if cls in ['MeshPart','Part']:
     parts.append(item)
     self.assertEqual(item.findtext('Properties/bool[@name="CanCollide"]'),'false')
     self.assertEqual(item.findtext('Properties/bool[@name="CanQuery"]'),'false')
     self.assertEqual(item.findtext('Properties/bool[@name="Massless"]'),'true')
     if cls=='MeshPart':self.assertTrue(item.findtext('Properties/Content[@name="MeshContent"]/uri') or item.findtext('Properties/Content[@name="MeshId"]/url'))
   self.assertTrue(30<=len(parts)<=60)
   self.assertTrue(model.findtext('Properties/BinaryString[@name="AttributesSerialize"]'))
 def test_built_place_has_local_car_assets_and_gameplay_modules(self):
  # Run after Rojo builds so a stale place cannot pass source-only validation.
  tree=ET.parse(ROOT/'build/redline-county.rbxlx')
  storage=next(i for i in tree.findall('Item') if i.attrib['class']=='ServerStorage')
  assets=next(i for i in storage.findall('Item') if i.findtext('Properties/string[@name="Name"]')=='VehicleAssets')
  self.assertEqual({i.findtext('Properties/string[@name="Name"]') for i in assets.findall('Item')},{'Pickup','Electric','Sport','Police'})
  modules={i.findtext('Properties/string[@name="Name"]') for i in tree.findall('.//Item') if i.attrib['class'] in ['ModuleScript','LocalScript']}
  self.assertTrue({'TownTraffic','Workshop','DriftRules','DriftEffects','Progression','BundledVehicles','Circuit','LapRules','NightMode','PoliceAlert','Interface','ProfileStore','ProfileRules','MissionVariants','Roadblock','PoliceTactics','VehicleAudio','VehicleVisuals','Performance','PlaytestMetrics','VehicleFinish','Cosmetics'}<=modules)
 def test_road_light_clears_authored_paint_and_fits_streaming_budget(self):
  math_source=(ROOT/'src/shared/HeadlightMath.luau').read_text()
  lift=float(re.search(r'HeadlightMath.SurfaceLift = ([0-9.]+)',math_source)[1])
  tree=ET.parse(ROOT/'assets/generated/Hopedale.rbxmx')
  ground=next(i for i in tree.findall('.//Item') if i.findtext('Properties/string[@name="Name"]')=='LevelTerrain_Provisional')
  terrain=next(i for i in ground.findall('.//Item') if i.attrib['class']=='Part')
  def top(part):
   props=part.find('Properties');cf=props.find('CoordinateFrame');size=props.find('Vector3[@name="size"]')
   return float(cf.findtext('Y'))+sum(abs(float(cf.findtext('R1'+str(i))))*float(size.findtext(axis))/2 for i,axis in enumerate(['X','Y','Z']))
  floor=top(terrain)
  roads=next(i for i in tree.findall('.//Item') if i.findtext('Properties/string[@name="Name"]')=='Roads')
  surfaces=[i for i in roads.findall('.//Item') if i.findtext('Properties/string[@name="Name"]') in ['Surface','Centerline','Zebra','LoopChevron']]
  self.assertGreater(len(surfaces),100)
  for surface in surfaces:
   # These are visual-only geometry; the ground ray cannot detect their top.
   self.assertEqual(surface.findtext('Properties/bool[@name="CanQuery"]'),'false')
   self.assertGreater(floor+lift,top(surface)+.02)
  tune=(ROOT/'src/shared/Config.luau').read_text()
  reach=float(re.search(r'RoadMaxRange = ([0-9.]+)',tune)[1])
  project=json.loads((ROOT/'default.project.json').read_text())
  self.assertGreater(project['tree']['Workspace']['$properties']['StreamingTargetRadius'],reach+50)
 def test_built_scripts_match_current_sources(self):
  tree=ET.parse(ROOT/'build/redline-county.rbxlx')
  code={(i.attrib['class'],i.findtext('Properties/string[@name="Name"]')): i.findtext('Properties/*[@name="Source"]') for i in tree.findall('.//Item') if i.attrib['class'] in ['ModuleScript','LocalScript','Script']}
  for path in list((ROOT/'src/shared').glob('*.luau'))+list((ROOT/'src/client').glob('*.luau'))+list((ROOT/'src/server').glob('*.luau')):
   name=path.name.removesuffix('.client.luau').removesuffix('.server.luau').removesuffix('.luau')
   cls='LocalScript' if '.client.' in path.name else 'Script' if '.server.' in path.name else 'ModuleScript'
   self.assertEqual(code.get((cls,name)),path.read_text(),str(path))
if __name__=='__main__':unittest.main()
