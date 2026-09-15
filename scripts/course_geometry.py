"""Fictional closed parkway: deliberately designed for driving, not an OSM road."""
import math

def add_course(nodes,roads):
 course=[]
 for i in range(96):
  a=2*math.pi*i/96
  node=-1000-i;nodes[node]=[690+230*math.cos(a),390+310*math.sin(a)];course.append(node)
 course.append(course[0])
 roads.append({'id':-1,'name':'Redline Parkway','oneway':'no','tags':{'fictional':'yes'},'segments':[list(pair) for pair in zip(course,course[1:])]})
 # Join the existing eastern Adin endpoint with a gradual approach to the oval.
 endpoint=max((n for r in roads if r['name']=='Adin Street' for seg in r['segments'] for n in seg),key=lambda n:nodes[n][0])
 join=course[60]
 a,b=nodes[endpoint],nodes[join]
 connector=[endpoint]
 for i in range(1,9):
  t=i/9;node=-2000-i;nodes[node]=[a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t];connector.append(node)
 connector.append(join)
 roads.append({'id':-2,'name':'Parkway Access','oneway':'no','tags':{'fictional':'yes'},'segments':[list(pair) for pair in zip(connector,connector[1:])]})
 # A smaller mill service circuit with two genuinely connected exits. All authored.
 service=[]
 for i in range(32):
  a=2*math.pi*i/32;node=-3000-i
  nodes[node]=[400+50*math.cos(a),560+100*math.sin(a)];service.append(node)
 service.append(service[0])
 roads.append({'id':-3,'name':'Mill Service Loop','oneway':'no','tags':{'fictional':'yes','half_width':4.5},'segments':[list(p) for p in zip(service,service[1:])]})
 def link(rid,name,anchors):
  ids=[]
  for segment,(a,b) in enumerate(zip(anchors,anchors[1:])):
   ids.append(a)
   length=math.dist(nodes[a],nodes[b]);steps=max(1,math.ceil(length/20))
   for j in range(1,steps):
    node=rid*1000-segment*100-j;t=j/steps
    nodes[node]=[nodes[a][k]+(nodes[b][k]-nodes[a][k])*t for k in range(2)];ids.append(node)
  ids.append(anchors[-1])
  roads.append({'id':rid,'name':name,'oneway':'no','tags':{'fictional':'yes','half_width':4.5},'segments':[list(p) for p in zip(ids,ids[1:])]})
 # This surveyed-data clearance waypoint keeps the new connector outside building shells.
 nodes[-3999]=[312.8232115317798,492.6808275991733]
 link(-4,'Centennial Mill Access',[63038498,-3999,service[16]])
 link(-5,'North Parkway Access',[service[4],course[36]])
 # Tight paved cut-through is a player escape option; traffic uses the perimeter.
 link(-6,'Mill Yard Cut-through',[service[8],service[24]])
 return course,service
