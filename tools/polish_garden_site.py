"""Scoped garden composition, pagoda paving, terrace rail return and cliff prop repair.
Build in optimized map through Blender MCP, then install in artistic source.
"""
import bpy,json,math,runpy,hashlib,struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent.parent
ART=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
LAMPS=[(90.2,-30.1),(90.2,-37.9),(104.41,-25.2),(104.41,-42.8),(116.,-25.2),(116.,-42.8)]

def export(path,os):
 bpy.ops.object.select_all(action='DESELECT')
 for o in os:o.hide_set(False);o.select_set(True)
 bpy.context.view_layer.objects.active=os[0]
 bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)

def build():
 b=runpy.run_path(str(ROOT/'tools/build_south_garden.py'))
 terrain=b['height_bvh'](bpy.data.objects['Distant_Islands-col'])
 def height(x,y):
  p=terrain.ray_cast(Vector((x,y,40)),Vector((0,0,-1)))[0]
  assert p is not None
  return p.z
 plan=json.loads((ROOT/'assets/south_garden.json').read_text())
 # Move the existing western lamp into a mirror pair across the pond axis.
 already=plan.get('composition',{}).get('stone_lanterns_blender')==[list(p) for p in LAMPS]
 if not already:
  old=(89.8,-43.5);new=(90.2,-37.9)
  delta=Vector((new[0]-old[0],new[1]-old[1],height(*new)-height(*old)))
  for name in ['SouthGarden_Dark_Stone','SouthGarden_Edge_Stone','SouthGarden_Lantern_Glow']:
   o=bpy.data.objects[name];o.data=o.data.copy();me=o.data
   for v in me.vertices:
    if abs(v.co.x-old[0])<.5 and abs(v.co.y-old[1])<.5:v.co+=delta
   # Mirror the middle southern lamp to add its missing northern partner.
   vs=[tuple(v.co) for v in me.vertices];fs=[tuple(p.vertices) for p in me.polygons]
   src={v.index for v in me.vertices if abs(v.co.x-104.41)<.5 and abs(v.co.y+42.8)<.5}
   shift=Vector((0,17.6,height(104.41,-25.2)-height(104.41,-42.8)))
   mapping={i:len(vs)+k for k,i in enumerate(sorted(src))}
   vs.extend(tuple(me.vertices[i].co+shift) for i in sorted(src))
   fs.extend(tuple(mapping[i] for i in p.vertices) for p in me.polygons if all(i in src for i in p.vertices))
   mesh=bpy.data.meshes.new(name+' | paired lanterns');mesh.from_pydata(vs,[],fs)
   for m in me.materials:mesh.materials.append(m)
   mesh.update();o.data=mesh
  for row in plan['colliders'][:]:
   if row['type']!='box':continue
   c=row['center']
   if abs(c[0]-old[0])<.5 and abs(c[1]-old[1])<.5:row['center']=[c[i]+delta[i] for i in range(3)]
   if abs(c[0]-104.41)<.5 and abs(c[1]+42.8)<.5:
    clone=json.loads(json.dumps(row));clone['center']=[c[0],c[1]+17.6,c[2]+height(104.41,-25.2)-height(104.41,-42.8)];plan['colliders'].append(clone)
 plan['lights']=[[x,height(x,y)+1.16,-y] for x,y in LAMPS]
 # Reuse the exact pagoda paving texture and 0.3 UV/metre repeat.
 o=bpy.data.objects['SouthGarden_Gravel'];o.data=o.data.copy()
 mat=bpy.data.objects['North_Pagoda_Pagoda_Sidewalk'].data.materials[0].copy();mat.name='Garden | pagoda limestone paving'
 for node in mat.node_tree.nodes:
  if node.type=='TEX_IMAGE' and node.image:
   path=ROOT/'assets/textures'/Path(node.image.filepath).name
   assert path.exists(),str(path)
   node.image=bpy.data.images.load(str(path),check_existing=True)
 o.data.materials.clear();o.data.materials.append(mat)
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='Pagoda matching stone tiles')
 for loop in o.data.loops:
  p=o.matrix_world@o.data.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(p.x*.3,p.y*.3)
 # Extend the front rail around the corner, along the existing cement edge.
 name='Temple_Terrace_Guard_Return'
 oldobj=bpy.data.objects.get(name)
 if oldobj:bpy.data.objects.remove(oldobj,do_unlink=True)
 vs=[];fs=[]
 def box(c,s):
  n=len(vs);vs.extend((c[0]+x*s[0]/2,c[1]+y*s[1]/2,c[2]+z*s[2]/2) for x,y,z in [(-1,-1,-1),(-1,-1,1),(-1,1,-1),(-1,1,1),(1,-1,-1),(1,-1,1),(1,1,-1),(1,1,1)])
  fs.extend(tuple(n+i for i in f) for f in [(0,4,6,2),(1,3,7,5),(0,1,5,4),(2,6,7,3),(0,2,3,1),(4,5,7,6)])
 # The rail reaches x=-2.5, where the transverse cement strip meets the approach.
 box((3.3,-11.8,.95),(11.92,.32,.10))
 for x in [-2.35,-.35,1.65,3.65,5.65,7.65,9.1]:box((x,-11.8,.5),(.26,.26,.90))
 me=bpy.data.meshes.new(name);me.from_pydata(vs,[],fs);me.materials.append(bpy.data.objects['Balustrades_With_Outfall_Notch'].data.materials[0]);me.update()
 uv=me.uv_layers.new(name='Stone metres')
 for p in me.polygons:
  for li in p.loop_indices:
   q=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(q.x*.65,(q.y if abs(p.normal.z)>.5 else q.z)*.65)
 rail=bpy.data.objects.new(name,me);bpy.context.scene.collection.objects.link(rail)
 export(ROOT/'assets/temple_terrace_guard.glb',[rail])
 rock=bpy.data.objects['Large_Rock_South_02-convcol'];rock.hide_render=True;rock.hide_set(True);rock['removed_unrooted_cliff_rock']=True
 plan['composition']={'stone_lanterns_blender':[list(p) for p in LAMPS],'mirror_axis_blender_y':-34.,'paving_uv_per_metre':.3,'paving_matches':'North_Pagoda_Pagoda_Sidewalk','removed_props':['Large_Rock_South_02']}
 for file in [ROOT/'assets/south_garden.json',ART/'south_garden.json']:file.write_text(json.dumps(plan,indent=2))
 export(ROOT/'assets/south_garden.glb',[o for o in bpy.data.collections['South Koi and Zen Garden'].objects if not o.name.startswith('South_Koi_')])
 bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
 return {'saved':bpy.data.filepath,'lanterns':len(LAMPS),'rail_length':11.92,'removed_rock':rock.name}

def install():
 # Copy the changed garden collection and new guard, leaving the whole map intact.
 col=bpy.data.collections['South Koi and Zen Garden']
 for o in list(col.objects):bpy.data.objects.remove(o,do_unlink=True)
 bpy.data.collections.remove(col)
 o=bpy.data.objects.get('Temple_Terrace_Guard_Return')
 if o:bpy.data.objects.remove(o,do_unlink=True)
 with bpy.data.libraries.load(str(ROOT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):
  dst.collections=['South Koi and Zen Garden'];dst.objects=['Temple_Terrace_Guard_Return']
 bpy.context.scene.collection.children.link(dst.collections[0]);bpy.context.scene.collection.objects.link(dst.objects[0])
 rock=bpy.data.objects.get('Large_Rock_South_02') or bpy.data.objects.get('Large_Rock_South_02-convcol');rock.hide_render=True;rock.hide_set(True)
 lab=runpy.run_path(str(ROOT/'tools/detail_lab_props.py'));lab['install_saved']()
 return {'saved':bpy.data.filepath}
