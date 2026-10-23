"""Repair drooping leaf in potted plant at temple stairs (Circle.001) and export scoped mesh.

Rotates Component 34 (159 vertices) in Circle.001 upward by 52 degrees around its stem,
raising its lowest point from z=-0.056 (10.6 cm in ground) to z=+0.084 (3.4 cm above pavement).
Exports assets/stair_pot_leaves.glb and updates both authoritative Blender source files.
"""
import math
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector, Matrix

PROJECT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')


def get_component_34(bm):
    bm.verts.ensure_lookup_table()
    visited = set()
    components = []
    for v in bm.verts:
        if v.index in visited:
            continue
        comp = []
        queue = [v]
        visited.add(v.index)
        while queue:
            curr = queue.pop(0)
            comp.append(curr.index)
            for edge in curr.link_edges:
                other = edge.other_vert(curr)
                if other.index not in visited:
                    visited.add(other.index)
                    queue.append(other)
        components.append(comp)
    for comp in components:
        min_z = min(bm.verts[i].co.z for i in comp)
        if min_z < -0.05:
            return comp
    return components[34]


def apply_leaf_rotation(me):
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.verts.ensure_lookup_table()

    comp = get_component_34(bm)
    base_v = max(comp, key=lambda i: bm.verts[i].co.z)
    base = bm.verts[base_v].co.copy()
    axis = Vector((0.0332, 0.0657, 0)).normalized()
    rot = Matrix.Rotation(math.radians(52), 3, axis)

    for i in comp:
        bm.verts[i].co = base + rot @ (bm.verts[i].co - base)

    bm.to_mesh(me)
    bm.free()
    me.update()


def build_and_export():
    assert Path(bpy.data.filepath) == PROJECT / 'assets/mediterranean_temple.blend'
    me = bpy.data.meshes['Circle.001']
    apply_leaf_rotation(me)

    temp_obj = bpy.data.objects.new('Stair_Pot_Leaves_Repaired', me)
    bpy.context.scene.collection.objects.link(temp_obj)
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action='DESELECT')
    temp_obj.select_set(True)
    bpy.context.view_layer.objects.active = temp_obj

    export_path = PROJECT / 'assets/stair_pot_leaves.glb'
    bpy.ops.export_scene.gltf(
        filepath=str(export_path),
        export_format='GLB',
        use_selection=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False
    )

    bpy.data.objects.remove(temp_obj, do_unlink=True)

    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
    print(f'Successfully built and exported {export_path} and saved {bpy.data.filepath}')


def install_saved():
    assert Path(bpy.data.filepath) == OUT / 'mediterranean_temple_improved.blend'
    me = bpy.data.meshes['Circle.001']
    apply_leaf_rotation(me)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)
    print(f'Successfully updated {bpy.data.filepath}')


if __name__ == '__main__':
    current_path = Path(bpy.data.filepath)
    if current_path == PROJECT / 'assets/mediterranean_temple.blend':
        build_and_export()
    elif current_path == OUT / 'mediterranean_temple_improved.blend':
        install_saved()
    else:
        print(f'Unknown blend file: {current_path}')
