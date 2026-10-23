"""Scoped pool/stair props and reference-colored offshore formations, via Blender MCP."""
import bpy
import bmesh
import hashlib
import json
import math
import struct
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
PROJECT=Path(__file__).resolve().parent.parent
ART=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend')
SEA=['East_Headland_Stack','East_Reef','North_Reef','North_Satellite','South_Cove_Rock','South_Reef','South_Satellite','Southwest_Skerry','West_Sea_Stack']
FERNS=['Fern_Pool_1','Fern_Pool_2']
PLAN=PROJECT/'assets/temple_clearance.json'

def obj(name):
    o=bpy.data.objects.get(name) or bpy.data.objects.get(name+'-col')
    assert o is not None,name
    return o

def components(me):
    adjacency=[[] for _ in me.vertices]
    for edge in me.edges:
        a,b=edge.vertices;adjacency[a].append(b);adjacency[b].append(a)
    seen=set();groups=[]
    for vertex in me.vertices:
        if vertex.index in seen:continue
        todo=[vertex.index];seen.add(vertex.index);group=[]
        while todo:
            i=todo.pop();group.append(i)
            for j in adjacency[i]:
                if j not in seen:seen.add(j);todo.append(j)
        groups.append(group)
    return groups

def leaves():
    o=obj('Pot_Stairs_Bot_L_leaves')
    if o.data.get('temple_leaf_clearance'):return
    # Each broad blade is a separate connected component. Keep its petiole
    # attachment fixed while tipping low blades upward; preserve UVs/stems.
    me=o.data.copy();me.name='Temple | raised stair plant leaves'
    turns=[]
    for group in components(me):
        if len(group)<150 or min(me.vertices[i].co.z for i in group)>=.075:continue
        positions={i:me.vertices[i].co.copy() for i in group}
        top=max(p.z for p in positions.values())
        candidates=[p for p in positions.values() if p.z>top-.012]
        base=min(candidates,key=lambda p:p.x*p.x+p.y*p.y).copy()
        center=sum(positions.values(),Vector())/len(group)
        radial=center-base;axis=Vector((radial.y,-radial.x,0)).normalized()
        found=False
        for degree in range(2,91,2):
            rot=Matrix.Rotation(math.radians(degree),3,axis)
            if min((base+rot@(p-base)).z for p in positions.values())>=.075:
                for i,p in positions.items():me.vertices[i].co=base+rot@(p-base)
                turns.append(degree);found=True;break
        assert found,'Cannot raise leaf without moving petiole'
    me['temple_leaf_clearance']=True;me.update()
    for name in ['Pot_Stairs_Bot_L_leaves','Pot_Stairs_Bot_R_leaves','Pot_Pool_2_leaves']:obj(name).data=me
    return turns

def natural_stone(p):
    # p is world coordinate in Blender. Water level is at p.z = -5.0.
    # Below -4.5: darker wet coastal stone.
    # Above -3.5: natural weathered Mediterranean limestone.
    t = max(0.0, min(1.0, (p.z - (-4.8)) / 1.5))
    wet = Vector((0.48, 0.49, 0.47, 1.0))
    dry = Vector((0.85, 0.84, 0.81, 1.0))
    var = 0.03 * math.sin(0.25 * p.x + 0.35 * p.y) + 0.02 * math.sin(0.8 * p.z)
    base = wet.lerp(dry, t)
    return (base[0] + var, base[1] + var, base[2] + var, 1.0)

def color_rocks():
    mat = bpy.data.materials.get('Sea stone | reference spectrum') or bpy.data.materials.new('Sea stone | reference spectrum')
    mat.use_nodes = True; nodes = mat.node_tree.nodes; nodes.clear()
    out = nodes.new('ShaderNodeOutputMaterial'); bs = nodes.new('ShaderNodeBsdfPrincipled')
    bs.inputs['Roughness'].default_value = 0.88; bs.inputs['Metallic'].default_value = 0.02
    col = nodes.new('ShaderNodeVertexColor')
    col.layer_name = 'Reference spectrum'
    tex_path = PROJECT / 'assets/textures/coastal_rock_grey.jpg'
    norm_path = PROJECT / 'assets/textures/coastal_rock_normal.png'
    if tex_path.exists():
        img = bpy.data.images.get('coastal_rock_grey.jpg') or bpy.data.images.load(str(tex_path))
        tex_node = nodes.new('ShaderNodeTexImage'); tex_node.image = img
        mix = nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'; mix.blend_type = 'MULTIPLY'
        mix.inputs[0].default_value = 1.0
        mat.node_tree.links.new(tex_node.outputs['Color'], mix.inputs[6])
        mat.node_tree.links.new(col.outputs['Color'], mix.inputs[7])
        mat.node_tree.links.new(mix.outputs[2], bs.inputs['Base Color'])
    else:
        mat.node_tree.links.new(col.outputs['Color'], bs.inputs['Base Color'])
    if norm_path.exists():
        norm_img = bpy.data.images.get('coastal_rock_normal.png') or bpy.data.images.load(str(norm_path))
        norm_img.colorspace_settings.name = 'Non-Color'
        norm_node = nodes.new('ShaderNodeTexImage'); norm_node.image = norm_img
        norm_map = nodes.new('ShaderNodeNormalMap'); norm_map.inputs['Strength'].default_value = 0.8
        mat.node_tree.links.new(norm_node.outputs['Color'], norm_map.inputs['Color'])
        mat.node_tree.links.new(norm_map.outputs['Normal'], bs.inputs['Normal'])
    mat.node_tree.links.new(bs.outputs['BSDF'], out.inputs['Surface'])
    for index, name in enumerate(SEA):
        o = obj(name)
        if not o.data.get('reference_spectrum'):
            o.data = o.data.copy()
            bm = bmesh.new(); bm.from_mesh(o.data)
            bmesh.ops.triangulate(bm, faces=list(bm.faces))
            bmesh.ops.subdivide_edges(bm, edges=list(bm.edges), cuts=2, use_grid_fill=True)
            bm.to_mesh(o.data); bm.free(); o.data.update()
        me = o.data; me.materials.clear(); me.materials.append(mat)
        colors = me.color_attributes.get('Reference spectrum') or me.color_attributes.new(name='Reference spectrum', type='FLOAT_COLOR', domain='POINT')
        for v, c in zip(me.vertices, colors.data):
            p = o.matrix_world @ v.co
            c.color_srgb = natural_stone(p)
        for poly in me.polygons: poly.material_index = 0
        me['reference_spectrum'] = True
        o['palette_reference'] = 'Natural Mediterranean weathered coastal limestone with waterline wetness'

def export(path,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)

def bvh(o):
    return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[p.vertices[:] for p in o.data.polygons])

def report():
    result={'saved':bpy.data.filepath,'hidden':{n:obj(n).hide_render for n in FERNS},'meshes':{},'positions':{}}
    for name in [*SEA,'Pot_Stairs_Bot_L_leaves']:
        o=obj(name);h=hashlib.sha256()
        for v in o.data.vertices:h.update(struct.pack('fff',*v.co))
        colors=o.data.color_attributes.get('Reference spectrum')
        if colors:
            for c in colors.data:h.update(struct.pack('ffff',*c.color))
        result['meshes'][name]={'vertices':len(o.data.vertices),'sha256':h.hexdigest(),'colors':len(colors.data) if colors else 0}
    for name in ['Vase_Stairs_Plinth','Pot_Stairs_Bot_L_pot','Pot_Stairs_Bot_L_dirt','Pot_Stairs_Bot_L_leaves']:result['positions'][name]=list(obj(name).location)
    # Exact triangle clearance for the visible leaf blades against nearby stone.
    blade=obj('Pot_Stairs_Bot_L_leaves');hits={}
    ids={i for group in components(blade.data) if len(group)>=150 for i in group}
    blade_bvh=BVHTree.FromPolygons([blade.matrix_world@v.co for v in blade.data.vertices],[p.vertices[:] for p in blade.data.polygons if all(i in ids for i in p.vertices)])
    for o in bpy.data.objects:
        if o.type=='MESH' and 'Central_Stair_' in o.name:
            overlap=blade_bvh.overlap(bvh(o))
            if overlap:hits[o.name]=len(overlap)
    assert not hits,hits
    floor=.05
    # Stems deliberately enter the pot; broad leaf blades must clear the floor.
    blade_min=min((blade.matrix_world@blade.data.vertices[i].co).z for group in components(blade.data) if len(group)>=150 for i in group)
    assert blade_min>floor+.05,blade_min
    result['leaf_floor_clearance']=blade_min-floor
    urn=obj('Vase_Stairs_Plinth');overlaps=[]
    for o in bpy.data.objects:
        if o.type=='MESH' and not o.hide_render and (o.name.startswith('Central_Stair_') or o.name in ['Fountain_Hollow_Stone_Bowl-col','Nymphaeum_Fountain_Niche-col','Balustrades_With_Outfall_Notch','Rill_Continuous_Bank-col','Rill_Continuous_Bank.001-col']):
            if bvh(urn).overlap(bvh(o)):overlaps.append(o.name)
    assert not overlaps,overlaps
    result['urn_architecture_overlaps']=overlaps
    return result

def build():
    assert Path(bpy.data.filepath)==PROJECT/'assets/mediterranean_temple.blend'
    turns=leaves();color_rocks()
    for name in FERNS:obj(name).hide_render=True;obj(name).hide_set(True)
    for suffix in ['pot','dirt','leaves']:
        o=obj('Pot_Stairs_Bot_L_'+suffix)
        if not o.get('clearance_reseated'):o.location+=Vector((.30,-.35,0));o['clearance_reseated']=True
    urn=obj('Vase_Stairs_Plinth');urn.location=Vector((5.6,5.9,3.54855))
    bpy.context.view_layer.update()
    export(PROJECT/'assets/offshore_spectrum.glb',[obj(n)for n in SEA])
    temp=bpy.data.objects.new('Stair_Pot_Leaves_Repaired',obj('Pot_Stairs_Bot_L_leaves').data);bpy.context.scene.collection.objects.link(temp)
    export(PROJECT/'assets/stair_pot_leaves.glb',[temp]);bpy.data.objects.remove(temp,do_unlink=True)
    data={'removed_props':FERNS,'positions':{},'sea_rocks':SEA,'guard_boxes':[{'center':[3.3,.5,11.8],'size':[11.92,1.,.32]},{'center':[9.1,.5,7.5],'size':[.32,1.,9.]},{'center':[6.7,4.,-7.5],'size':[.32,1.,18.]}]}
    for name in ['Vase_Stairs_Plinth','Fountain_Offering_Vase',*['Pot_Stairs_Bot_L_'+s for s in ['pot','dirt','leaves']]]:
        p=obj(name).location;data['positions'][name]=[p.x,p.z,-p.y]
    PLAN.write_text(json.dumps(data,indent=2)+'\n')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    result=report();result['leaf_rotations']=turns;return result

def install():
    assert Path(bpy.data.filepath)==ART
    names=[n+'-col' for n in SEA]+['Pot_Stairs_Bot_L_leaves']
    targets=[obj(n)for n in SEA]+[obj('Pot_Stairs_Bot_L_leaves')]
    with bpy.data.libraries.load(str(PROJECT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):dst.objects=names
    leaf=None
    for target,source in zip(targets,dst.objects):
        target.data=source.data
        if 'leaves' in target.name:leaf=target.data
        bpy.data.objects.remove(source,do_unlink=True)
    for name in ['Pot_Stairs_Bot_R_leaves','Pot_Pool_2_leaves']:obj(name).data=leaf
    data=json.loads(PLAN.read_text())
    for name,p in data['positions'].items():obj(name).location=(p[0],-p[2],p[1])
    for name in FERNS:obj(name).hide_render=True;obj(name).hide_set(True)
    bpy.context.view_layer.update()
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return report()
