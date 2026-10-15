"""
Create the updated, game-ready .blend file for the Godot walkable temple project.
Takes the latest improvements from mediterranean_temple_improved.blend:
- Relocated marble bust and plinth assembly on east terrace
- Rear science lab equipment (collection 15_Rear_Lab_Equipment)
- Full temple science lab (collection 14_Temple_Science_Lab)
- 91 grounded olive trees with game-ready mesh
- 22 large rocks with game-ready mesh and -convcol collision
- Naturalized coastline and centered temple stairs
- Active collision suffixes (-col, -convcol) for direct Godot .blend import
- Omits archived/hidden objects and tiny spray particles
"""

import bpy
from pathlib import Path

SRC_BLEND = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend')
DST_BLEND = Path('/home/allister/Projects/mediterranean_temple_walkable/assets/mediterranean_temple.blend')

def build_blend():
    print(f"Loading source: {SRC_BLEND}")
    bpy.ops.wm.open_mainfile(filepath=str(SRC_BLEND))

    # Identify candidate objects
    candidates = []
    to_delete = []

    archive_collection_names = {
        'Assets_Staging', 'Original_Water_Feature_ARCHIVE', 'Previous_Still_Water_ARCHIVE',
        'Previous_Geometric_Land_ARCHIVE', 'Previous_Offset_Stair_ARCHIVE',
        'Previous_Solid_Cella_ARCHIVE'
    }

    for o in list(bpy.context.scene.objects):
        if o.type not in {'MESH', 'CURVE', 'SURFACE', 'FONT'}:
            continue
        if o.hide_render or o.hide_get():
            to_delete.append(o)
            continue
        if any(c.hide_render or c.hide_viewport or c.name in archive_collection_names for c in o.users_collection):
            to_delete.append(o)
            continue

        # Skip individual tiny transparent spray/foam particle dots that cause heavy alpha fillrate lag
        if any(c.name == '09_Animated_Water' for c in o.users_collection):
            if any(term in o.name for term in ['impact spray', 'falling spray', 'landing foam', 'churning foam', 'inlet foam']):
                to_delete.append(o)
                continue

        candidates.append(o)

    print(f"Purging {len(to_delete)} archived/hidden/particle objects...")
    for o in to_delete:
        bpy.data.objects.remove(o, do_unlink=True)

    # Delete archive collections
    for c in list(bpy.data.collections):
        if c.name in archive_collection_names:
            bpy.data.collections.remove(c)

    def get_collision_suffix(o):
        colls = {c.name for c in o.users_collection}

        # Water never collides
        if '09_Animated_Water' in colls or o.name == 'Mediterranean_Sea':
            return ""
        if 'Water' in o.name or (hasattr(o.data, 'materials') and any(m and 'Water' in m.name for m in o.data.materials)):
            return ""

        # Foliage: trees should NOT have concave collision
        if any(c in colls for c in {'11_Island_Olive_Groves', '12_Main_Island_Olive_Groves'}):
            return ""
        if 'Olive' in o.name or 'tree' in o.name.lower():
            return ""

        # Small dressing/plants
        if 'fern' in o.name.lower() or 'leaves' in o.name.lower() or 'stem' in o.name.lower() or 'pebbles' in o.name.lower():
            return ""

        # Non-structural dressing: text, cables, liquid volumes
        if o.type == 'FONT' or 'Liquid' in o.name or 'Pendant_Cable' in o.name:
            return ""

        # Large Island Rocks: use -convcol
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
            if o.name in {'Balustrades_With_Outfall_Notch', 'Bronze_Wall_Spout', 'Outfall_Bed',
                          'Outfall_Channel_Wall', 'Outfall_Channel_Wall.001', 'Outfall_End_Sill',
                          'Outfall_Stone_Corbel', 'Outfall_Stone_Corbel.001'}:
                return ""
            return "-col"

        return ""

    # Decimate shared tree mesh
    orig_tree_mesh = bpy.data.meshes.get('island_trees_01_blockout_cleaned')
    tree_objects = [o for o in candidates if o.type == 'MESH' and o.data == orig_tree_mesh]
    if orig_tree_mesh and tree_objects:
        print(f"Decimating shared tree mesh from {len(orig_tree_mesh.polygons)} polygons...")
        temp_obj = bpy.data.objects.new('TempTreeDecim', orig_tree_mesh)
        bpy.context.scene.collection.objects.link(temp_obj)
        dec_mod = temp_obj.modifiers.new('DecimTree', 'DECIMATE')
        dec_mod.ratio = 0.08
        deps = bpy.context.evaluated_depsgraph_get()
        eval_obj = temp_obj.evaluated_get(deps)
        decimated_tree_mesh = bpy.data.meshes.new_from_object(eval_obj)
        decimated_tree_mesh.name = 'island_trees_01_game_ready'
        for o in tree_objects:
            o.data = decimated_tree_mesh
        bpy.data.objects.remove(temp_obj)
        bpy.data.meshes.remove(orig_tree_mesh)
        print(f"Tree mesh reduced to {len(decimated_tree_mesh.polygons)} polygons across all {len(tree_objects)} trees.")

    # Apply decimation modifier to high poly rocks
    for o in candidates:
        if o.name.startswith('Large_Rock_') and o.type == 'MESH':
            dec = o.modifiers.new(name='GameDecimate', type='DECIMATE')
            dec.ratio = 0.12
            # Apply modifier
            bpy.context.view_layer.objects.active = o
            bpy.ops.object.modifier_apply(modifier=dec.name)

    # Rename objects with -col / -convcol suffixes
    renamed_count = 0
    for o in candidates:
        if o.name not in bpy.data.objects:
            continue
        suffix = get_collision_suffix(o)
        if suffix and not o.name.endswith(suffix):
            o.name += suffix
            renamed_count += 1

    print(f"Renamed {renamed_count} objects with collision suffixes.")

    # Convert island_tree_01_leaves custom group into standard Principled BSDF for glTF/Godot export
    mat = bpy.data.materials.get('island_tree_01_leaves')
    if mat and mat.node_tree:
        nodes = mat.node_tree.nodes
        links = mat.node_tree.links
        group_node = None
        output_node = None
        for n in list(nodes):
            if n.type == 'GROUP':
                group_node = n
            elif n.type == 'OUTPUT_MATERIAL':
                output_node = n

        diff_node = nodes.get('Image Texture')
        rough_node = nodes.get('Image Texture.001')
        norm_node = nodes.get('Image Texture.002')
        alpha_node = nodes.get('Image Texture.003')

        if group_node and output_node:
            nodes.remove(group_node)
            bsdf = nodes.new(type='ShaderNodeBsdfPrincipled')
            bsdf.name = 'Principled BSDF'
            bsdf.location = (200, 300)

            if diff_node:
                links.new(diff_node.outputs['Color'], bsdf.inputs['Base Color'])
            if rough_node:
                links.new(rough_node.outputs['Color'], bsdf.inputs['Roughness'])
            if alpha_node:
                links.new(alpha_node.outputs['Color'], bsdf.inputs['Alpha'])
            if norm_node:
                norm_map = nodes.new(type='ShaderNodeNormalMap')
                norm_map.location = (0, 0)
                links.new(norm_node.outputs['Color'], norm_map.inputs['Color'])
                links.new(norm_map.outputs['Normal'], bsdf.inputs['Normal'])

            links.new(bsdf.outputs['BSDF'], output_node.inputs['Surface'])
            mat.blend_method = 'CLIP'
            print("Converted island_tree_01_leaves to standard Principled BSDF with CLIP alpha.")

    # Save to destination blend file
    print(f"Saving game-ready blend file to {DST_BLEND}...")
    bpy.ops.wm.save_as_mainfile(filepath=str(DST_BLEND), compress=True)
    print(f"Saved successfully! Size: {DST_BLEND.stat().st_size} bytes.")

if __name__ == '__main__':
    build_blend()
