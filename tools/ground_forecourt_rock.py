"""Fit the forecourt boulder's underside to its actual terrain and export it alone.

Run build_and_export() in the optimized map, then install_saved() in the artistic
map. The top surface is preserved and the boulder is seated 0.65 m lower;
the lower shell is embedded into the hill. Runtime replaces only this mesh and its convex proxy.
"""
import json
from pathlib import Path

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
NAME='Large_Rock_Main_02-convcol'


def world_bvh(obj):
    vertices=[obj.matrix_world@v.co for v in obj.data.vertices]
    return BVHTree.FromPolygons(vertices,[tuple(p.vertices) for p in obj.data.polygons])


def build_and_export():
    assert Path(bpy.data.filepath)==PROJECT/'assets/mediterranean_temple.blend'
    rock=bpy.data.objects[NAME]
    assert not rock.get('grounded_underside'), 'Already repaired: use the scoped backup to rebuild'
    rock.data=rock.data.copy()
    rock.location.z-=.65
    bpy.context.view_layer.update()
    bpy.ops.object.select_all(action='DESELECT');rock.select_set(True);bpy.context.view_layer.objects.active=rock
    mod=rock.modifiers.new('Underside terrain sampling','SUBSURF');mod.subdivision_type='SIMPLE';mod.levels=1
    bpy.ops.object.modifier_apply(modifier=mod.name)
    ground=world_bvh(bpy.data.objects['Cliff_Terrain-col'])
    # Preserve the exposed upper shell exactly, then close it down into the
    # terrain. A shell projected from above avoids leaving high side triangles
    # suspended at the thin tips of the original flattened rock.
    upper=[tuple(p.vertices) for p in rock.data.polygons
           if (rock.matrix_world.to_3x3()@p.normal).z>.001]
    used=sorted({i for face in upper for i in face});remap={old:new for new,old in enumerate(used)}
    vertices=[rock.data.vertices[i].co.copy() for i in used];count=len(vertices)
    inverse=rock.matrix_world.inverted()
    for index in used:
        point=rock.matrix_world@rock.data.vertices[index].co
        floor=ground.ray_cast(Vector((point.x,point.y,60)),Vector((0,0,-1)))[0]
        assert floor is not None, 'Rock footprint has no terrain'
        point.z=min(point.z-.10,floor.z-.20)
        vertices.append(inverse@point)
    faces=[];edges={}
    for face in upper:
        ids=tuple(remap[i] for i in face);faces.append(ids)
        faces.append(tuple(i+count for i in reversed(ids)))
        for a,b in zip(ids,ids[1:]+ids[:1]):
            key=tuple(sorted((a,b)))
            if key in edges:edges[key]=None
            else:edges[key]=(a,b)
    for edge in edges.values():
        if edge:
            a,b=edge;faces.append((a,a+count,b+count,b))
    materials=list(rock.data.materials)
    fitted=bpy.data.meshes.new('Forecourt boulder with terrain-fitted lower shell')
    fitted.from_pydata(vertices,[],faces);fitted.update()
    for material in materials:fitted.materials.append(material)
    for polygon in fitted.polygons:polygon.use_smooth=True
    rock.data=fitted;changed=count;refinements=0
    bpy.context.view_layer.update()
    rock['grounded_underside']=True
    rock['grounding_embed_m']=.20
    # Export a clean mesh node without the historical -convcol import suffix.
    clone=rock.copy();clone.data=rock.data;clone.name='Forecourt_Rock_Grounded';bpy.context.scene.collection.objects.link(clone)
    bpy.ops.object.select_all(action='DESELECT');clone.select_set(True);bpy.context.view_layer.objects.active=clone
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/forecourt_rock_grounded.glb'),export_format='GLB',
                              use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
    bpy.data.objects.remove(clone,do_unlink=True)
    sample=world_bvh(rock);bounds=[rock.matrix_world@Vector(p) for p in rock.bound_box]
    gaps=[]
    for i in range(81):
        x=min(v.x for v in bounds)+(max(v.x for v in bounds)-min(v.x for v in bounds))*(i+.5)/81
        for j in range(113):
            y=min(v.y for v in bounds)+(max(v.y for v in bounds)-min(v.y for v in bounds))*(j+.5)/113
            bottom=sample.ray_cast(Vector((x,y,-15)),Vector((0,0,1)))[0]
            floor=ground.ray_cast(Vector((x,y,60)),Vector((0,0,-1)))[0]
            if bottom and floor:gaps.append(bottom.z-floor.z)
    report={'name':'Large_Rock_Main_02','source_object':NAME,'mesh':'res://assets/forecourt_rock_grounded.glb',
            'ground_samples':len(gaps),'maximum_underside_gap_m':max(gaps),
            'underside_vertices_seated':changed,'silhouette_refinements':refinements,'embed_m':.20,'position':[rock.location.x,rock.location.z,-rock.location.y]}
    (PROJECT/'assets/forecourt_rock_grounding.json').write_text(json.dumps(report,indent=2))
    (OUT/'forecourt_rock_grounding.json').write_text(json.dumps(report,indent=2))
    # Keep the shared placement override in agreement with both editable maps.
    for path in [PROJECT/'assets/bridge_approach_repairs.json',OUT/'bridge_approach_repairs.json']:
        plan=json.loads(path.read_text())
        row=next(r for r in plan['grounded_props'] if r['name']=='Large_Rock_Main_02')
        row['position']=report['position']
        row['blender_position']=list(rock.location)
        row['grounded_mesh']=report['mesh']
        path.write_text(json.dumps(plan,indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,**report}


def install_saved():
    assert Path(bpy.data.filepath)==OUT/'mediterranean_temple_improved.blend'
    target=bpy.data.objects['Large_Rock_Main_02']
    with bpy.data.libraries.load(str(PROJECT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):dst.objects=[NAME]
    source=dst.objects[0]
    bpy.context.scene.collection.objects.link(source)
    bpy.context.view_layer.update()
    target.data=source.data;target.matrix_world=source.matrix_world.copy()
    bpy.context.view_layer.update()
    bpy.data.objects.remove(source,do_unlink=True)
    target['grounded_underside']=True;target['grounding_embed_m']=.20
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,'vertices':len(target.data.vertices)}
