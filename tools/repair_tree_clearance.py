"""Find exact tree/solid triangle intersections and relocate onto clear supported soil."""
import bpy,json
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
removed=json.loads((ROOT/'assets/island_site_repairs.json').read_text()).get('removed_trees',[])
def is_tree(o):return o.type=='MESH' and any(m and 'island_tree' in m.name for m in o.data.materials)
def bounds(o):
 ps=[o.matrix_world@Vector(p) for p in o.bound_box]
 return [(min(p[i] for p in ps),max(p[i] for p in ps)) for i in range(3)]
def intersects(a,b):return all(a[i][0]<b[i][1] and a[i][1]>b[i][0] for i in range(3))
def bvh(o):
 # Trees and static obstacles are already baked meshes in the saved map.
 # Direct world-space triangles avoid repeatedly evaluating the whole scene.
 me=o.data
 return BVHTree.FromPolygons([o.matrix_world@p.co for p in me.vertices],[tuple(p.vertices) for p in me.polygons])
def scene_obstacles():
 obstacles=[]
 for o in bpy.data.objects:
  if o.type!='MESH' or o.hide_render or is_tree(o):continue
  if any(k in o.name for k in ['Terrain','Distant_Islands','Grass','grass','Ground','ground','Meadow','meadow','Landing_Bank','Water','water','Sea','Fall','Koi','Reed','Lily','Blossom','Moss']):continue
  if o.name.startswith('Lab_') or o.name.startswith('LabDetail'):continue
  obstacles.append((o,bounds(o)))
 return obstacles

def audit():
 obstacles=scene_obstacles();cache={};hits=[];count=0
 for o in bpy.data.objects:
  if not is_tree(o) or o.name.removesuffix('-convcol') in removed or o.hide_render:continue
  count+=1;box=bounds(o);candidates=[q for q,b in obstacles if intersects(box,b)]
  if not candidates:continue
  t=bvh(o)
  for q in candidates:
   if q.name not in cache:cache[q.name]=bvh(q)
   overlap=t.overlap(cache[q.name])
   if overlap:hits.append({'tree':o.name,'obstacle':q.name,'pairs':len(overlap)})
 return {'tree_count':count,'obstacles':len(obstacles),'hits':hits}

def repair(max_changes=4):
 import math
 from mathutils import Matrix
 obstacles=scene_obstacles();cache={};report=[]
 terrain=[(o,bvh(o)) for o in bpy.data.objects if o.name in ['Distant_Islands-col','Cliff_Terrain-col']]
 trees=[o for o in bpy.data.objects if is_tree(o) and o.name.removesuffix('-convcol') not in removed and not o.hide_render]
 def height(x,y):
  hits=[t.ray_cast(Vector((x,y,70)),Vector((0,0,-1)))[0] for o,t in terrain]
  hs=[p.z for p in hits if p is not None]
  return max(hs) if hs else None
 def collisions(o):
  bb=bounds(o);cs=[q for q,b in obstacles if intersects(bb,b)]
  if not cs:return []
  t=bvh(o);out=[]
  for q in cs:
   if q.name not in cache:cache[q.name]=bvh(q)
   if t.overlap(cache[q.name]):out.append(q.name)
  return out
 for o in trees:
  found=collisions(o)
  if not found:continue
  original=o.matrix_world.copy();pos=original.translation.copy()
  local_bottom=min((original@v.co).z-pos.z for v in o.data.vertices)
  fixed=False;attempts=0
  # Minimal displacement first; search a deterministic polar grid on dry soil.
  for radius in [i*.65 for i in range(1,19)]:
   for j in range(24):
    a=j*math.tau/24;xx=pos.x+math.cos(a)*radius;yy=pos.y+math.sin(a)*radius
    z=height(xx,yy)
    if z is None or z<.4:continue
    hs=[height(xx+math.cos(k*math.tau/8)*.30,yy+math.sin(k*math.tau/8)*.30) for k in range(8)]
    if any(h is None for h in hs) or max(hs)-min(hs)>1.1:continue
    if any(math.hypot(xx-p.matrix_world.translation.x,yy-p.matrix_world.translation.y)<1.7 for p in trees if p!=o):continue
    matrix=original.copy();matrix.translation=Vector((xx,yy,z-local_bottom-.055));o.matrix_world=matrix
    attempts+=1
    if not collisions(o):fixed=True;break
   if fixed:break
  assert fixed,'No clear supported site for '+o.name
  report.append({'name':o.name.removesuffix('-convcol'),'before_blender':list(pos),'blender_position':list(o.matrix_world.translation),'position':[o.matrix_world.translation.x,o.matrix_world.translation.z,-o.matrix_world.translation.y],'cleared_obstacles':found,'attempts':attempts})
  print('TREE_CLEAR',o.name,attempts,flush=True)
  Path('/tmp/tree_clearance_progress.json').write_text(json.dumps(report))
  if len(report)>=max_changes:break
 result={'batch_changes':len(report)}
 previous=ROOT/'assets/tree_clearance_repairs.json'
 existing=json.loads(previous.read_text())['trees'] if previous.exists() else []
 byname={r['name']:r for r in existing}
 byname.update({r['name']:r for r in report})
 report=list(byname.values())
 data={'description':'Final supported tree placements after solid geometry clearance audit','trees':report,'validation':result}
 (ROOT/'assets/tree_clearance_repairs.json').write_text(json.dumps(data,indent=2))
 # Keep earlier position overrides consistent with these final positions.
 byname={r['name']:r for r in report}
 for filename in ['island_site_repairs.json','bridge_approach_repairs.json','pagoda_sidewalk_repairs.json','south_garden.json']:
  path=ROOT/'assets'/filename;plan=json.loads(path.read_text())
  for key in ['trees','grounded_props']:
   for row in plan.get(key,[]):
    new=byname.get(row['name'])
    if new:
     row['position']=new['position']
     if 'blender_position' in row:row['blender_position']=new['blender_position']
  path.write_text(json.dumps(plan,indent=2))
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
 return {'saved':bpy.data.filepath,'relocated':len(report),'validation':result}

def install(validate=True):
 data=json.loads((ROOT/'assets/tree_clearance_repairs.json').read_text())
 for row in data['trees']:
  o=bpy.data.objects.get(row['name']) or bpy.data.objects.get(row['name']+'-convcol')
  assert o is not None,row['name'];o.location=row['blender_position']
 bpy.context.view_layer.update()
 result=audit() if validate else {'positions_applied':len(data['trees'])}
 if validate:assert not result['hits'],result['hits']
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
 return {'saved':bpy.data.filepath,'validation':result}
