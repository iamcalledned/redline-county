from hopedale_geo import load,ROOT,Polygon,LineString,box
from PIL import Image,ImageDraw,ImageFont
c,g=load();nodes=g['nodes'];w,h=1280,1040
im=Image.new('RGB',(w,h),'#f5f3ed');d=ImageDraw.Draw(im)
fontpath='/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
f=lambda n:ImageFont.truetype(fontpath,n)
d.text((40,24),'HOPEDALE CENTER',font=f(32),fill='#23343d');d.text((40,70),'Town getaway routes + continuous parkway • gold loot sites / red closed branches',font=f(18),fill='#52636c')
x0,y0,x1,y1=g['play_bounds'];scale=min(1080/(x1-x0),780/(y1-y0))
def p(v):return (70+(v[0]-x0)*scale,130+(y1-v[1])*scale)
d.rectangle((*p((x0,y1)),*p((x1,y0))),fill='#e2e7d8',outline='#869980',width=2)
for v in g['greenery']:
 poly=Polygon(v['points']).intersection(box(*g['play_bounds']))
 for q in (list(poly.geoms) if hasattr(poly,'geoms') else [poly]):
  if q.geom_type=='Polygon':d.polygon([p(vv) for vv in q.exterior.coords],fill='#b6c7a1')
for v in g['water']:d.polygon([p(vv) for vv in v['points']],fill='#76a8b1')
for v in g['paths']:
 path=LineString(v['points']).intersection(box(*g['play_bounds']))
 for q in (list(path.geoms) if hasattr(path,'geoms') else [path]):
  if q.geom_type=='LineString':d.line([p(vv) for vv in q.coords],fill='#bca77f',width=2)
for b in g['buildings']:d.polygon([p(v) for v in b['points']],fill='#b7afa1')
for r in g['roads']:
 for a,b in r['segments']:d.line([p(nodes[a]),p(nodes[b])],fill='#faf9f5',width=16)
 for a,b in r['segments']:d.line([p(nodes[a]),p(nodes[b])],fill='#7f8987',width=10)
d.line([p(nodes[n]) for n in g['course']],fill='#378cd1',width=9)
d.line([p(nodes[n]) for n in g['service_route']],fill='#b1753a',width=7)
d.text(p((305,713)),'MILL YARD\nLoop + cut-through',font=f(16),fill='#754a23')
d.text(p((565,435)),f'REDLINE PARKWAY\n{g["course_length_m"]:.0f} m circuit\nFictional driving course',font=f(20),fill='#215875')
route=[p(nodes[n]) for n in g['route']];d.line(route,fill='#27998b',width=8)
for n in c['route_nodes'][:-1]:
 x,y=p(nodes[n]);d.ellipse((x-7,y-7,x+7,y+7),fill='#c77738',outline='white',width=2)
# Mission sites use the same ordered route indices as Contracts.luau (one-based).
for i,index in enumerate([3,11,13,19,53],1):
 x,y=p(nodes[g['route'][index-1]]);d.ellipse((x-11,y-11,x+11,y+11),fill='#efbb4b',outline='#293941',width=2);d.text((x-5,y-9),str(i),font=f(14),fill='#17242b')
for i,index in enumerate([69,5,37],1):
 x,y=p(nodes[g['course'][index-1]]);d.ellipse((x-11,y-11,x+11,y+11),fill='#efbb4b',outline='#293941',width=2);d.text((x-7,y-9),'P'+str(i),font=f(12),fill='#17242b')
ends={}
for road in g['roads']:
 for a,b in road['segments']:ends.setdefault(a,set()).add(b);ends.setdefault(b,set()).add(a)
for node,links in ends.items():
 if len(links)==1:
  x,y=p(nodes[node]);d.line((x-7,y-7,x+7,y+7),fill='#c94445',width=4);d.line((x-7,y+7,x+7,y-7),fill='#c94445',width=4)
labels={'Parklands / pond shore':(-620,770),'Little Red Shop':(-610,540),'Bancroft Library':(-350,145),'Ballou Park':(-270,250),'Hopedale Street':(-162,191),'Union Street':(-95,355),'Dutcher Street':(90,206),'Adin Street':(125,10),'Hope Street':(125,262),'Draper Street':(60,112),'Peace Street':(-36,288),'Prospect Street':(113,359)}
for name,pt in labels.items():d.text(p(pt),name,font=f(15),fill='#263c47',stroke_width=2,stroke_fill='#f5f3ed')
hall=p((0,0));d.ellipse((hall[0]-8,hall[1]-8,hall[0]+8,hall[1]+8),fill='#963e36');d.line([hall,p((-140,-48))],fill='#963e36',width=2);d.text(p((-245,-70)),'Historic Town Hall\n78 Hopedale Street',font=f(18),fill='#963e36')
center=g['garage']['center'];d.rectangle((*p((367,103)),*p((413,57))),fill='#608b96',outline='white',width=3);d.line([p(center),p(g['garage']['road'])],fill='#608b96',width=8);d.text(p((242,-15)),'Fictional home garage\nAdded driveway to Adin St',font=f(16),fill='#275663')
d.text((1140,135),'N ↑',font=f(26),fill='#23343d');d.line((80,952,80+100*scale,952),fill='#263c47',width=4);d.text((80,962),'100 metres',font=f(15),fill='#263c47')
d.text((300,948),f'Parkway: {g["course_length_m"]:.0f} m  •  Extent: {x1-x0:.0f} × {y1-y0:.0f} m',font=f(18),fill='#263c47');d.text((300,978),'© OpenStreetMap contributors · ODbL 1.0 · No proprietary map tiles',font=f(15),fill='#52636c')
im.save(ROOT/'docs/previews/hopedale-route.png')
