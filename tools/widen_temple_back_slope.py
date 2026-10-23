"""Widen the temple's east rear ramp without rebuilding bridges or the map.

Run build_and_export() in the artistic scene, then install_saved() in both maps.
The scoped Cliff_Terrain export retains the previous bridge grading and skirts.
"""
import json
import math
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
WIDTH_ADDED = 3.5


def smooth(a, b, x):
    t = max(0., min(1., (x-a)/(b-a)))
    return t*t*(3.-2.*t)


def expansion(x, y):
    return (WIDTH_ADDED * smooth(8., 9., x) * (1.-smooth(10., 22., x))
            * smooth(9., 12., y) * (1.-smooth(21., 27., y)))


def ground(bvh, x, y):
    hit = bvh.ray_cast(Vector((x, y, 60.)), Vector((0., 0., -1.)))[0]
    assert hit is not None, (x, y)
    return hit.z


def build_and_export():
    assert Path(bpy.data.filepath) == OUT/'mediterranean_temple_improved.blend'
    land = bpy.data.objects['Cliff_Terrain']
    assert land.matrix_world == __import__('mathutils').Matrix.Identity(4)
    old_x = land.data.attributes.get('temple_back_slope_original_x')
    if old_x is None:
        old_x = land.data.attributes.new('temple_back_slope_original_x', 'FLOAT', 'POINT')
        for v, value in zip(land.data.vertices, old_x.data):
            value.value = v.co.x
    changed = 0
    for v, value in zip(land.data.vertices, old_x.data):
        amount = expansion(value.value, v.co.y)
        v.co.x = value.value+amount
        changed += amount > .0001
    land.data.update()
    # Keep the world-space terrain texture at its existing frequency.
    for uv in land.data.uv_layers:
        for loop, value in zip(land.data.loops, uv.data):
            v = land.data.vertices[loop.vertex_index]
            if expansion(old_x.data[v.index].value, v.co.y) > .0001:
                value.uv = (v.co.x*.19, v.co.y*.19)
    bpy.context.view_layer.update()
    bvh = BVHTree.FromObject(land, bpy.context.evaluated_depsgraph_get())
    props = []
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or not obj.name.startswith(('Main_Island_Olive_', 'Large_Rock_Main_')):
            continue
        x = obj.get('temple_back_slope_original_x', obj.location.x)
        amount = expansion(x, obj.location.y)
        if amount < .0001:
            continue
        obj['temple_back_slope_original_x'] = x
        obj.location.x = x+amount
        bpy.context.view_layer.update()
        points = [obj.matrix_world@v.co for v in obj.data.vertices]
        bottom = min(p.z for p in points)
        feet = [p for p in points if p.z < bottom+.16]
        feet = feet[::max(1, len(feet)//96)]
        obj.location.z += min(ground(bvh, p.x, p.y)-p.z for p in feet)-.035
        props.append({'name':obj.name, 'temple_back_slope_original_x':x,
                      'blender_position':list(obj.location),
                      'position':[obj.location.x, obj.location.z, -obj.location.y]})
    lamps = json.loads((PROJECT/'assets/island_lantern_positions.json').read_text())
    lamp_names = []
    for row in lamps:
        x, y, z = row['blender_position']
        x = row.get('temple_back_slope_original_x', x)
        amount = expansion(x, y)
        if amount < .0001:
            continue
        row['temple_back_slope_original_x'] = x
        x += amount
        z = min(ground(bvh, x+.245*math.cos(i*math.tau/32),
                       y+.245*math.sin(i*math.tau/32)) for i in range(32))-.02
        row['blender_position'] = [x, y, z]
        row['position'] = [x, z, -y]
        lamp_names.append(row['name'])
    for path in [PROJECT/'assets/island_lantern_positions.json', OUT/'island_lantern_positions.json']:
        path.write_text(json.dumps(lamps, indent=2))
    grass_path = PROJECT/'assets/gscatter_ground_cover_instances.json'
    grass = json.loads(grass_path.read_text())
    moved = 0
    for row in grass:
        x, z, neg_y = row['origin']
        x = row.get('temple_back_slope_original_x', x)
        amount = expansion(x, -neg_y)
        if amount < .0001:
            continue
        row['temple_back_slope_original_x'] = x
        x += amount
        row['origin'] = [x, ground(bvh, x, -neg_y)-.008, neg_y]
        moved += 1
    grass_path.write_text(json.dumps(grass, separators=(',', ':')))
    repair_path = PROJECT/'assets/bridge_approach_repairs.json'
    report = json.loads(repair_path.read_text())
    merged = {r['name']:r for r in report['grounded_props']}
    merged.update({r['name']:r for r in props})
    report['grounded_props'] = list(merged.values())
    report['temple_back_slope'] = {'width_added_m':WIDTH_ADDED,
        'full_width_blender_y':[12., 21.], 'feathered_blender_y':[9., 27.],
        'terrain_vertices_widened':changed, 'grass_reseated':moved,
        'grounded_props':[r['name'] for r in props], 'reseated_lamps':lamp_names}
    for path in [repair_path, OUT/'bridge_approach_repairs.json']:
        path.write_text(json.dumps(report, indent=2))
    bpy.ops.object.select_all(action='DESELECT')
    land.select_set(True)
    bpy.context.view_layer.objects.active = land
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/bridge_approach_terrain.glb'),
        export_format='GLB', use_selection=True, export_cameras=False,
        export_lights=False, export_animations=False)
    bpy.data.libraries.write(str(OUT/'bridge_approach_terrain.blend'), {land},
                             fake_user=True, compress=True)
    return report['temple_back_slope']


def install_saved():
    assert Path(bpy.data.filepath) in [OUT/'mediterranean_temple_improved.blend',
                                     PROJECT/'assets/mediterranean_temple.blend']
    land = bpy.data.objects.get('Cliff_Terrain') or bpy.data.objects['Cliff_Terrain-col']
    with bpy.data.libraries.load(str(OUT/'bridge_approach_terrain.blend'), link=False) as (src, dst):
        dst.meshes = [n for n in src.meshes if n.startswith('Cliff_Terrain')]
    assert len(dst.meshes) == 1
    land.data = dst.meshes[0]
    report = json.loads((PROJECT/'assets/bridge_approach_repairs.json').read_text())
    for row in report['grounded_props']:
        obj = (bpy.data.objects.get(row['name']) or bpy.data.objects.get(row['name']+'-col')
               or bpy.data.objects.get(row['name']+'-convcol'))
        assert obj is not None, row['name']
        obj.location = row['blender_position']
        if row['name'] in report['temple_back_slope']['grounded_props']:
            # Recover the pre-widening pivot for an older report, too.
            lo, hi = obj.location.x-WIDTH_ADDED, obj.location.x
            for _ in range(32):
                mid = (lo+hi)/2
                if mid+expansion(mid,obj.location.y) < obj.location.x:
                    lo = mid
                else:
                    hi = mid
            obj['temple_back_slope_original_x'] = row.get('temple_back_slope_original_x',(lo+hi)/2)
    for row in json.loads((PROJECT/'assets/island_lantern_positions.json').read_text()):
        obj = bpy.data.objects.get(row['name'])
        assert obj is not None, row['name']
        obj.location = row['blender_position']
    bpy.context.view_layer.update()
    bvh = BVHTree.FromObject(land, bpy.context.evaluated_depsgraph_get())
    reseated = 0
    for obj in bpy.context.scene.objects:
        if obj.type != 'MESH' or not obj.name.startswith('GScatter_') or not obj.name.endswith('_Meadow'):
            continue
        mesh = obj.data
        original = mesh.attributes.get('temple_back_slope_original_x')
        if original is None:
            original = mesh.attributes.new('temple_back_slope_original_x', 'FLOAT', 'POINT')
            for v, value in zip(mesh.vertices, original.data):
                value.value = (obj.matrix_world@v.co).x
        inverse = obj.matrix_world.inverted()
        for v, value in zip(mesh.vertices, original.data):
            p = obj.matrix_world@v.co
            amount = expansion(value.value, p.y)
            if amount < .0001:
                continue
            p.x = value.value+amount
            p.z = ground(bvh, p.x, p.y)-.008
            v.co = inverse@p
            reseated += 1
        mesh.update()
    bpy.context.scene['temple_back_slope_widened_m'] = WIDTH_ADDED
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
    return {'saved':bpy.data.filepath, 'grass_reseated':reseated,
            'width_added_m':WIDTH_ADDED}
