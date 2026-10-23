"""Check the saved ID card against coat geometry in actual Godot task/gait poses."""
import json
from pathlib import Path
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

OUT=Path('/home/allister/Projects/live-aligned-previews/site-finish-2026-10-18/scientist')


def validate():
    obj=bpy.data.objects['Dr Vale | character mesh']
    poses=json.loads((OUT/'poses.json').read_text())
    rest=np.array([(v.co.x,v.co.z,-v.co.y,1.) for v in obj.data.vertices])
    weights={g.name:[] for g in obj.vertex_groups}
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            if group.weight>0:weights[obj.vertex_groups[group.group].name].append((vertex.index,group.weight))
    weights={name:(np.array([v[0] for v in rows]),np.array([v[1] for v in rows])) for name,rows in weights.items() if rows}
    coat=[];card=[]
    for polygon in obj.data.polygons:
        material=obj.data.materials[polygon.material_index].name
        if material.startswith('Coat • ivory twill'):coat.append(tuple(polygon.vertices))
        if material.startswith('Shirt • pearl'):card.append(tuple(polygon.vertices))
    indices=sorted({v for f in card for v in f})
    assert card and coat
    misses=[];crossings=[];minimum=1.;maximum=0.;probes=0
    for pose in poses:
        vertices=np.zeros_like(rest)
        for bone,(ids,w) in weights.items():
            matrix=np.array(pose['bones'][bone])
            vertices[ids]+=(rest[ids]@matrix.T)*w[:,None]
        tree=BVHTree.FromPolygons(vertices[:,:3].tolist(),coat)
        badge=BVHTree.FromPolygons(vertices[:,:3].tolist(),card)
        overlap=tree.overlap(badge)
        if overlap:crossings.append({'pose':pose['label'],'triangles':len(overlap)})
        for i in indices:
            p=Vector(vertices[i,:3]);hit=tree.ray_cast(p,Vector((0,0,-1)),.12)[0]
            probes+=1
            if hit is None:misses.append({'pose':pose['label'],'vertex':i})
            else:
                gap=p.z-hit.z;minimum=min(minimum,gap);maximum=max(maximum,gap)
    report={'saved':bpy.data.filepath,'poses':len(poses),'card_vertices':len(indices),
        'coat_clearance_probes':probes,'minimum_clearance_m':minimum,'maximum_clearance_m':maximum,
        'card_coat_intersections':crossings,'unsupported_vertices':misses[:10]}
    (OUT/'badge_validation.json').write_text(json.dumps(report,indent=2))
    assert not crossings and not misses,report
    assert minimum>.004,minimum
    return report
