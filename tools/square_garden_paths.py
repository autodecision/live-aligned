"""Square the installed garden loop without rebuilding its pond or furnishings."""
import bpy,json,runpy,hashlib,struct
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')

def build():
    assert Path(bpy.data.filepath)==ROOT/'assets/mediterranean_temple.blend'
    b=runpy.run_path(str(ROOT/'tools/build_south_garden.py'))
    trees=[b['height_bvh'](bpy.data.objects[n]) for n in ['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South']]
    def height(x,y):
        hits=[t.ray_cast(Vector((x,y,40)),Vector((0,0,-1)))[0] for t in trees]
        assert any(p is not None for p in hits),(x,y)
        return max(p.z for p in hits if p is not None)
    o=bpy.data.objects['SouthGarden_Gravel'];mats=list(o.data.materials)
    scope=b['build_paths'].__globals__;scope.update(BATCH={},COLLIDERS=[])
    b['build_paths'](height)
    verts,faces=scope['BATCH']['Garden_Gravel']
    mesh=bpy.data.meshes.new('Garden paving | square continuous loop');mesh.from_pydata(verts,[],faces);mesh.update()
    for m in mats:mesh.materials.append(m)
    uv=mesh.uv_layers.new(name='Pagoda matching stone tiles')
    for p in mesh.polygons:p.use_smooth=True
    for loop in mesh.loops:
        v=mesh.vertices[loop.vertex_index].co;uv.data[loop.index].uv=(v.x*.3,v.y*.3)
    o.data=mesh
    plan=json.loads((ROOT/'assets/south_garden.json').read_text())
    for i in range(4):plan['routes'][i]=[[x,z,-y] for x,y,z in b['ROUTES'][i]]
    refine=runpy.run_path(str(ROOT/'tools/refine_south_garden.py'))
    refine['sync_route_heights'](plan)
    # Re-seed grass tufts onto the lawn uncovered by tightening the top-left sidewalk.
    import random,math
    rows=json.loads((ROOT/'assets/gscatter_ground_cover_instances.json').read_text())
    rng=random.Random(9026)
    for _ in range(160):
        x,y=rng.uniform(80.0,92.0),rng.uniform(-25.4,-19.2)
        if b['path_field'](x,y)>-0.58:continue
        if any(math.hypot(x-px,y-py)<1.0 for px,py in [(90.2,-30.1),(85.0,-27.4),(82.65,-25.20)]):continue
        h=height(x,y)
        if h<3.8 or max(abs(height(x+.3,y)-height(x-.3,y)),abs(height(x,y+.3)-height(x,y-.3)))>.30:continue
        if any(math.hypot(x-r['origin'][0],y-(-r['origin'][2]))<0.38 for r in rows if r['origin'][0]>79 and r['origin'][2]>0):continue
        a=rng.random()*math.tau;s=rng.uniform(.78,1.06);c,sn=math.cos(a)*s,math.sin(a)*s
        rows.append({'asset':'GScatter_ShortSward_'+str(rng.randrange(3)),'origin':[x,h-.018,-y],
                     'basis':[[c,0,sn],[0,s,0],[-sn,0,c]],'blender_rotation':[0,0,a],'blender_scale':[s]*3,'south_garden':True})
    (ROOT/'assets/gscatter_ground_cover_instances.json').write_text(json.dumps(rows,separators=(',',':')))
    grass=refine['clear_grass'](b)
    plan['grass']['runtime_total']=grass['runtime_total']
    plan['square_sidewalk']={'outer_bounds_blender':[87.,119.5,-42.5,-25.5],'width_m':2.,'right_angle_corners':True,'tightened_top_left_arrival':True,'terrain_preserved':True,'grass_removed':grass['removed']+plan.get('square_sidewalk',{}).get('grass_removed',0)}
    for p in [ROOT/'assets/south_garden.json',OUT/'south_garden.json']:p.write_text(json.dumps(plan,indent=2))
    export=runpy.run_path(str(ROOT/'tools/polish_garden_site.py'))['export']
    export(ROOT/'assets/south_garden.glb',[o for o in bpy.data.collections[b['COLLECTION']].objects if not o.name.startswith('South_Koi_')])
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,'vertices':len(verts),'grass':grass['removed'],'plan':plan['square_sidewalk']}

def install():
    target=bpy.data.objects['SouthGarden_Gravel']
    with bpy.data.libraries.load(str(ROOT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):dst.objects=['SouthGarden_Gravel']
    imported=dst.objects[0];target.data=imported.data;bpy.data.objects.remove(imported,do_unlink=True)
    if Path(bpy.data.filepath).name!='south_garden.blend':
        b=runpy.run_path(str(ROOT/'tools/build_south_garden.py'));b['install_meadow'](json.loads((ROOT/'assets/gscatter_ground_cover_instances.json').read_text()))
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return audit()

def audit():
    o=bpy.data.objects['SouthGarden_Gravel'];h=hashlib.sha256()
    for v in o.data.vertices:h.update(struct.pack('fff',*v.co))
    # Every exposed edge around the garden proper must run along X or Y.
    counts={}
    for f in o.data.polygons:
        if f.normal.z<.5:continue
        for a,b in zip(f.vertices,list(f.vertices[1:])+[f.vertices[0]]):
            e=tuple(sorted((a,b)));counts[e]=counts.get(e,0)+1
    checked=0
    for (a,b),n in counts.items():
        if n!=1:continue
        p,q=o.data.vertices[a].co,o.data.vertices[b].co
        if max(p.y,q.y)>-25.5001:continue
        assert min(abs(p.x-q.x),abs(p.y-q.y))<1e-5,(tuple(p),tuple(q))
        checked+=1
    return {'saved':bpy.data.filepath,'sha256':h.hexdigest(),'axis_aligned_boundary_edges':checked,'vertices':len(o.data.vertices)}
