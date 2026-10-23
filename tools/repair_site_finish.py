"""Repair the installed garden arrivals, west corner and temple pool, in scope.

Run build_and_export in the optimized map, then install_saved in the artistic
map and save_standalone from the garden builder in a fresh optimized-map read.
The original base GLB and northern island are preserved.
"""
import hashlib
import json
import math
import runpy
import struct
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
PREVIEW = Path('/home/allister/Projects/live-aligned-previews/site-finish-2026-10-18')
POOL_NAMES = ('Ancient_Column_Drums-col', 'Lower_Pool_Water_Fitted', 'Outfall_Contained_Water')
LANTERNS = ((90.2,-30.1),(116.,-25.2),(116.,-42.8),(104.41,-42.8),(89.8,-43.5))


def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3.-2.*t)


def arrival_height(x,y):
    # Broad, monotonic ramps, with level, full-width thresholds at both decks.
    main=4.735+.815*(1.-smooth(79.65,88.,x))
    inward=(x-87.)*.275+(y+18.75)*-.96
    across=(x-87.)*.96+(y+18.75)*.275
    north=(1.-smooth(2.5,5.,abs(across)))*(1.-smooth(0.,5.2,inward))
    return main*(1.-north)+4.10*north


def grade_ground(builder):
    report={}
    for name in ['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South']:
        obj=bpy.data.objects[name]
        obj.data=obj.data.copy()
        inverse=obj.matrix_world.inverted()
        changed=0
        for vertex in obj.data.vertices:
            p=obj.matrix_world@vertex.co
            if p.y>=0:continue
            original=p.z
            # A grassy shoulder wraps the west corner, then falls naturally to
            # the sea. The existing pond excavation remains outside this patch.
            if name=='Distant_Islands-col' and p.x<94 and p.y<-36:
                r=math.hypot((p.x-87.0)/9.0,(p.y+42.0)/7.3)
                terrace=4.65-9.65*smooth(.57,1.25,r)
                p.z=max(p.z,terrace)
            if p.x<93 and p.y>-29.5:
                field=builder['path_field'](p.x,p.y)
                influence=1.-smooth(.35,3.,-field)
                # Keep terrain below the bridge deck on its sea-facing side.
                inward=(p.x-87.)*.275+(p.y+18.75)*-.96
                if p.x<79.25 or (p.x>84.5 and inward<0.):
                    influence=0.
                edge=smooth(-29.5,-27.8,p.y)
                influence*=edge
                target=arrival_height(p.x,p.y)-.085
                p.z=p.z*(1.-influence)+target*influence
            if abs(p.z-original)>1e-6:
                vertex.co=inverse@p
                changed+=1
        obj.data.update()
        report[name]=changed
    return report


def export_selected(path, objects):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',
        use_selection=True,export_animations=False,export_cameras=False,export_lights=False)


def texture_fragments():
    obj=bpy.data.objects['Ancient_Column_Drums-col']
    if len(obj.data.vertices)>100 and obj.data.uv_layers:
        return {'vertices':len(obj.data.vertices),'uv_loops':len(obj.data.uv_layers.active.data)}
    # These fragments had no UV layer at all; glTF sampled one pale texel.
    obj.data=obj.data.copy()
    uv=obj.data.uv_layers.new(name='Quarried stone UV')
    for face in obj.data.polygons:
        axis=max(range(3),key=lambda k:abs(face.normal[k]))
        axes=[i for i in range(3) if i!=axis]
        for loop in face.loop_indices:
            p=obj.matrix_world@obj.data.vertices[obj.data.loops[loop].vertex_index].co
            uv.data[loop].uv=(p[axes[0]]*.65,p[axes[1]]*.65)
        face.use_smooth=False
    mat=bpy.data.materials.new('Column fragments | veined weathered marble')
    mat.use_nodes=True
    nodes=mat.node_tree.nodes;links=mat.node_tree.links
    bsdf=nodes.get('Principled BSDF')
    bsdf.inputs['Roughness'].default_value=.88
    for suffix,socket in [('Diffuse','Base Color'),('Rough','Roughness')]:
        tex=nodes.new('ShaderNodeTexImage')
        tex.image=bpy.data.images.load(str(PROJECT/f'assets/textures/marble_01_{suffix}_2k.jpg'),check_existing=True)
        if suffix=='Rough':tex.image.colorspace_settings.name='Non-Color'
        links.new(tex.outputs['Color'],bsdf.inputs[socket])
    tex=nodes.new('ShaderNodeTexImage')
    tex.image=bpy.data.images.load(str(PROJECT/'assets/textures/marble_01_nor_gl_2k.jpg'),check_existing=True)
    tex.image.colorspace_settings.name='Non-Color'
    normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.65
    links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs['Normal'],bsdf.inputs['Normal'])
    obj.data.materials.clear();obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active=obj
    bevel=obj.modifiers.new('Worn fragment edges','BEVEL');bevel.width=.018;bevel.segments=3
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    return {'vertices':len(obj.data.vertices),'uv_loops':len(obj.data.uv_layers.active.data)}


def water_grid(obj,xs,ys):
    # The two grids share the exact pool-outlet seam, including its subdivisions.
    vertices=[(x,y,.20) for y in ys for x in xs]
    faces=[];nx=len(xs)
    for j in range(len(ys)-1):
        for i in range(nx-1):
            a=j*nx+i;faces.append((a,a+1,a+nx+1,a+nx))
    mats=list(obj.data.materials)
    me=bpy.data.meshes.new(obj.name+' | connected level water')
    me.from_pydata(vertices,[],faces);me.update()
    for mat in mats:me.materials.append(mat)
    obj.data=me
    obj.modifiers.clear()
    uv=me.uv_layers.new(name='UVMap')
    for p in me.polygons:
        for li in p.loop_indices:
            v=me.vertices[me.loops[li].vertex_index].co
            uv.data[li].uv=(v.x*.2,v.y*.2)


def repair_water():
    def steps(a,b,n):return [a+(b-a)*i/n for i in range(n+1)]
    seam=steps(-8.,-6.9,12)
    ys=steps(-10.10,-8.,16)[:-1]+seam+steps(-6.9,-4.90,16)[1:]
    water_grid(bpy.data.objects['Lower_Pool_Water_Fitted'],steps(1.995,6.70,40),ys)
    water_grid(bpy.data.objects['Outfall_Contained_Water'],steps(6.70,9.98,32),seam)
    return {'seam_x':6.70,'seam_y':[-8.,-6.9],'level':.20,'shared_seam_vertices':len(seam)}


def reseat_coastal_posts():
    """Seat the nearby coast posts after grading; keep the new apron clear."""
    builder=runpy.run_path(str(PROJECT/'tools/build_south_garden.py'))
    tree=builder['height_bvh'](bpy.data.objects['Distant_Islands-col'])
    path=PROJECT/'assets/island_lantern_positions.json'
    rows=json.loads(path.read_text());changed=[]
    for row in rows:
        if not row['name'].startswith('Coastal_Lantern_South_'):continue
        x,y,_=row['blender_position']
        if row['name']=='Coastal_Lantern_South_03':x,y=85.,-27.4
        assert builder['path_field'](x,y)<-.35,'Coast post overlaps paving'
        hs=[]
        for j in range(32):
            a=j*math.tau/32
            p=tree.ray_cast(Vector((x+.245*math.cos(a),y+.245*math.sin(a),40)),Vector((0,0,-1)))[0]
            assert p is not None
            hs.append(p.z)
        z=min(hs)-.025
        row.update(blender_position=[x,y,z],position=[x,z,-y],
            footprint_height_range=max(hs)-min(hs),maximum_base_gap=-.025)
        obj=bpy.data.objects[row['name']];obj.location=(x,y,z)
        changed.append(row['name'])
    for file in [path,OUT/'island_lantern_positions.json']:
        file.write_text(json.dumps(rows,indent=2))
    return changed


def build_and_export():
    assert Path(bpy.data.filepath)==PROJECT/'assets/mediterranean_temple.blend'
    PREVIEW.mkdir(parents=True,exist_ok=True)
    builder=runpy.run_path(str(PROJECT/'tools/build_south_garden.py'))
    report={'ground_vertices_graded':grade_ground(builder)}
    trees=[builder['height_bvh'](bpy.data.objects[n]) for n in
           ['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South']]
    def height(x,y):
        hits=[t.ray_cast(Vector((x,y,40)),Vector((0,0,-1)))[0] for t in trees]
        return max(p.z for p in hits if p is not None)
    # Rebuild the existing path and only the five lantern assemblies, retaining
    # the refined pond, coping, sand stones, fish, deck, benches and vegetation.
    gravel=bpy.data.objects['SouthGarden_Gravel']
    bpy.data.objects.remove(gravel,do_unlink=True)
    scope=builder['build_paths'].__globals__
    scope.update(COL=bpy.data.collections['South Koi and Zen Garden'],BATCH={},COLLIDERS=[])
    scope['M'].update({k:bpy.data.materials[k] for k in ['Garden_Gravel']})
    builder['build_paths'](height)
    v,f=scope['BATCH']['Garden_Gravel']
    # The old builder's x>84.5 endpoint clamp created a vertical crease through
    # the apron. Use the continuous ramp across its whole width and both flares.
    top={i for face in f if len(face)==3 for i in face}
    for i in top:
        x,y,z=v[i]
        if x<93 and y>-29.5:
            blend=smooth(-29.5,-27.8,y)
            v[i]=(x,y,z*(1.-blend)+arrival_height(x,y)*blend)
    gravel=builder['addmesh']('SouthGarden_Gravel',v,f,'Garden_Gravel')
    for p in gravel.data.polygons:p.use_smooth=True
    plan=json.loads((PROJECT/'assets/south_garden.json').read_text())
    # Translate the last batched stone lantern, as well as its simple collision.
    delta=Vector((2.0,-2.4,height(89.8,-43.5)-height(87.8,-41.1)))
    count=0
    for name in ['SouthGarden_Dark_Stone','SouthGarden_Edge_Stone','SouthGarden_Lantern_Glow']:
        obj=bpy.data.objects[name];obj.data=obj.data.copy()
        for vertex in obj.data.vertices:
            p=vertex.co
            if abs(p.x-87.8)<.5 and abs(p.y+41.1)<.5:
                vertex.co+=delta;count+=1
        obj.data.update()
    for row in plan['colliders']:
        if row['type']=='box' and abs(row['center'][0]-87.8)<.5 and abs(row['center'][1]+41.1)<.5:
            row['center']=[row['center'][i]+delta[i] for i in range(3)]
    for row in plan['lights']:
        if abs(row[0]-87.8)<.5 and abs(row[2]-41.1)<.5:
            row[:]=[row[0]+delta.x,row[1]+delta.z,row[2]-delta.y]
    report['lantern_vertices_moved']=count
    plan['grounded_props']=builder['reseat_props'](height)
    report['reseated_coastal_posts']=reseat_coastal_posts()
    refine=runpy.run_path(str(PROJECT/'tools/refine_south_garden.py'))
    refine['sync_route_heights'](plan)
    rows=json.loads((PROJECT/'assets/gscatter_ground_cover_instances.json').read_text())
    kept=[]
    for row in rows:
        x,y=row['origin'][0],-row['origin'][2]
        if x>69 and y<0:
            margin=.42*max(row.get('blender_scale',[1,1,1]))+.12
            if builder['path_field'](x,y)>-margin or any(math.hypot(x-a,y-b)<.65+margin for a,b in LANTERNS):continue
            row['origin'][1]=height(x,y)-.018
        kept.append(row)
    (PROJECT/'assets/gscatter_ground_cover_instances.json').write_text(json.dumps(kept,separators=(',',':')))
    builder['install_meadow'](kept)
    plan['grass']['runtime_total']=len(kept)
    report['grass_removed']=len(rows)-len(kept)
    report['column_fragments']=texture_fragments()
    report['water_connection']=repair_water()
    plan['site_finish']={'lantern_corner':[89.8,4.65,43.5],
        'clear_tree':'Island_South_Olive_11','continuous_arrival_grades':True,
        'expanded_west_shoulder':True,'report':report}
    for path in [PROJECT/'assets/south_garden.json',OUT/'south_garden.json']:
        path.write_text(json.dumps(plan,indent=2))
    col=bpy.data.collections['South Koi and Zen Garden']
    export_selected(PROJECT/'assets/south_garden.glb',[o for o in col.objects if not o.name.startswith('South_Koi_')])
    clones=[]
    for name in ['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South']:
        original=bpy.data.objects[name];clone=original.copy();clone.data=original.data.copy()
        clone.name='SouthGarden_'+name.replace('-col','');bpy.context.scene.collection.objects.link(clone)
        clones.append(clone)
    export_selected(PROJECT/'assets/south_garden_terrain.glb',clones)
    for obj in clones:bpy.data.objects.remove(obj,do_unlink=True)
    export_selected(PROJECT/'assets/temple_pool_finish.glb',[bpy.data.objects[n] for n in POOL_NAMES])
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    (PREVIEW/'build.json').write_text(json.dumps(report,indent=2))
    return {'saved':bpy.data.filepath,**report}


def install_saved():
    assert Path(bpy.data.filepath)==OUT/'mediterranean_temple_improved.blend'
    names=['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South',*POOL_NAMES]
    old=bpy.data.collections['South Koi and Zen Garden']
    for obj in list(old.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(old)
    targets={n.replace('-col',''):bpy.data.objects.get(n.replace('-col','')) or bpy.data.objects.get(n) for n in names}
    with bpy.data.libraries.load(str(PROJECT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):
        dst.objects=list(names);dst.collections=['South Koi and Zen Garden']
    bpy.context.scene.collection.children.link(dst.collections[0])
    for name,source in zip(names,dst.objects):
        target=targets[name.replace('-col','')]
        assert target is not None,name
        target.data=source.data;target.matrix_world=source.matrix_world.copy()
        if name in POOL_NAMES:target.modifiers.clear()
        bpy.data.objects.remove(source,do_unlink=True)
    plan=json.loads((PROJECT/'assets/south_garden.json').read_text())
    for row in plan['grounded_props']:
        target=bpy.data.objects.get(row['name']) or bpy.data.objects.get(row['name']+'-convcol')
        if target:target.location=row['blender_position']
    for row in json.loads((PROJECT/'assets/island_lantern_positions.json').read_text()):
        if row['name'].startswith('Coastal_Lantern_South_'):
            bpy.data.objects[row['name']].location=row['blender_position']
    builder=runpy.run_path(str(PROJECT/'tools/build_south_garden.py'))
    builder['install_meadow'](json.loads((PROJECT/'assets/gscatter_ground_cover_instances.json').read_text()))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath}


def validate_saved():
    """Fingerprint the reopened deliverables, not the in-memory build state."""
    result={'saved':bpy.data.filepath,'meshes':{}}
    for name in ['Distant_Islands','Landing_Bank_Main_South','Landing_Bank_North_South','SouthGarden_Gravel',*POOL_NAMES]:
        obj=bpy.data.objects.get(name) or bpy.data.objects.get(name+'-col')
        if obj is None:obj=bpy.data.objects.get(name.replace('-col',''))
        assert obj is not None,name
        h=hashlib.sha256()
        for v in obj.data.vertices:h.update(struct.pack('fff',*v.co))
        result['meshes'][name]={'vertices':len(obj.data.vertices),'sha256':h.hexdigest()}
    for name in ['Island_South_Olive_02','Island_South_Olive_11']:
        obj=bpy.data.objects.get(name) or bpy.data.objects.get(name+'-convcol')
        result[name]=list(obj.location)
    ground=bpy.data.objects.get('Distant_Islands-col') or bpy.data.objects.get('Distant_Islands')
    def north_fingerprint(obj):
        h=hashlib.sha256();count=0
        for v in obj.data.vertices:
            p=obj.matrix_world@v.co
            if p.y>=0:
                h.update(struct.pack('fff',*p));count+=1
        return count,h.hexdigest()
    backup=Path('/home/allister/Backups/live-aligned/site-finish-20261018')/str(Path(bpy.data.filepath)).lstrip('/')
    current_north=north_fingerprint(ground)
    with bpy.data.libraries.load(str(backup),link=False) as (src,dst):
        dst.objects=[ground.name]
    original=dst.objects[0]
    assert north_fingerprint(original)==current_north,'Northern terrain changed'
    bpy.data.objects.remove(original,do_unlink=True)
    result['northern_terrain_unchanged']=True
    result['northern_vertices']=current_north[0]
    path=bpy.data.objects['SouthGarden_Gravel']
    slopes=[p.normal.z for p in path.data.polygons if len(p.vertices)==3 and p.center.x<93 and p.center.y>-27.8]
    result['minimum_arrival_up_normal']=min(slopes)
    result['maximum_arrival_slope_degrees']=math.degrees(math.acos(min(slopes)))
    assert min(slopes)>math.cos(math.radians(40.)),'Arrival paving exceeds 40 degrees'
    # Only the affected lanterns: canopy clearance at the eastern lamp, and
    # the moved western lamp. Other trees continue sharing their original mesh.
    intersections=[]
    for x,y in [(116.,-25.2),(89.8,-43.5)]:
        base=4.65 if x<100 else 4.64
        for obj in bpy.data.objects:
            if not obj.name.startswith('Island_South_Olive_') or obj.type!='MESH':continue
            corners=[obj.matrix_world@Vector(c) for c in obj.bound_box]
            if max(p.x for p in corners)<x-.4 or min(p.x for p in corners)>x+.4:continue
            if max(p.y for p in corners)<y-.4 or min(p.y for p in corners)>y+.4:continue
            for v in obj.data.vertices:
                p=obj.matrix_world@v.co
                if abs(p.x-x)<.4 and abs(p.y-y)<.4 and base-.25<p.z<base+1.65:
                    intersections.append(obj.name);break
    assert not intersections,intersections
    result['tree_lantern_intersections']=intersections
    return result
