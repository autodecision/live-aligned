"""Ground floating reeds in koi pond and seat stone lanterns equidistant from ramp.

Authoritative sources:
- assets/mediterranean_temple.blend (optimized map)
- output/mediterranean_temple/improvements/mediterranean_temple_improved.blend (artistic map)
- output/mediterranean_temple/improvements/south_garden.blend (standalone garden library)
Runtime exports:
- assets/south_garden.glb
- assets/south_garden.json
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
ART = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
COLLECTION = 'South Koi and Zen Garden'

# North lantern is at (90.2, -30.1).
# Ramp Y center is (-34.355 + -32.003) / 2 = -33.179.
# Distance from ramp center to north lantern: -30.1 - (-33.179) = 3.079 m.
# Equidistant south lantern: -33.179 - 3.079 = -36.258 m.
NEW_LAMPS = [
    (90.2, -30.1),
    (90.2, -36.258),
    (104.41, -25.2),
    (104.41, -42.8),
    (116.0, -25.2),
    (116.0, -42.8),
]

def export_gltf(path, objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format='GLB',
        use_selection=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False
    )

def ground_reeds(lining_obj, reed_obj):
    tree = BVHTree.FromPolygons([v.co for v in lining_obj.data.vertices], [p.vertices for p in lining_obj.data.polygons])
    me = reed_obj.data
    num_blades = len(me.vertices) // 6
    assert num_blades == 76, f'Expected 76 blades, got {num_blades}'
    for b in range(num_blades):
        v0 = me.vertices[6 * b]
        v1 = me.vertices[6 * b + 1]
        v2 = me.vertices[6 * b + 2]
        v3 = me.vertices[6 * b + 3]
        v4 = me.vertices[6 * b + 4]
        v5 = me.vertices[6 * b + 5]

        mid_xy = (v0.co.xy + v1.co.xy) / 2
        hit, normal, index, dist = tree.ray_cast(Vector((mid_xy.x, mid_xy.y, 5.0)), Vector((0, 0, -1)))
        assert hit is not None, f'Blade {b} missed lining at {mid_xy}'

        bed_z = hit.z - 0.02  # Embed 2cm into pond lining bed
        top_z = (v4.co.z + v5.co.z) / 2
        new_h = top_z - bed_z

        v0.co.z = bed_z
        v1.co.z = bed_z

        v2.co.z = bed_z + new_h * 0.55
        v3.co.z = bed_z + new_h * 0.55
        v2.co.x = v0.co.x + (v4.co.x - v0.co.x) * (1.0 / 3.0)
        v2.co.y = v0.co.y + (v4.co.y - v0.co.y) * (1.0 / 3.0)
        v3.co.x = v1.co.x + (v5.co.x - v1.co.x) * (1.0 / 3.0)
        v3.co.y = v1.co.y + (v5.co.y - v1.co.y) * (1.0 / 3.0)
    me.update()
    print(f'Grounded {num_blades} reed blades into pond lining.')

def move_south_lantern(old_y=-37.9, new_y=-36.258):
    # Delta from (-37.9, 4.619419) to (-36.258, 4.6500015)
    delta = Vector((0.0, new_y - old_y, 4.650001525878906 - 4.619419097900391))
    for name in ['SouthGarden_Dark_Stone', 'SouthGarden_Edge_Stone', 'SouthGarden_Lantern_Glow']:
        o = bpy.data.objects.get(name)
        if not o: continue
        moved = 0
        for v in o.data.vertices:
            if abs(v.co.x - 90.2) < 0.8 and abs(v.co.y - old_y) < 0.8:
                v.co += delta
                moved += 1
        o.data.update()
        print(f'{name}: moved {moved} vertices for south lantern by {delta}')

def update_plan():
    plan_path = ROOT / 'assets/south_garden.json'
    plan = json.loads(plan_path.read_text())

    # Update colliders for south lantern
    for row in plan['colliders']:
        if row.get('type') == 'box':
            c = row['center']
            if abs(c[0] - 90.2) < 0.5 and abs(c[1] - (-37.9)) < 0.5:
                c[1] = -36.258
                c[2] = 4.650001525878906 if row['size'][2] < 0.5 else 5.190001525878906

    # Update lights
    for row in plan['lights']:
        if abs(row[0] - 90.2) < 0.5 and abs(row[2] - 37.9) < 0.5:
            row[2] = 36.258
            row[1] = 5.810001525878906

    # Update composition
    if 'composition' in plan:
        plan['composition']['stone_lanterns_blender'] = [list(p) for p in NEW_LAMPS]
        plan['composition']['ramp_mirror_axis_blender_y'] = -33.179

    for p in [plan_path, ART / 'south_garden.json']:
        p.write_text(json.dumps(plan, indent=2))
    print('Updated south_garden.json plan and colliders.')

def update_optimized_blend():
    assert Path(bpy.data.filepath) == ROOT / 'assets/mediterranean_temple.blend'
    lining = bpy.data.objects['SouthGarden_Pond_Lining']
    reeds = bpy.data.objects['SouthGarden_Reed']
    ground_reeds(lining, reeds)
    move_south_lantern(-37.9, -36.258)
    update_plan()

    # Scoped export of South Koi and Zen Garden
    col = bpy.data.collections[COLLECTION]
    export_objs = [o for o in col.objects if not o.name.startswith('South_Koi_')]
    export_gltf(ROOT / 'assets/south_garden.glb', export_objs)
    print('Exported assets/south_garden.glb')

    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
    print('Saved assets/mediterranean_temple.blend')

def update_standalone_blend():
    assert Path(bpy.data.filepath) == ART / 'south_garden.blend'
    lining = bpy.data.objects['SouthGarden_Pond_Lining']
    reeds = bpy.data.objects['SouthGarden_Reed']
    ground_reeds(lining, reeds)
    move_south_lantern(-37.9, -36.258)

    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
    print('Saved south_garden.blend')

def update_artistic_blend():
    assert Path(bpy.data.filepath) == ART / 'mediterranean_temple_improved.blend'
    # Replace South Koi and Zen Garden collection from south_garden.blend
    old_col = bpy.data.collections.get(COLLECTION)
    if old_col:
        for o in list(old_col.objects):
            bpy.data.objects.remove(o, do_unlink=True)
        bpy.data.collections.remove(old_col)

    with bpy.data.libraries.load(str(ART / 'south_garden.blend'), link=False) as (src, dst):
        dst.collections = [COLLECTION]
    bpy.context.scene.collection.children.link(dst.collections[0])

    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
    print('Saved mediterranean_temple_improved.blend')
