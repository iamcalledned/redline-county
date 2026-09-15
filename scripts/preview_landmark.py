"""Offline geometry QA only; does not simulate Roblox materials/lighting."""
from hopedale_geo import ROOT,load,Polygon,LineString,unary_union
from bake_hopedale import world,sub,add,dot,cross,unit,mul
from PIL import Image,ImageDraw,ImageFont
import numpy as np
import xml.etree.ElementTree as ET,math
c,g=load();tree=ET.parse(ROOT/'assets/generated/HopedaleLandmarks.rbxmx');root=next(i for i in tree.findall('.//Item') if i.find('./Properties/string[@name="Name"]') is not None and i.find('./Properties/string[@name="Name"]').text=='HistoricTownHall')
poly=Polygon(next(b['points'] for b in g['buildings'] if b['id']==c['town_hall_way']));ctr=poly.centroid
streets=unary_union([LineString([g['nodes'][a],g['nodes'][b]]) for r in g['roads'] if r['name']=='Hopedale Street' for a,b in r['segments']]);p=streets.interpolate(streets.project(ctr));front=unit((p.x-ctr.x,0,-p.y+ctr.y));target=world((ctr.x,ctr.y),6)
camera=add(add(target,mul(front,155)),(0,25,0));forward=unit(sub(target,camera));right=unit(cross(forward,(0,1,0)));up=cross(right,forward)
def project(v):
 d=sub(v,camera);z=dot(d,forward);return(600+dot(d,right)*1050/z,450-dot(d,up)*1050/z,z)
faces=[]
for part in root.findall('./Item'):
 if part.attrib['class'] not in ['Part','WedgePart']:continue
 pr=part.find('Properties');size=[float(pr.find('Vector3').find(a).text) for a in ['X','Y','Z']];cf=pr.find('CoordinateFrame');pos=tuple(float(cf.find(a).text) for a in ['X','Y','Z']);rot=[[float(cf.find(f'R{i}{j}').text) for j in range(3)] for i in range(3)];col=pr.find('Color3');rgb=[float(col.find(a).text) for a in ['R','G','B']]
 if part.attrib['class']=='Part':
  verts=[(x*size[0]/2,y*size[1]/2,z*size[2]/2) for x,y,z in [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]];indices=[(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(3,7,6,2),(0,1,5,4)]
 else:
  verts=[(x*size[0]/2,y*size[1]/2,z*size[2]/2) for x,y,z in [(-1,-1,-1),(1,-1,-1),(-1,-1,1),(1,-1,1),(-1,1,1),(1,1,1)]];indices=[(0,2,4),(1,5,3),(2,3,5,4),(0,1,3,2),(0,4,5,1)]
 vertices=[add(pos,tuple(sum(rot[i][j]*v[j] for j in range(3)) for i in range(3))) for v in verts]
 for ids in indices:
  vs=[vertices[i] for i in ids];norm=unit(cross(sub(vs[1],vs[0]),sub(vs[2],vs[0])));shade=.7+.3*abs(dot(norm,unit((.4,1,.3))));color=tuple(int(min(1,x*shade)*255) for x in rgb);z=sum(dot(sub(v,camera),forward) for v in vs)/len(vs);faces.append((z,[project(v) for v in vs],color))
im=Image.new('RGB',(1200,880),'#dce6e6');d=ImageDraw.Draw(im);d.rectangle((0,650,1200,880),fill='#929584')
pixels=np.array(im);depth=np.full((880,1200),np.inf)
for _,points,col in faces:
 for index in range(1,len(points)-1):
  a,b,c=points[0],points[index],points[index+1]
  x0=max(0,int(min(a[0],b[0],c[0])));x1=min(1199,int(max(a[0],b[0],c[0]))+1)
  y0=max(0,int(min(a[1],b[1],c[1])));y1=min(879,int(max(a[1],b[1],c[1]))+1)
  if x1<x0 or y1<y0:continue
  den=(b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
  if abs(den)<1e-8:continue
  yy,xx=np.mgrid[y0:y1+1,x0:x1+1]
  u=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/den
  v=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/den;ww=1-u-v
  with np.errstate(divide='ignore',invalid='ignore'):z=1/(u/a[2]+v/b[2]+ww/c[2])
  old=depth[y0:y1+1,x0:x1+1];mask=(u>=0)&(v>=0)&(ww>=0)&(z<old)&(z>0)
  old[mask]=z[mask];pixels[y0:y1+1,x0:x1+1][mask]=col
im=Image.fromarray(pixels);d=ImageDraw.Draw(im)
f=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',20)
d.rectangle((0,0,1200,74),fill='#23343d');d.text((24,14),'HOPEDALE TOWN HALL — custom exterior geometry',font=f,fill='white');d.text((24,43),'Offline geometry preview · approximate proportions · not a Studio screenshot',font=f,fill='#d4d9d2')
im.save(ROOT/'docs/previews/town-hall-model.png')
