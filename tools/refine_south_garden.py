"""Scoped, repeatable repair of the already installed south garden.

Run refine_and_export() in the optimized map, save_standalone() in a fresh
process, then install_refinement() in the artistic map. Terrain is preserved.
"""
import bpy
import json
import math
import runpy
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
PREVIEW=Path('/home/allister/Projects/live-aligned-previews/south-garden-refinement-2026-10-15')
COLLECTION='South Koi and Zen Garden'


def hull2(points):
    points=sorted(set(points))
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    lower=[];upper=[]
    for p in points:
        while len(lower)>1 and cross(lower[-2],lower[-1],p)<=0:lower.pop()
        lower.append(p)
    for p in reversed(points):
        while len(upper)>1 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
        upper.append(p)
    return lower[:-1]+upper[:-1]


def inside_margin(x,y,poly,margin):
    # Convex rock footprint enlarged by the whole grass tuft, not its origin.
    for a,b in zip(poly,poly[1:]+poly[:1]):
        if ((b[0]-a[0])*(y-a[1])-(b[1]-a[1])*(x-a[0])) < -margin*math.dist(a,b):return False
    return True


def rock_footprints():
    return [hull2([(round(p.x,5),round(p.y,5)) for p in [o.matrix_world@v.co for v in o.data.vertices]])
            for o in bpy.data.objects if o.name.startswith('Large_Rock_South_') and o.type=='MESH']


def clear_grass(builder):
    footprints=rock_footprints();rows=json.loads((PROJECT/'assets/gscatter_ground_cover_instances.json').read_text());kept=[]
    for row in rows:
        x,y=row['origin'][0],-row['origin'][2]
        scale=max(row.get('blender_scale',[1,1,1]));margin=.42*scale+.12
        if x>69 and y<0 and (builder['path_field'](x,y)>-margin or any(inside_margin(x,y,p,margin) for p in footprints)):
            continue
        kept.append(row)
    (PROJECT/'assets/gscatter_ground_cover_instances.json').write_text(json.dumps(kept,separators=(',',':')))
    builder['install_meadow'](kept)
    return {'removed':len(rows)-len(kept),'runtime_total':len(kept),'rock_footprints':footprints}


def source_stone_materials():
    for key in ['Garden_Contemplation_Rock','Garden_Edge_Stone']:
        mat=bpy.data.materials[key];nodes=mat.node_tree.nodes;links=mat.node_tree.links
        nodes.clear()
        p=nodes.new('ShaderNodeBsdfPrincipled');p.location=(400,0)
        out=nodes.new('ShaderNodeOutputMaterial');out.location=(650,0)
        links.new(p.outputs['BSDF'],out.inputs['Surface'])
        if key=='Garden_Contemplation_Rock':
            p.inputs['Base Color'].default_value=(.18,.21,.19,1)
            p.inputs['Roughness'].default_value=.88
            tex_path=str(PROJECT/'assets/textures/coastal_rock_grey.jpg')
            norm_path=str(PROJECT/'assets/textures/coastal_rock_normal.png')
            if Path(tex_path).exists() and Path(norm_path).exists():
                img_tex=bpy.data.images.load(tex_path,check_existing=True)
                img_norm=bpy.data.images.load(norm_path,check_existing=True)
                img_norm.colorspace_settings.name='Non-Color'
                node_tex=nodes.new('ShaderNodeTexImage');node_tex.image=img_tex;node_tex.location=(-200,200)
                node_norm=nodes.new('ShaderNodeTexImage');node_norm.image=img_norm;node_norm.location=(-200,-200)
                node_norm_map=nodes.new('ShaderNodeNormalMap');node_norm_map.location=(100,-200)
                node_coord=nodes.new('ShaderNodeTexCoord');node_coord.location=(-600,0)
                node_mapping=nodes.new('ShaderNodeMapping');node_mapping.location=(-400,0)
                node_mapping.inputs['Scale'].default_value=(.4,.4,.4)
                links.new(node_coord.outputs['Object'],node_mapping.inputs['Vector'])
                links.new(node_mapping.outputs['Vector'],node_tex.inputs['Vector'])
                links.new(node_mapping.outputs['Vector'],node_norm.inputs['Vector'])
                links.new(node_tex.outputs['Color'],p.inputs['Base Color'])
                links.new(node_norm.outputs['Color'],node_norm_map.inputs['Color'])
                links.new(node_norm_map.outputs['Normal'],p.inputs['Normal'])
        else:
            p.inputs['Base Color'].default_value=(.18,.21,.19,1)
            tex=nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=5.2;tex.inputs['Detail'].default_value=4.2;tex.inputs['Roughness'].default_value=.72
            ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.18;ramp.color_ramp.elements[0].color=(.055,.065,.055,1);ramp.color_ramp.elements[1].position=.8;ramp.color_ramp.elements[1].color=(.30,.32,.28,1)
            links.new(tex.outputs['Fac'],ramp.inputs['Fac']);links.new(ramp.outputs['Color'],p.inputs['Base Color'])
            bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.32;bump.inputs['Distance'].default_value=.045
            links.new(tex.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])


def sync_route_heights(plan):
    path=bpy.data.objects['SouthGarden_Gravel']
    tree=BVHTree.FromPolygons([v.co for v in path.data.vertices],[tuple(p.vertices) for p in path.data.polygons])
    for route in plan['routes']:
        for point in route:
            hit=tree.ray_cast(Vector((point[0],-point[2],40)),Vector((0,0,-1)))[0]
            assert hit is not None,point
            point[1]=hit.z
    return plan


def refine_and_export():
    assert Path(bpy.data.filepath)==PROJECT/'assets/mediterranean_temple.blend'
    builder=runpy.run_path(str(PROJECT/'tools/build_south_garden.py'));build=builder['build_static'];scope=build.__globals__
    ground=bpy.data.objects['Distant_Islands-col']
    terrains=[builder['height_bvh'](bpy.data.objects[n]) for n in ['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South']]
    def height(x,y):
        hits=[t.ray_cast(Vector((x,y,40)),Vector((0,0,-1)))[0] for t in terrains]
        heights=[p.z for p in hits if p is not None]
        assert heights,(x,y)
        return max(heights)
    col=bpy.data.collections[COLLECTION]
    for obj in list(col.objects):
        if not obj.name.startswith('South_Koi_'):bpy.data.objects.remove(obj,do_unlink=True)
    scope.update(COL=col,BATCH={},COLLIDERS=[]);builder['setup_materials']();lights=build(height)
    source_stone_materials()
    grounded_props=builder['reseat_props'](height)
    plan=json.loads((PROJECT/'assets/south_garden.json').read_text());plan['colliders']=scope['COLLIDERS'];plan['lights']=lights;plan['grounded_props']=grounded_props
    sync_route_heights(plan)
    plan['refinement']={'continuous_paths':True,'terrain_following_step_m':.125,'deck_opening':True,'quarried_coping':True,'detailed_zen_stones':True,'grass':clear_grass(builder)}
    plan['grass']['runtime_total']=plan['refinement']['grass']['runtime_total']
    for path in [PROJECT/'assets/south_garden.json',OUT/'south_garden.json']:path.write_text(json.dumps(plan,indent=2))
    bpy.ops.object.select_all(action='DESELECT')
    for obj in col.objects:
        if not obj.name.startswith('South_Koi_'):obj.select_set(True)
    bpy.context.view_layer.objects.active=bpy.data.objects['SouthGarden_Gravel']
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/south_garden.glb'),export_format='GLB',use_selection=True,export_animations=False)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,'path_vertices':len(bpy.data.objects['SouthGarden_Gravel'].data.vertices),'rock_vertices':len(bpy.data.objects['SouthGarden_Contemplation_Rock'].data.vertices),'refinement':plan['refinement']}


def install_refinement():
    assert Path(bpy.data.filepath)==OUT/'mediterranean_temple_improved.blend'
    old=bpy.data.collections[COLLECTION]
    for obj in list(old.objects):bpy.data.objects.remove(obj,do_unlink=True)
    bpy.data.collections.remove(old)
    with bpy.data.libraries.load(str(OUT/'south_garden.blend'),link=False) as (src,dst):dst.collections=[COLLECTION]
    bpy.context.scene.collection.children.link(dst.collections[0])
    builder=runpy.run_path(str(PROJECT/'tools/build_south_garden.py'))
    builder['install_meadow'](json.loads((PROJECT/'assets/gscatter_ground_cover_instances.json').read_text()))
    artistic_terrains=[builder['height_bvh'](bpy.data.objects[n]) for n in ['Distant_Islands','Landing_Bank_Main_South','Landing_Bank_North_South'] if n in bpy.data.objects]
    def artistic_height(x,y):
        hits=[t.ray_cast(Vector((x,y,40)),Vector((0,0,-1)))[0] for t in artistic_terrains]
        return max(p.z for p in hits if p is not None)
    builder['reseat_props'](artistic_height)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,'garden_objects':len(dst.collections[0].objects)}


def validate_saved():
    import hashlib,struct
    ns=runpy.run_path(str(PROJECT/'tools/validate_south_garden.py'))
    ns['validate'].__globals__['PREVIEW']=PREVIEW
    report=ns['validate']()
    source=Path(bpy.data.filepath);standalone=source.name=='south_garden.blend'
    ground_name='SouthGarden_Distant_Islands' if standalone else ('Distant_Islands-col' if source.parent==PROJECT/'assets' else 'Distant_Islands')
    builder=runpy.run_path(str(PROJECT/'tools/build_south_garden.py'))
    tree_names=[ground_name]+[('SouthGarden_' if standalone else '')+n for n in ['Landing_Bank_Main_South','Landing_Bank_North_South']]
    trees=[builder['height_bvh'](bpy.data.objects[n]) for n in tree_names]
    path=bpy.data.objects['SouthGarden_Gravel'];minimum=100;checks=0
    assert all(p.use_smooth for p in path.data.polygons),'Faceted path shading'
    for face in path.data.polygons:
        if face.normal.z<.30:continue
        p=face.center
        for tree in trees:
            hit=tree.ray_cast(Vector((p.x,p.y,40)),Vector((0,0,-1)))[0]
            if hit:minimum=min(minimum,p.z-hit.z)
        checks+=1
    assert minimum>.035,minimum
    edge=bpy.data.objects['SouthGarden_Edge_Stone'];deck=(88.3,91.,-34.355,-32.003)
    caps=[p for p in edge.data.polygons if len(p.vertices)==8 and p.normal.z>.8]
    assert len(caps)>40,'Missing coping top faces'
    # Full triangle intersection, including height, against the actual timber slab.
    deck_verts=[Vector((x,y,z)) for z in [4.70,4.82] for x,y in [(deck[0],deck[2]),(deck[1],deck[2]),(deck[1],deck[3]),(deck[0],deck[3])]]
    deck_faces=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    deck_tree=BVHTree.FromPolygons(deck_verts,deck_faces)
    overlaps=deck_tree.overlap(builder['height_bvh'](edge))
    assert not overlaps,'Coping intersects boardwalk: '+str(len(overlaps))
    plan=json.loads((PROJECT/'assets/south_garden.json').read_text());rows=json.loads((PROJECT/'assets/gscatter_ground_cover_instances.json').read_text())
    for row in rows:
        x,y=row['origin'][0],-row['origin'][2]
        if not(x>69 and y<0):continue
        margin=.42*max(row.get('blender_scale',[1,1,1]))+.12
        assert builder['path_field'](x,y)<=-margin
        assert not any(inside_margin(x,y,p,margin) for p in plan['refinement']['grass']['rock_footprints'])
    if not standalone:
        backup=Path(json.loads((PREVIEW/'backup.json').read_text())['path'])
        with bpy.data.libraries.load(str(backup/str(source).lstrip('/')),link=False) as (src,dst):dst.objects=[ground_name]
        old=dst.objects[0]
        assert ns['fingerprint'](old)==ns['fingerprint'](bpy.data.objects[ground_name]),'Terrain changed during visual repair'
        bpy.data.objects.remove(old,do_unlink=True)
        report['all_terrain_vertices_unchanged']=True
    digest=hashlib.sha256()
    for obj in sorted(bpy.data.collections[COLLECTION].objects,key=lambda o:o.name):
        if obj.name.startswith('South_Koi_'):continue
        digest.update(obj.name.encode())
        for v in obj.data.vertices:digest.update(struct.pack('fff',*v.co))
    report.update(path_triangles_checked=checks,min_path_soil_clearance_m=minimum,coping_visible_caps=len(caps),deck_stone_intersections=0,grass_rock_intersections=0,static_geometry_sha256=digest.hexdigest(),zen_stone_vertices=len(bpy.data.objects['SouthGarden_Contemplation_Rock'].data.vertices))
    filename='source_'+('library' if standalone else ('optimized' if source.parent==PROJECT/'assets' else 'artistic'))+'.json'
    (PREVIEW/filename).write_text(json.dumps(report,indent=2));return report
