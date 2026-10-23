"""Extend the truncated western pagoda beach into the existing seabed via Blender MCP."""
import bpy, bmesh, hashlib, json, math
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
NAME = 'North_Pagoda_Pagoda_Meadow_Ground'
STEPS = 20


def digest(obj):
    h = hashlib.sha256()
    coords=np.empty(len(obj.data.vertices)*3,dtype=np.float32)
    obj.data.vertices.foreach_get('co',coords);h.update(coords.tobytes())
    loops=np.empty(len(obj.data.loops),dtype=np.int32)
    obj.data.loops.foreach_get('vertex_index',loops);h.update(loops.tobytes())
    counts=np.empty(len(obj.data.polygons),dtype=np.int32)
    obj.data.polygons.foreach_get('loop_total',counts);h.update(counts.tobytes())
    return h.hexdigest()


def scene_snapshot():
    return {o.name: {'mesh': digest(o), 'matrix': [list(r) for r in o.matrix_world]}
            for o in bpy.context.scene.objects if o.type == 'MESH' and o.name != NAME}


def save():
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath, compress=True)


def build():
    o = bpy.data.objects[NAME]
    assert not o.get('western_shore_closed'), 'Repair already installed'
    before = scene_snapshot()
    old = o.data
    bm = bmesh.new(); bm.from_mesh(old)
    west_x = min(v.co.x for v in bm.verts)
    edges = [e for e in bm.edges if e.is_boundary and all(abs(v.co.x-west_x) < .001 for v in e.verts)]
    assert len(edges) == 63, len(edges)
    bm.verts.ensure_lookup_table()
    ids = sorted({v.index for e in edges for v in e.verts}, key=lambda i: old.vertices[i].co.y)
    assert len(ids) == 64
    original_vertices = [tuple(v.co) for v in old.vertices]
    vertices = list(original_vertices)
    faces = [tuple(p.vertices) for p in old.polygons]
    material_ids = [p.material_index for p in old.polygons]
    old_attr = old.attributes.get('sidewalk_original_z')
    heights = [d.value for d in old_attr.data] if old_attr else [v.co.z for v in old.vertices]
    floor = bpy.data.objects['Ocean_Seabed']
    floor_bvh = BVHTree.FromObject(floor, bpy.context.evaluated_depsgraph_get())
    by_xy = {(round(v.co.x, 4), round(v.co.y, 4)): v.co.z for v in old.vertices}
    dx = 56/86
    rows = []
    samples = []
    for idx in ids:
        p = old.vertices[idx].co
        # Vary the submerged toe in plan; retain the exact existing landward seam.
        width = 11.5 + .9*math.sin(p.y*.19) + .45*math.sin(p.y*.43+.6)
        end_x = p.x-width
        hit, _, _, _ = floor_bvh.ray_cast(Vector((end_x, p.y, 20)), Vector((0,0,-1)))
        assert hit is not None
        end_z = hit.z-.40
        inner_z = by_xy[(round(p.x+dx, 4), round(p.y, 4))]
        gradient = max(0., min((inner_z-p.z)/dx, 1.1, 2*(p.z-end_z)/width))
        row = [idx]
        for step in range(1, STEPS+1):
            t = step/STEPS
            h00 = 2*t*t*t-3*t*t+1
            h10 = t*t*t-2*t*t+t
            h01 = -2*t*t*t+3*t*t
            z = h00*p.z+h10*(-gradient*width)+h01*end_z
            if idx in (ids[0],ids[-1]):
                side_hit,_,_,_=floor_bvh.ray_cast(Vector((p.x-width*t,p.y,20)),Vector((0,0,-1)))
                assert side_hit is not None
                z=min(z,side_hit.z-.4)
            row.append(len(vertices))
            vertices.append((p.x-width*t,p.y,z)); heights.append(z)
        rows.append(row)
        samples.append({'seam':list(p),'toe':[end_x,p.y,end_z], 'floor':hit.z})
    for j in range(len(rows)-1):
        for s in range(STEPS):
            a,b,c,d=rows[j][s],rows[j+1][s],rows[j+1][s+1],rows[j][s+1]
            faces.extend([(a,b,c),(a,c,d)]); material_ids.extend([0,0])
    bm.free()
    mesh = bpy.data.meshes.new('Pagoda_Meadow_Ground_Closed_West_Shore')
    mesh.from_pydata(vertices,[],faces); mesh.update()
    for mat in old.materials: mesh.materials.append(mat)
    uv = mesh.uv_layers.new(name='UVMap')
    for i,p in enumerate(mesh.polygons):
        p.use_smooth=True; p.material_index=material_ids[i]
        for li in p.loop_indices:
            co = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=(co.x*.25,co.y*.25)
    attr = mesh.attributes.new('sidewalk_original_z','FLOAT','POINT')
    for d,z in zip(attr.data,heights): d.value=z
    o.data=mesh
    o['western_shore_closed']=True
    bpy.context.view_layer.update()
    assert before == scene_snapshot(), 'Unrelated scene geometry changed'
    assert [tuple(v.co) for v in mesh.vertices[:len(original_vertices)]] == original_vertices
    assert [tuple(p.vertices) for p in mesh.polygons[:len(old.polygons)]] == [tuple(p.vertices) for p in old.polygons]
    # A single scoped mesh keeps the already delivered pagoda structure untouched.
    bpy.ops.object.select_all(action='DESELECT'); o.select_set(True); bpy.context.view_layer.objects.active=o
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/pagoda_shore.glb'),export_format='GLB',use_selection=True,
                              export_cameras=False,export_lights=False,export_animations=False)
    bpy.data.libraries.write(str(OUT/'pagoda_shore.blend'),{o},fake_user=True,compress=True)
    report={'mesh':NAME,'original_vertices':len(original_vertices),'original_faces':len(old.polygons),
            'vertices':len(mesh.vertices),'faces':len(mesh.polygons),'added_vertices':len(vertices)-len(original_vertices),
            'buried_toe_rows':samples,'sha256':digest(o),'preserved_other_meshes':len(before)}
    (ROOT/'assets/pagoda_shore.json').write_text(json.dumps(report,indent=2))
    (OUT/'pagoda_shore.json').write_text(json.dumps(report,indent=2))
    save()
    return report


def install():
    before=scene_snapshot()
    target=bpy.data.objects[NAME]
    with bpy.data.libraries.load(str(OUT/'pagoda_shore.blend'),link=False) as (source,dest): dest.objects=[NAME]
    src=dest.objects[0]; target.data=src.data; bpy.data.objects.remove(src,do_unlink=True)
    target['western_shore_closed']=True
    assert before==scene_snapshot(), 'Unrelated scene geometry changed'
    save()
    return {'saved':bpy.data.filepath,'sha256':digest(target),'other_meshes_unchanged':len(before)}


def audit():
    o=bpy.data.objects[NAME]
    plan=json.loads((ROOT/'assets/pagoda_shore.json').read_text())
    assert digest(o)==plan['sha256']
    return {'saved':bpy.data.filepath,'sha256':digest(o),'vertices':len(o.data.vertices),'faces':len(o.data.polygons)}


def finalize_contacts():
    """Seat the two submerged side seams against the existing rolling floor."""
    o=bpy.data.objects[NAME]
    floor=BVHTree.FromObject(bpy.data.objects['Ocean_Seabed'],bpy.context.evaluated_depsgraph_get())
    count=0
    for v in o.data.vertices:
        if v.co.x>=39.254 or min(abs(v.co.y-31.0731716),abs(v.co.y-77.1707306))>.001: continue
        p,_,_,_=floor.ray_cast(Vector((v.co.x,v.co.y,20)),Vector((0,0,-1)))
        assert p is not None
        if v.co.z>p.z-.4: v.co.z=p.z-.4; count+=1
    o.data.update()
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/pagoda_shore.glb'),export_format='GLB',use_selection=True,
                              export_cameras=False,export_lights=False,export_animations=False)
    bpy.data.libraries.write(str(OUT/'pagoda_shore.blend'),{o},fake_user=True,compress=True)
    report=json.loads((ROOT/'assets/pagoda_shore.json').read_text())
    report['sha256']=digest(o); report['seated_side_vertices']=count
    for p in [ROOT/'assets/pagoda_shore.json',OUT/'pagoda_shore.json']: p.write_text(json.dumps(report,indent=2))
    save()
    return {'saved':bpy.data.filepath,'side_contacts_seated':count,'sha256':digest(o)}
