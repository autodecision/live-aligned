"""Add red cedar infill around the upstairs lattice windows via Blender MCP.

Run build_and_export() in the standalone north_pagoda.blend, then install_saved()
in each editable map. This preserves the existing sidewalk and all other meshes.
"""
import json
import math
from pathlib import Path

import bpy

PROJECT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
NAME = 'North_Pagoda_Pagoda_Window_Wall_Infill'


def panels():
    """Match the original builder's window borders, with concealed overlap."""
    yaw = -.88
    c, s = math.cos(yaw), math.sin(yaw)
    for floor, half in [(5.4, 5.3), (9.8, 4.65)]:
        # Two windows per wall: centers +/- .43*half, width .69*half.
        intervals = [(-half-.095, -.775*half+.02),
                     (-.085*half-.02, .085*half+.02),
                     (.775*half-.02, half+.095)]
        for side in range(4):
            angle = -side * math.pi / 2
            ca, sa = math.cos(angle), math.sin(angle)
            for lo, hi in intervals:
                q = (lo+hi)/2
                x, y = -sa*half+ca*q, ca*half+sa*q
                yield {'type': 'box', 'window_wall_infill': True,
                       'center': [92+c*x-s*y, 64+s*x+c*y, 5.5+floor+1.98],
                       'size': [hi-lo, .19, 2.18], 'yaw': yaw+angle}


def build_and_export():
    assert Path(bpy.data.filepath) == OUT/'north_pagoda.blend'
    rows = list(panels())
    vertices, faces = [], []
    cube = [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
            (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
    quads = [(0,3,2,1),(4,5,6,7),(0,1,5,4),
             (1,2,6,5),(2,3,7,6),(3,0,4,7)]
    for row in rows:
        cx,cy,cz = row['center']
        sx,sy,sz = [v/2 for v in row['size']]
        c,s = math.cos(row['yaw']),math.sin(row['yaw'])
        offset = len(vertices)
        vertices.extend((cx+c*sx*x-s*sy*y,cy+s*sx*x+c*sy*y,cz+sz*z)
                        for x,y,z in cube)
        faces.extend(tuple(offset+i for i in face) for face in quads)
    obj = bpy.data.objects.get(NAME)
    if obj is None:
        mesh = bpy.data.meshes.new(NAME)
        obj = bpy.data.objects.new(NAME, mesh)
        bpy.data.collections['North Pagoda'].objects.link(obj)
    else:
        obj.data = bpy.data.meshes.new(NAME)
    obj.data.from_pydata(vertices, [], faces)
    obj.data.materials.append(bpy.data.objects['North_Pagoda_Pagoda_Red_Cedar'].data.materials[0])
    obj.data.update()
    obj['window_wall_infill_panels'] = len(rows)
    plan = json.loads((PROJECT/'assets/north_pagoda.json').read_text())
    plan['colliders'] = [r for r in plan['colliders'] if not r.get('window_wall_infill')]+rows
    plan['window_wall_infill_panels'] = len(rows)
    for path in [PROJECT/'assets/north_pagoda.json', OUT/'north_pagoda.json']:
        path.write_text(json.dumps(plan, indent=2))
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'north_pagoda.blend'), compress=True)
    # Export the existing standalone landmark, including the repaired sidewalk.
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/north_pagoda.glb'),
                              export_format='GLB', export_cameras=False,
                              export_lights=False, export_animations=False)
    return {'panels':len(rows),'material':obj.data.materials[0].name,
            'saved':bpy.data.filepath,'export':str(PROJECT/'assets/north_pagoda.glb')}


def install_saved():
    assert Path(bpy.data.filepath) in [PROJECT/'assets/mediterranean_temple.blend',
                                     OUT/'mediterranean_temple_improved.blend']
    target = bpy.data.objects.get(NAME)
    with bpy.data.libraries.load(str(OUT/'north_pagoda.blend'), link=False) as (src, dst):
        dst.objects = [NAME]
    source = dst.objects[0]
    if target:
        target.data = source.data
        bpy.data.objects.remove(source, do_unlink=True)
    else:
        target = source
        bpy.data.collections['North Pagoda'].objects.link(target)
    # Reuse the map's exact pillar material, without introducing a duplicate.
    target.data.materials[0] = bpy.data.objects['North_Pagoda_Pagoda_Red_Cedar'].data.materials[0]
    target['window_wall_infill_panels'] = 24
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
    return {'saved':bpy.data.filepath,'panels':24,'vertices':len(target.data.vertices)}
