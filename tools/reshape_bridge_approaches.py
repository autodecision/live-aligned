"""Scoped Blender MCP repair of the two large-island bridge approaches.
Call sculpt_and_export() and close_shoreline_and_export() on the artistic
source, then install_saved() on both
sources after rebuilding the independent bridge asset. Never export the base map.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT = Path('/home/allister/Projects/live-aligned')
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
STARTS = [('Main_North', (20.5, 31.5, 2.2600278854370117)),
          ('Main_South', (-1., -22., 2.35))]


def smooth(a, b, x):
    t = max(0., min(1., (x-a)/(b-a)))
    return t*t*(3.-2.*t)


def routes():
    plan = json.loads((PROJECT/'assets/island_bridges.json').read_text())
    result = []
    for name, start in STARTS:
        route = next(r for r in plan['bridges'] if r['name'] == name)
        a = Vector(start)
        b = Vector(route['sections'][-1]['blender_position'])
        d = Vector((b.x-a.x, b.y-a.y, 0.)); length = d.length; d.normalize()
        result.append((name, a, b, d, Vector((-d.y, d.x, 0.)), length))
    return result


def influence(p, route):
    _, a, b, d, n, length = route
    delta = p-a; s = delta.dot(d); c = delta.dot(n)
    irregular = .12*math.sin(p.x*.83+p.y*1.11)+.08*math.sin(p.y*2.1)
    w = smooth(-9., -5., s)*(1.-smooth(1.25, 6., s))
    w *= 1.-smooth(2.65, 6.8+irregular, abs(c))
    return w, s, c


def height(bvh, x, y):
    h, _, _, _ = bvh.ray_cast(Vector((x, y, 60.)), Vector((0., 0., -1.)))
    return h.z if h else None


def sculpt_and_export():
    land = bpy.data.objects.get('Cliff_Terrain') or bpy.data.objects['Cliff_Terrain-col']
    # Original Z values make reruns idempotent while retaining every other vertex.
    attr = land.data.attributes.get('bridge_original_z')
    if attr is None:
        attr = land.data.attributes.new('bridge_original_z', 'FLOAT', 'POINT')
        for v, value in zip(land.data.vertices, attr.data): value.value = v.co.z
    route_list = routes(); changed = 0
    for v, value in zip(land.data.vertices, attr.data):
        if value.value <= -9.999:
            v.co.z = value.value
            continue
        p = land.matrix_world @ v.co; p.z = value.value
        z = p.z
        for route in route_list:
            w, s, c = influence(p, route)
            if w <= 0.: continue
            _, a, b, d, n, length = route
            # A quiet walkable crown; the same mesh feathers out to the coast.
            if s < 0.:
                target = a.z-.055-s*.105
            else:
                t = min(1., s/length)
                target = a.z+(b.z-a.z)*t+1.15*math.sin(math.pi*t)-.065
            z = z*(1.-w)+target*w
        if abs(z-value.value)>.0001: changed += 1
        v.co.z = z
    land.data.update(); bpy.context.view_layer.update()
    bvh = BVHTree.FromObject(land, bpy.context.evaluated_depsgraph_get())
    props = []
    for obj in list(bpy.context.scene.objects):
        if obj.type != 'MESH' or not (obj.name.startswith('Main_Island_Olive_') or obj.name.startswith('Large_Rock_Main_')): continue
        points = [obj.matrix_world@v.co for v in obj.data.vertices]
        bottom = min(p.z for p in points)
        foot = [p for p in points if p.z < bottom+.16]
        if not any(influence(p, r)[0]>.02 for p in foot for r in route_list): continue
        foot = foot[::max(1, len(foot)//96)]
        offsets = [height(bvh,p.x,p.y)-p.z for p in foot if height(bvh,p.x,p.y) is not None]
        obj.location.z += min(offsets)-.035
        props.append({'name': obj.name.removesuffix('-col').removesuffix('-convcol'),
                      'blender_position': list(obj.location),
                      'position': [obj.location.x,obj.location.z,-obj.location.y]})
    # Shift one existing post out of the new approach, preserving its shared mesh.
    lamp_rows = json.loads((OUT/'island_lantern_positions.json').read_text())
    row = next(r for r in lamp_rows if r['name']=='Coastal_Lantern_Main_02')
    x, y = -4.75, -18.
    z = min(height(bvh,x+.245*math.cos(i*math.tau/32),y+.245*math.sin(i*math.tau/32)) for i in range(32))-.015
    row['blender_position'] = [x,y,z]; row['position'] = [x,z,-y]
    for path in [OUT/'island_lantern_positions.json',PROJECT/'assets/island_lantern_positions.json']:
        path.write_text(json.dumps(lamp_rows,indent=2))
    # Existing instance rows remain authoritative. Only altered ground is reseated;
    # the worn central approach stays clear of grass and encroaching blade tips.
    grass_path = PROJECT/'assets/gscatter_ground_cover_instances.json'
    grass_rows = json.loads(grass_path.read_text()); kept=[]; moved=0; cleared=0
    for row in grass_rows:
        p=Vector((row['origin'][0],-row['origin'][2],row['origin'][1]))
        nearby=[(r,influence(p,r)) for r in route_list]
        if any((-7.5 < v[1] < -.75 and abs(v[2]) < 1.85) or (-.75 <= v[1] < 6. and abs(v[2]) < 2.65) for r,v in nearby):
            cleared+=1;continue
        if any(v[0]>.001 for r,v in nearby):
            h=height(bvh,p.x,p.y)
            if h is not None and abs(h-p.z)<10.:
                row['origin'][1]=h-.008;moved+=1
        kept.append(row)
    grass_path.write_text(json.dumps(kept,separators=(',',':')))
    # Scoped terrain export has one mesh; the runtime swaps it into the existing
    # map node and refreshes that node's collider. The base GLB stays untouched.
    bpy.ops.object.select_all(action='DESELECT');land.select_set(True);bpy.context.view_layer.objects.active=land
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/bridge_approach_terrain.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
    bpy.data.libraries.write(str(OUT/'bridge_approach_terrain.blend'),{land},fake_user=True,compress=True)
    report={'terrain_vertices_changed':changed,'grounded_props':props,'grass_reseated':moved,'grass_cleared':cleared,
            'bridge_starts':[{'name':n,'blender_position':list(p)} for n,p in STARTS],
            'runtime_terrain':'res://assets/bridge_approach_terrain.glb'}
    (PROJECT/'assets/bridge_approach_repairs.json').write_text(json.dumps(report,indent=2))
    (OUT/'bridge_approach_repairs.json').write_text(json.dumps(report,indent=2))
    return report


def install_saved():
    path=bpy.data.filepath
    land=bpy.data.objects.get('Cliff_Terrain') or bpy.data.objects['Cliff_Terrain-col']
    with bpy.data.libraries.load(str(OUT/'bridge_approach_terrain.blend'),link=False) as (src,dst):
        dst.meshes=[n for n in src.meshes if n.startswith('Cliff_Terrain')]
    assert len(dst.meshes)==1
    land.data=dst.meshes[0]
    report=json.loads((PROJECT/'assets/bridge_approach_repairs.json').read_text())
    for row in report['grounded_props']:
        obj=bpy.data.objects.get(row['name']) or bpy.data.objects.get(row['name']+'-col') or bpy.data.objects.get(row['name']+'-convcol')
        assert obj is not None,row['name'];obj.location=row['blender_position']
    # Replace only bridge meshes, preserving all unrelated independent additions.
    col=bpy.data.collections['Island Bridges']
    for obj in list(col.objects):bpy.data.objects.remove(obj,do_unlink=True)
    with bpy.data.libraries.load(str(OUT/'island_bridges.blend'),link=False) as (src,dst):
        dst.objects=[n for n in src.objects if n.startswith('Bridge_')]
    for obj in dst.objects:col.objects.link(obj)
    lamp_rows=json.loads((PROJECT/'assets/island_lantern_positions.json').read_text())
    for row in lamp_rows:
        obj=bpy.data.objects.get(row['name']);assert obj is not None,row['name']
        obj.location=row['blender_position'];obj.rotation_euler.z=row['yaw']
    # Replace only the far Main_South bank, whose bridge direction changed.
    col=bpy.data.collections['Bridge Landing Banks']
    old=bpy.data.objects['Landing_Bank_Main_South'];bpy.data.objects.remove(old,do_unlink=True)
    with bpy.data.libraries.load(str(OUT/'bridge_landing_banks.blend'),link=False) as (src,dst):
        dst.objects=['Landing_Bank_Main_South']
    col.objects.link(dst.objects[0])
    # Keep the editable meadow point meshes synchronized with runtime clearing
    # and the graded ground, preserving their rotation and scale attributes.
    import bmesh
    bvh=BVHTree.FromObject(land,bpy.context.evaluated_depsgraph_get())
    route_list=routes();cleared=0;reseated=0
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH' or not obj.name.startswith('GScatter_') or not obj.name.endswith('_Meadow'):continue
        bm=bmesh.new();bm.from_mesh(obj.data);delete=[];inverse=obj.matrix_world.inverted()
        for v in bm.verts:
            p=obj.matrix_world@v.co;nearby=[influence(p,r) for r in route_list]
            if any((-7.5 < value[1] < -.75 and abs(value[2]) < 1.85) or (-.75 <= value[1] < 6. and abs(value[2]) < 2.65) for value in nearby):
                delete.append(v);continue
            if any(value[0]>.001 for value in nearby):
                h=height(bvh,p.x,p.y)
                if h is not None and abs(h-p.z)<10.:
                    p.z=h-.008;v.co=inverse@p;reseated+=1
        cleared+=len(delete);bmesh.ops.delete(bm,geom=delete,context='VERTS');bm.to_mesh(obj.data);bm.free()
    bpy.context.scene['bridge_approach_meadow_sync']=f'Cleared {cleared}, reseated {reseated} editable meadow points'
    bpy.context.scene['bridge_approach_repair']='Integrated graded bridge banks; Main_South start (-1,-22,2.35); scoped Cliff_Terrain override, base runtime GLB preserved.'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=path,compress=True)
    return {'saved':path,'terrain_vertices':len(land.data.vertices),'grounded_props':len(report['grounded_props'])}


def close_shoreline_and_export():
    """Continue newly exposed lower terrain edges below the sea surface.

    The historical terrain's gridded surface and cliff skirts have separate
    boundaries. Grading can expose the old underwater surface boundary, so it
    needs a short matching skirt rather than leaving the triangles suspended.
    """
    import bmesh
    land=bpy.data.objects.get('Cliff_Terrain') or bpy.data.objects['Cliff_Terrain-col']
    bm=bmesh.new();bm.from_mesh(land.data)
    original=bm.verts.layers.float.get('bridge_original_z')
    route_list=routes();bottoms={};closed=0
    for edge in list(bm.edges):
        if not edge.is_boundary:continue
        a,b=edge.verts
        if max(a.co.z,b.co.z)<-6.5:continue
        if min(a[original],b[original])>-6.:continue
        if not any(influence(v.co,r)[0]>.001 for v in (a,b) for r in route_list):continue
        loop=next(loop for loop in edge.link_faces[0].loops if loop.edge==edge)
        a,b=loop.vert,loop.link_loop_next.vert
        for v in (a,b):
            if v not in bottoms:
                q=bm.verts.new((v.co.x,v.co.y,-10.));q[original]=-10.;bottoms[v]=q
        face=bm.faces.new((b,a,bottoms[a],bottoms[b]));face.smooth=True;closed+=1
    bm.normal_update();bm.to_mesh(land.data);bm.free();land.data.update()
    # World coordinates keep the same ground texture frequency on the skirts.
    uv=land.data.uv_layers.active
    if uv:
        for poly in land.data.polygons:
            for index in poly.loop_indices:
                co=land.data.vertices[land.data.loops[index].vertex_index].co
                uv.data[index].uv=(co.x*.19,co.y*.19)
    bpy.ops.object.select_all(action='DESELECT');land.select_set(True);bpy.context.view_layer.objects.active=land
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/bridge_approach_terrain.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
    bpy.data.libraries.write(str(OUT/'bridge_approach_terrain.blend'),{land},fake_user=True,compress=True)
    report=json.loads((PROJECT/'assets/bridge_approach_repairs.json').read_text())
    report['closed_underwater_shore_edges']=closed
    for p in [PROJECT/'assets/bridge_approach_repairs.json',OUT/'bridge_approach_repairs.json']:
        p.write_text(json.dumps(report,indent=2))
    return {'shoreline_edges_closed':closed,'terrain_vertices':len(land.data.vertices)}
