"""Check front/back trouser-coat clearance in actual Godot gait/stair poses.

Run in the saved character lineup after scripts/check_visual_fit.gd. The runtime
exports skinning matrices; this checks the authoring mesh through those poses.
"""
import json
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def validate():
    folder=Path('/tmp/live-aligned-fit')
    poses=json.loads((folder/'scientist_poses.json').read_text())
    obj=bpy.data.objects['Dr Vale | character mesh']
    # Blender (x,y,z) -> glTF/Godot (x,z,-y), independent of lineup placement.
    rest=np.array([(v.co.x,v.co.z,-v.co.y,1.) for v in obj.data.vertices])
    weights={g.name:[] for g in obj.vertex_groups}
    for vertex in obj.data.vertices:
        for group in vertex.groups:
            if group.weight>0:weights[obj.vertex_groups[group.group].name].append((vertex.index,group.weight))
    weights={name:(np.array([v[0] for v in rows]),np.array([v[1] for v in rows]))
             for name,rows in weights.items() if rows}
    coat=[];lower_coat=[];pant_faces=[];trousers=set()
    for polygon in obj.data.polygons:
        name=obj.data.materials[polygon.material_index].name
        if name.startswith('Coat • ivory twill'):
            coat.append(tuple(polygon.vertices))
            if min(rest[i,1] for i in polygon.vertices)<1.08:
                lower_coat.append(tuple(polygon.vertices))
        if name.startswith('Trousers • graphite'):
            trousers.update(polygon.vertices);pant_faces.append(tuple(polygon.vertices))
    probes=[i for i in trousers if .77<=rest[i,1]<=1.035 and rest[i,2]<-.012]
    missing=[];tested=0;crossings=[]
    for pose in poses:
        vertices=np.zeros_like(rest)
        for bone,(indices,weight) in weights.items():
            matrix=np.array(pose['bones'][bone])
            vertices[indices]+=(rest[indices]@matrix.T)*weight[:,None]
        bvh=BVHTree.FromPolygons(vertices[:,:3].tolist(),coat)
        lower_bvh=BVHTree.FromPolygons(vertices[:,:3].tolist(),lower_coat)
        pants_bvh=BVHTree.FromPolygons(vertices[:,:3].tolist(),pant_faces)
        overlaps=lower_bvh.overlap(pants_bvh)
        if overlaps:
            crossings.append({'phase':pose['phase'],'site':pose['site'],'intersections':len(overlaps),'coat_rest_range': [rest[list({v for i,j in overlaps for v in lower_coat[i]}),:3].min(axis=0).tolist(),rest[list({v for i,j in overlaps for v in lower_coat[i]}),:3].max(axis=0).tolist()]})
        for i in probes:
            point=Vector(vertices[i,:3]);hit=bvh.ray_cast(point,Vector((0,0,-1)),1.)[0]
            tested+=1
            if hit is None:missing.append({'phase':pose['phase'],'site':pose['site'],'vertex':i,'point':list(point)})
    result={'poses':len(poses),'rear_trouser_probes_per_pose':len(probes),
            'coverage_rays':tested,'uncovered_rear_vertices':len(missing),
            'examples':missing[:12],'poses_with_pants_coat_intersections':len(crossings),'crossing_examples':crossings[:12]}
    (folder/'coat_validation.json').write_text(json.dumps(result,indent=2))
    assert not missing, 'Rear trousers exposed: see coat_validation.json'
    assert not crossings, 'Trousers intersect the coat: see coat_validation.json'
    return result
