"""Offline EPSG:26986 import. OSM-derived output: ODbL 1.0, © OSM contributors."""
import sys,json,math,hashlib,heapq,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.tools/gis'))
from pyproj import Transformer
from shapely.geometry import LineString,Polygon,Point,box
from shapely.ops import unary_union,polygonize

def load():
    config=json.loads((ROOT/'geo/curated/hopedale.json').read_text())
    transform=Transformer.from_crs('EPSG:4326',config['crs'],always_xy=True)
    origin=transform.transform(config['origin']['lon'],config['origin']['lat'])
    tree=ET.parse(ROOT/'geo/source/hopedale.osm').getroot()
    extra=ROOT/'geo/source/hopedale-pond-island.osm'
    if extra.exists():tree.extend(list(ET.parse(extra).getroot()))
    nodes={}; tags={}
    for n in tree.findall('node'):
        p=transform.transform(float(n.attrib['lon']),float(n.attrib['lat']))
        nodes[int(n.attrib['id'])]=[p[0]-origin[0],p[1]-origin[1]]
        tags[int(n.attrib['id'])]={t.attrib['k']:t.attrib['v'] for t in n.findall('tag')}
    area=box(*config['bounds_metres']); roads=[]; buildings=[]; greenery=[]; paths=[]; water=[]
    valid={'residential','tertiary','secondary','unclassified','primary','living_street'}
    for w in tree.findall('way'):
        t={a.attrib['k']:a.attrib['v'] for a in w.findall('tag')}; ids=[int(n.attrib['ref']) for n in w.findall('nd')]; pts=[nodes[n] for n in ids]; wid=int(w.attrib['id'])
        if t.get('highway') in valid and not t.get('access')=='private' and t.get('motor_vehicle')!='private':
            if t.get('bridge')=='yes' or t.get('tunnel')=='yes' or t.get('layer','0')!='0':
                if area.intersects(LineString(pts)) and wid not in config.get('modeled_bridges',[]):raise ValueError('Selected extent includes separate road level; model explicitly before proceeding')
            segments=[]
            for a,b in zip(ids,ids[1:]):
                # Endpoints outside the area are clipped only in geometry; graph stops at boundary.
                if area.covers(Point(nodes[a])) and area.covers(Point(nodes[b])):segments.append([a,b])
            if segments:roads.append({'id':wid,'name':t.get('name','Unnamed street'),'oneway':t.get('oneway','no'),'tags':t,'segments':segments})
        if 'building' in t and len(pts)>3:
            p=Polygon(pts)
            if p.is_valid and area.contains(p):buildings.append({'id':wid,'tags':t,'points':pts})
        if t.get('highway') in ['footway','path','cycleway'] and area.intersects(LineString(pts)):
            paths.append({'id':wid,'points':pts})
        if (t.get('leisure') in ['park','garden','recreation_ground'] or t.get('landuse') in ['forest','grass','recreation_ground'] or t.get('natural') in ['wood','water']) and len(pts)>3:
            p=Polygon(pts)
            if p.is_valid and area.intersects(p):greenery.append({'id':wid,'tags':t,'points':pts})
    ways={int(w.attrib['id']):[nodes[int(n.attrib['ref'])] for n in w.findall('nd')] for w in tree.findall('way')}
    for relation in tree.findall('relation'):
        t={a.attrib['k']:a.attrib['v'] for a in relation.findall('tag')}
        if t.get('natural')!='water':continue
        outer=[];inner=[]
        for member in relation.findall('member'):
            if member.attrib['type']!='way':continue
            wid=int(member.attrib['ref'])
            if wid not in ways:raise ValueError('Water relation incomplete; cache missing way '+str(wid))
            (inner if member.attrib.get('role')=='inner' else outer).append(LineString(ways[wid]))
        geometry=unary_union(list(polygonize(unary_union(outer)))).difference(unary_union(list(polygonize(unary_union(inner)))))
        geometry=geometry.intersection(area)
        polygons=list(geometry.geoms) if hasattr(geometry,'geoms') else [geometry]
        for poly in polygons:
            if poly.geom_type=='Polygon' and not poly.is_empty:water.append({'id':int(relation.attrib['id']),'name':t.get('name','Pond'),'points':list(poly.exterior.coords),'holes':[list(h.coords) for h in poly.interiors]})
    from course_geometry import add_course
    course,service=add_course(nodes,roads)
    graph={}; edges=[]
    for road in roads:
        for a,b in road['segments']:
            pairs=[(a,b)] if road['oneway']=='yes' else [(b,a)] if road['oneway']=='-1' else [(a,b),(b,a)]
            for u,v in pairs:
                length=math.dist(nodes[u],nodes[v]);graph.setdefault(u,[]).append((v,length,road['id']))
                edges.append({'id':f'{road["id"]}:{u}:{v}','from':u,'to':v,'road':road['name'],'length_m':round(length,3),'width_m':road['tags'].get('half_width',6) if road['tags'].get('fictional') else 3.6,'direction':'right-hand','control':tags.get(v,{}).get('highway') if tags.get(v,{}).get('highway') in ['stop','give_way','traffic_signals'] else 'unverified','navigation':[nodes[u],nodes[v]]})
    def path(a,b,name):
        queue=[(0,a,[])];seen=set()
        while queue:
            d,u,p=heapq.heappop(queue)
            if u==b:return p+[u],d
            if u in seen:continue
            seen.add(u)
            for v,w,rid in graph.get(u,[]):
                if next(r['name'] for r in roads if r['id']==rid)==name:heapq.heappush(queue,(d+w,v,p+[u]))
        raise ValueError(f'No legal route on {name}: {a}->{b}')
    route=[]; length=0
    for a,b,name in zip(config['route_nodes'],config['route_nodes'][1:],config['route_roads']):
        segment,d=path(a,b,name);route.extend(segment[:-1]);length+=d
    route.append(route[0])
    # Choose a fictional site off Adin, entirely clear of mapped buildings.
    footprints=unary_union([Polygon(b['points']) for b in buildings])
    adin=unary_union([LineString([nodes[a],nodes[b]]) for r in roads if r['name']=='Adin Street' for a,b in r['segments']])
    garage=None
    for x in range(230,391,5):
        for y in range(80,171,5):
            reserve=box(x-23,y-23,x+23,y+23)
            if area.contains(reserve) and reserve.distance(footprints)>3 and 12<reserve.distance(adin)<50:
                near=adin.interpolate(adin.project(Point(x,y))); garage={'center':[x,y],'road':[near.x,near.y],'reserve':[x-23,y-23,x+23,y+23]};break
        if garage:break
    if not garage:raise ValueError('No clear fictional garage site')
    degree={n:len(set(v for v,_,_ in links)) for n,links in graph.items()}
    junctions=[n for n,v in degree.items() if v>=3]
    out={'schema':1,'origin':config['origin'],'origin_projected':origin,'crs':config['crs'],'bounds':config['bounds_metres'],'play_bounds':[-650,-120,950,820],'course':course,'service_route':service,'course_length_m':round(sum(math.dist(nodes[a],nodes[b]) for a,b in zip(course,course[1:])),2),'metres_per_stud':.28,'nodes':nodes,'roads':roads,'buildings':buildings,'greenery':greenery,'paths':paths,'water':water,'lane_edges':edges,'junctions':junctions,'crossings':[n for n,t in tags.items() if t.get('highway')=='crossing' and area.covers(Point(nodes[n]))],'route':route,'route_length_m':round(length,2),'garage':garage,'supplement_sha256':hashlib.sha256((ROOT/'geo/source/hopedale-pond-island.osm').read_bytes()).hexdigest(),'source_sha256':hashlib.sha256((ROOT/'geo/source/hopedale.osm').read_bytes()).hexdigest()}
    # Right-hand lane navigation offsets; explicit junction connections separate from rendering.
    for edge in edges:
        a,b=edge['navigation'];dx,dy=b[0]-a[0],b[1]-a[1];l=math.hypot(dx,dy);off=(dy/l*1.8,-dx/l*1.8)
        edge['navigation']=[[round(p[0]+off[0],3),round(p[1]+off[1],3)] for p in [a,b]]
        edge['junction_behavior']=('stop_before_entering' if edge['to'] in junctions and edge['road'] not in ['Hopedale Street','Dutcher Street','Redline Parkway'] else 'yield_to_conflicting_traffic')
        edge['control_source']='OSM tag' if edge['control']!='unverified' else 'provisional gameplay priority; verify signs in Studio review'
        edge['next']=[e['id'] for e in edges if e['from']==edge['to'] and e['to']!=edge['from']]
    return config,out
if __name__=='__main__':
    c,d=load();(ROOT/'geo/generated/hopedale.json').write_text(json.dumps(d,indent=2,sort_keys=True)+'\n');print(f'{len(d["roads"])} ways, {len(d["buildings"])} footprints, loop {d["route_length_m"]} m; garage {d["garage"]}')
