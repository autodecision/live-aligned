"""Scoped sea-level shelves, volumetric outfall, idle instrument and rear lamp.
Run build_and_export in optimized map; install_saved in artistic map.
"""
import bpy
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT=Path(__file__).resolve().parent.parent
ART=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
PREVIEW=Path('/home/allister/Projects/live-aligned-previews/coast-outflow-2026-10-18')
NAMES=['Sea_Connected_Fall','Lab_Centrifuge_RPM']

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)

def terrain():
    o=bpy.data.objects['Distant_Islands-col'];o.data=o.data.copy()
    attr=o.data.attributes.get('coast_original_z')
    if attr is None:
        attr=o.data.attributes.new('coast_original_z','FLOAT','POINT')
        for v,a in zip(o.data.vertices,attr.data):a.value=v.co.z
    changed=0
    for v,a in zip(o.data.vertices,attr.data):
        z=a.value
        # The low gridded apron coincided with mean sea level (-5m). Sink it
        # below the lowest animated trough; feather only the underwater coast.
        t=max(0.,min(1.,(-3.-z)/2.))
        new=z-1.35*t*t*(3.-2.*t) if z>-8 else z
        if abs(v.co.z-new)>1e-6:changed+=1
        v.co.z=new
    o.data.update()
    return changed

def fall():
    o=bpy.data.objects['Sea_Connected_Fall'];mat=o.data.materials[0]
    vs=[];fs=[];nx=48;nr=40
    for j in range(nx+1):
        t=j/nx
        x=9.965+2.435*t;z=.145-5.695*t**1.65
        tangent=Vector((2.435,0,-5.695*1.65*max(t,.0001)**.65)).normalized()
        normal=Vector((-tangent.z,0,tangent.x))
        # A real oval cross section rolls over the sill, gathers toward the
        # center and thickens into an aerated jet instead of a paper ribbon.
        w=.55*(1.-.23*t);r=.055+.095*math.sin(math.pi*t*.75)
        for i in range(nr):
            a=i*math.tau/nr
            fold=(.012*math.sin(t*33+i*.8)+.007*math.sin(t*57-i*.6))*math.sin(math.pi*t)
            p=Vector((x,-7.45+w*math.cos(a),z))+normal*((r+fold)*math.sin(a))
            vs.append(tuple(p))
    for j in range(nx):
        for i in range(nr):
            a=j*nr+i;b=j*nr+(i+1)%nr
            fs.append((a,b,b+nr,a+nr))
    fs.append(tuple(reversed(range(nr))))
    fs.append(tuple(nx*nr+i for i in range(nr)))
    me=bpy.data.meshes.new('Outfall | closed rounded flowing volume');me.from_pydata(vs,[],fs);me.materials.append(mat);me.update()
    uv=me.uv_layers.new(name='Stream cross section and travel')
    for p in me.polygons:
        p.use_smooth=len(p.vertices)==4
        for li in p.loop_indices:
            idx=me.loops[li].vertex_index
            uv.data[li].uv=((idx%nr)/nr,(idx//nr)/nx)
    o.modifiers.clear();o.data=me
    o['outflow_volume']='Closed oval cross sections; feathered moving folds in Godot'


def lamp():
    land=bpy.data.objects['Cliff_Terrain-col'];tree=BVHTree.FromObject(land,bpy.context.evaluated_depsgraph_get())
    x,y=-2.,18.75
    heights=[]
    for i in range(32):
        a=i*math.tau/32
        p=tree.ray_cast(Vector((x+.245*math.cos(a),y+.245*math.sin(a),40)),Vector((0,0,-1)))[0]
        assert p is not None;heights.append(p.z)
    z=min(heights)-.025
    rows=json.loads((PROJECT/'assets/island_lantern_positions.json').read_text())
    row=next(r for r in rows if r['name']=='Coastal_Lantern_Main_05')
    row.update(blender_position=[x,y,z],position=[x,z,-y],footprint_height_range=max(heights)-min(heights),maximum_base_gap=-.025,adjustment='Rear temple lamp moved fully onto the grassy bank, clear of the plaza edge')
    for path in [PROJECT/'assets/island_lantern_positions.json',ART/'island_lantern_positions.json']:path.write_text(json.dumps(rows,indent=2))
    bpy.data.objects[row['name']].location=(x,y,z)
    return row

def report():
    result={'saved':bpy.data.filepath,'meshes':{}}
    for name in ['Distant_Islands',*NAMES]:
        o=bpy.data.objects.get(name) or bpy.data.objects.get(name+'-col')
        if o.type=='FONT':result['display']=o.data.body;continue
        h=hashlib.sha256()
        for v in o.data.vertices:h.update(struct.pack('fff',*v.co))
        result['meshes'][name]={'vertices':len(o.data.vertices),'sha256':h.hexdigest()}
    result['lamp']=list(bpy.data.objects['Coastal_Lantern_Main_05'].location)
    return result

def build_and_export():
    assert Path(bpy.data.filepath)==PROJECT/'assets/mediterranean_temple.blend'
    PREVIEW.mkdir(parents=True,exist_ok=True)
    changed=terrain();fall();row=lamp()
    bpy.data.objects['Lab_Centrifuge_RPM'].data.body='0000'
    bpy.context.view_layer.update()
    # Refresh the existing three-mesh override; bank meshes are unchanged.
    clones=[]
    for name in ['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South']:
        source=bpy.data.objects[name];o=source.copy();o.name='SouthGarden_'+name.removesuffix('-col');bpy.context.scene.collection.objects.link(o);clones.append(o)
    export(PROJECT/'assets/south_garden_terrain.glb',clones)
    for o in clones:bpy.data.objects.remove(o,do_unlink=True)
    # glTF needs evaluated mesh text, but retain editable FONT in both sources.
    text=bpy.data.objects['Lab_Centrifuge_RPM']
    me=bpy.data.meshes.new_from_object(text.evaluated_get(bpy.context.evaluated_depsgraph_get()))
    clone=bpy.data.objects.new('Idle_Centrifuge_Digits',me);bpy.context.scene.collection.objects.link(clone);clone.matrix_world=text.matrix_world.copy()
    export(PROJECT/'assets/coast_outflow_detail.glb',[bpy.data.objects['Sea_Connected_Fall'],clone])
    bpy.data.objects.remove(clone,do_unlink=True)
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    data=report();data.update(lowered_shelf_vertices=changed,lamp_placement=row)
    (PREVIEW/'build.json').write_text(json.dumps(data,indent=2));return data

def install_saved():
    targets={n:bpy.data.objects.get(n) or bpy.data.objects.get(n+'-col') for n in ['Distant_Islands',*NAMES]}
    names=['Distant_Islands-col',*NAMES]
    with bpy.data.libraries.load(str(PROJECT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):dst.objects=names
    for name,source in zip(targets,dst.objects):
        target=targets[name];assert target is not None,name
        target.data=source.data;target.modifiers.clear() if name=='Sea_Connected_Fall' else None
        bpy.data.objects.remove(source,do_unlink=True)
    row=next(r for r in json.loads((PROJECT/'assets/island_lantern_positions.json').read_text()) if r['name']=='Coastal_Lantern_Main_05')
    bpy.data.objects[row['name']].location=row['blender_position']
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return report()
