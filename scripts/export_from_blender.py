"""
Export the latest Mediterranean Temple map from Blender into the walkable Godot game.
Optimized for real-time game performance:
- Applies proper collision types (-col for architecture/terrain, -convcol for rocks)
- Eliminates 70M+ collision polygons on dense tree foliage
- Decimates heavy 812k polygon tree mesh to a game-ready ~50k polygon shared asset
- Decimates high-poly sculpt rocks to ~4k polygons with convex colliders (-convcol)
- Avoids overdraw from 200+ individual tiny spray particles
- Collides solid lab furniture while keeping tiny props collision-free
"""

import bpy
import struct
import json
import time
from pathlib import Path

SRC_BLEND = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend')
DST_GLB = Path('/home/allister/Projects/mediterranean_temple_walkable/assets/mediterranean_temple.glb')
BACKUP_GLB = Path('/home/allister/Projects/mediterranean_temple_walkable/assets/mediterranean_temple.glb.bak_oct9')

def run_export():
    t0 = time.time()

    # Find candidates
    candidates = []
    for o in bpy.context.scene.objects:
        if o.type not in {'MESH', 'CURVE', 'SURFACE', 'FONT'}:
            continue
        if o.hide_render or o.hide_get():
            continue
        if any(c.hide_render or c.hide_viewport for c in o.users_collection):
            continue
        if any(c.name in {'Assets_Staging', 'Original_Water_Feature_ARCHIVE', 'Previous_Still_Water_ARCHIVE',
                          'Previous_Geometric_Land_ARCHIVE', 'Previous_Offset_Stair_ARCHIVE',
                          'Previous_Solid_Cella_ARCHIVE'} for c in o.users_collection):
            continue

        # Skip individual tiny transparent spray/foam particle dots that cause heavy alpha fillrate lag
        if any(c.name == '09_Animated_Water' for c in o.users_collection):
            if any(term in o.name for term in ['impact spray', 'falling spray', 'landing foam', 'churning foam', 'inlet foam']):
                continue

        candidates.append(o)

    def get_collision_suffix(o):
        colls = {c.name for c in o.users_collection}

        # Water never collides
        if '09_Animated_Water' in colls or o.name == 'Mediterranean_Sea':
            return ""
        if 'Water' in o.name or (hasattr(o.data, 'materials') and any(m and 'Water' in m.name for m in o.data.materials)):
            return ""

        # Foliage: trees should NOT have concave collision (chokes physics engine and causes branch snags)
        if any(c in colls for c in {'11_Island_Olive_Groves', '12_Main_Island_Olive_Groves'}):
            return ""
        if 'Olive' in o.name or 'tree' in o.name.lower():
            return ""

        # Small dressing/plants (ferns, individual leaves)
        if 'fern' in o.name.lower() or 'leaves' in o.name.lower() or 'stem' in o.name.lower() or 'pebbles' in o.name.lower():
            return ""

        # Non-structural dressing: text, cables, liquid volumes
        if o.type == 'FONT' or 'Liquid' in o.name or 'Pendant_Cable' in o.name:
            return ""

        # Large Island Rocks: use -convcol (Convex Polygon Shape) instead of -col (Concave Trimesh)
        # Prevents getting stuck in concave polygon crevices and is orders of magnitude faster
        if '13_Large_Island_Rocks' in colls or o.name.startswith('Large_Rock_'):
            return "-convcol"

        # Lab: only collide actual solid furniture and apparatus bases
        if '14_Temple_Science_Lab' in colls or '15_Rear_Lab_Equipment' in colls:
            solid_lab_keywords = [
                'Cabinet', 'Top', 'Worktop', 'Sofa', 'TV_Console', 'Side_Table',
                'Fume_Hood_Back', 'Fume_Hood_Canopy', 'East_Storage', 'West_Storage',
                'Rear_Station', 'Sample_Chamber_Back', 'Sample_Chamber_Side', 'Sample_Chamber_Top',
                'Balance_Base', 'Centrifuge', 'Microscope_Base', 'Console_Foot', 'Retort_Stand'
            ]
            if any(kw in o.name for kw in solid_lab_keywords):
                return "-col"
            return ""

        # Solid architecture, stairs, entrance, and natural island terrains
        solid_architecture_collections = {
            '01_Environment', '02_Architecture', '03_Water_Feature',
            '06_Water_Architecture_Repair', '07_Centered_Temple_Stair',
            '08_Temple_Entrance', '10_Natural_Coastline'
        }
        if colls & solid_architecture_collections:
            # Outfall details that shouldn't block player
            if o.name in {'Balustrades_With_Outfall_Notch', 'Bronze_Wall_Spout', 'Outfall_Bed',
                          'Outfall_Channel_Wall', 'Outfall_Channel_Wall.001', 'Outfall_End_Sill',
                          'Outfall_Stone_Corbel', 'Outfall_Stone_Corbel.001'}:
                return ""
            return "-col"

        return ""

    # Decimate the shared olive tree mesh so 91 instances are game-ready (~50k polys instead of 812k)
    orig_tree_mesh = bpy.data.meshes.get('island_trees_01_blockout_cleaned')
    temp_tree_mesh = None
    tree_objects = [o for o in candidates if o.data == orig_tree_mesh]
    if orig_tree_mesh and tree_objects:
        print(f"Decimating shared tree mesh from {len(orig_tree_mesh.polygons)} polygons...")
        temp_obj = bpy.data.objects.new('TempTreeDecim', orig_tree_mesh)
        bpy.context.scene.collection.objects.link(temp_obj)
        dec_mod = temp_obj.modifiers.new('DecimTree', 'DECIMATE')
        dec_mod.ratio = 0.08  # ~65k polygons per tree
        deps = bpy.context.evaluated_depsgraph_get()
        eval_obj = temp_obj.evaluated_get(deps)
        temp_tree_mesh = bpy.data.meshes.new_from_object(eval_obj)
        for o in tree_objects:
            o.data = temp_tree_mesh
        bpy.data.objects.remove(temp_obj)
        print(f"Shared tree mesh reduced to {len(temp_tree_mesh.polygons)} polygons for all {len(tree_objects)} trees.")

    # Apply decimation to high-poly rocks for game export
    temp_rock_modifiers = []
    for o in candidates:
        if o.name.startswith('Large_Rock_') and o.type == 'MESH':
            dec = o.modifiers.new(name='GameExportDecimate', type='DECIMATE')
            dec.ratio = 0.12  # Reduce 33k vertices to ~4k vertices per rock
            temp_rock_modifiers.append((o, dec))

    for o in bpy.context.scene.objects:
        o.select_set(False)

    selected = []
    renamed = []
    for o in candidates:
        suffix = get_collision_suffix(o)
        if suffix:
            o.name += suffix
            renamed.append((o, suffix))
        o.select_set(True)
        selected.append(o.name)

    print(f"Exporting {len(selected)} objects to {DST_GLB}...")
    bpy.ops.export_scene.gltf(
        filepath=str(DST_GLB),
        export_format='GLB',
        use_selection=True,
        export_apply=True,
        export_cameras=False,
        export_lights=False
    )

    # Clean up temporary rock modifiers
    for o, dec in temp_rock_modifiers:
        o.modifiers.remove(dec)

    # Restore tree mesh pointers
    if orig_tree_mesh and tree_objects:
        for o in tree_objects:
            o.data = orig_tree_mesh
        if temp_tree_mesh:
            bpy.data.meshes.remove(temp_tree_mesh)

    # Restore object names
    for o, suffix in renamed:
        o.name = o.name.removesuffix(suffix)

    print(f"Export completed in {time.time() - t0:.2f}s. File size: {DST_GLB.stat().st_size} bytes.")

if __name__ == '__main__':
    run_export()
