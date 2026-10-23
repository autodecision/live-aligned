"""Repair the pagoda sidewalk through Blender MCP without rebuilding the landmark.

Run build_and_export() against the artistic scene, clear_pagoda_meadow.gd in
Godot, then install_saved() against both authoritative Blender scenes.
"""
import bpy
import json
import math
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import delaunay_2d_cdt

PROJECT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')

def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)))
    return t*t*(3.-2.*t)

def cubic(a,b,c,d,t):return a*(1-t)**3+b*(3*t*(1-t)**2)+c*(3*t*t*(1-t))+d*t**3

def make_routes(plan):
    old=plan.get('sidewalk_previous_path',plan['path'])
    p=[Vector((v[0],-v[2])) for v in old]
    bridges=json.loads((PROJECT/'assets/island_bridges.json').read_text())['bridges']
    north=next(b for b in bridges if b['name']=='Main_North')
    south=next(b for b in bridges if b['name']=='North_South')
    a=Vector((north['end'][0],-north['end'][2]));d=Vector(north['direction'][:2])
    j=Vector((south['start'][0],-south['start'][2]))-Vector(south['direction'][:2])*2.2
    yaw=plan['yaw'];forward=Vector((-math.sin(yaw),math.cos(yaw)))
    e=Vector((92.,64.))+forward*(-10.41)
    sections=[]
    def curve(a,b,c,d,steps):
        for i in range(steps):sections.append(cubic(a,b,c,d,i/steps))
    curve(a-d*.035,a+d*.9,p[8]-Vector((.8,.1)),p[8],9)
    curve(p[8],p[8]+Vector((2.,.25)),j-Vector((2.,0.)),j,21)
    curve(j,j+Vector((2.,0.)),p[34]-Vector((1.7,0.)),p[34],18)
    for i in range(34,46):
        count=max(1,math.ceil((p[i+1]-p[i]).length/.4))
        for k in range(count):sections.append(p[i].lerp(p[i+1],k/count))
    curve(p[46],p[46]+Vector((.8,2.3)),e-forward*2.4,e,24)
    sections.append(e)
    lengths=[0.]
    for a,b in zip(sections,sections[1:]):lengths.append(lengths[-1]+(b-a).length)
    sj=lengths[30];s_high=lengths[48];s_low=lengths[68]
    anchors=[(0.,north['end'][1]),(sj-2.,south['start'][1]),(sj+2.,south['start'][1]),
             (s_high,5.24),(s_low,4.48),(lengths[-1],5.535)]
    assert all(b[0]>a[0] for a,b in zip(anchors,anchors[1:])),anchors
    heights=[];widths=[]
    for s in lengths:
        z=anchors[-1][1]
        for (s0,z0),(s1,z1) in zip(anchors,anchors[1:]):
            if s<=s1:z=z0+(z1-z0)*smooth(s0,s1,s);break
        heights.append(z)
        width=1.12+.98*(1.-smooth(0.,2.8,s))+.78*smooth(lengths[-1]-4.5,lengths[-1]-.8,s)
        widths.append(width)
    main={'points':[Vector((p.x,p.y,h)) for p,h in zip(sections,heights)],'widths':widths,'lengths':lengths}
    a=Vector((south['start'][0],-south['start'][2],south['start'][1]))
    # The bridge branch joins the main paving behind its open end.
    branch={'points':[a+Vector((*south['direction'][:2],0.))*.035,a.lerp(Vector((j.x,j.y,a.z)),.5),Vector((j.x,j.y,a.z))],
            'widths':[2.1,1.48,1.12]}
    return [main,branch],old

def nearest(p,route):
    best=None
    for i,(a,b) in enumerate(zip(route['points'],route['points'][1:])):
        d=Vector((b.x-a.x,b.y-a.y));v=Vector((p.x-a.x,p.y-a.y))
        t=max(0.,min(1.,v.dot(d)/max(d.length_squared,1e-8)))
        distance=(v-d*t).length
        if best is None or distance<best[0]:
            best=(distance,a.z+(b.z-a.z)*t,route['widths'][i]*(1-t)+route['widths'][i+1]*t)
    return best

def influence(p,routes):
    candidates=[nearest(p,r) for r in routes]
    distance,z,width=min(candidates,key=lambda row:row[0]-row[2])
    weight=1.-smooth(width+.35,width+3.25,distance)
    return weight,z-.07

def grade(obj,routes):
    mesh=obj.data;attr=mesh.attributes.get('sidewalk_original_z')
    if attr is None:
        attr=mesh.attributes.new('sidewalk_original_z','FLOAT','POINT')
        for v,d in zip(mesh.vertices,attr.data):d.value=v.co.z
    count=0
    for v,d in zip(mesh.vertices,attr.data):
        p=obj.matrix_world@v.co;p.z=d.value
        if p.z<=-9.99:continue
        w,target=influence(p,routes)
        if w<=.001:continue
        value=p.z*(1.-w)+target*w
        if abs(value-p.z)>.0001:count+=1
        v.co.z=value
    mesh.update()
    return count

def bvh(obj):return BVHTree.FromObject(obj,bpy.context.evaluated_depsgraph_get())
def height(surfaces,x,y):
    values=[]
    for surface in surfaces:
        p,_,_,_=surface.ray_cast(Vector((x,y,60.)),Vector((0.,0.,-1.)))
        if p:values.append(p.z)
    return max(values) if values else None

def route_data(route):
    return {'path':[[p.x,p.z,-p.y] for p in route['points']],'half_widths':route['widths']}

def build_and_export():
    plan=json.loads((PROJECT/'assets/north_pagoda.json').read_text());routes,old_path=make_routes(plan)
    names=['Distant_Islands','Landing_Bank_Main_North','North_Pagoda_Pagoda_Meadow_Ground']
    objects=[bpy.data.objects[n] for n in names]
    counts={o.name:grade(o,routes) for o in objects};bpy.context.view_layer.update()
    surfaces=[bvh(o) for o in objects]
    props=[]
    for obj in list(bpy.context.scene.objects):
        if obj.type!='MESH' or not obj.name.startswith(('Island_North_Olive_','Large_Rock_North_')):continue
        if obj.name=='Island_North_Olive_02':obj.location.x=67.7;obj.location.y=44.75;bpy.context.view_layer.update()
        points=[obj.matrix_world@v.co for v in obj.data.vertices];bottom=min(p.z for p in points)
        foot=[p for p in points if p.z<bottom+.16];foot=foot[::max(1,len(foot)//96)]
        if obj.name!='Island_North_Olive_02' and not any(influence(p,routes)[0]>.001 for p in foot):continue
        offsets=[height(surfaces,p.x,p.y)-p.z for p in foot if height(surfaces,p.x,p.y) is not None]
        obj.location.z+=min(offsets)-.035
        props.append({'name':obj.name,'blender_position':list(obj.location),'position':[obj.location.x,obj.location.z,-obj.location.y]})
    lamp_rows=json.loads((PROJECT/'assets/island_lantern_positions.json').read_text());lamps=[]
    for row in lamp_rows:
        if row['island']!='North':continue
        x,y,z=row['blender_position']
        if influence(Vector((x,y,z)),routes)[0]<=.001:continue
        samples=[height(surfaces,x+.245*math.cos(i*math.tau/32),y+.245*math.sin(i*math.tau/32)) for i in range(32)]
        z=min(samples)-.02;row['blender_position']=[x,y,z];row['position']=[x,z,-y];lamps.append(row['name'])
    for p in [PROJECT/'assets/island_lantern_positions.json',OUT/'island_lantern_positions.json']:p.write_text(json.dumps(lamp_rows,indent=2))
    moved_grass=0
    for name in ['gscatter_ground_cover_instances.json','north_pagoda_cover.json']:
        path=PROJECT/'assets'/name;rows=json.loads(path.read_text())
        for row in rows:
            p=Vector((row['origin'][0],-row['origin'][2],row['origin'][1]))
            if influence(p,routes)[0]>.001:
                h=height(surfaces,p.x,p.y)
                if h is not None:row['origin'][1]=h-.012;moved_grass+=1
        path.write_text(json.dumps(rows,separators=(',',':')))
    # Clone the affected native ground objects only for scoped export/library.
    clones=[]
    for obj,name in zip(objects[:2],['Sidewalk_Distant_Islands','Sidewalk_Landing_Bank_Main_North']):
        clone=obj.copy();clone.name=name;bpy.context.scene.collection.objects.link(clone);clones.append(clone)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in clones:obj.select_set(True)
    bpy.context.view_layer.objects.active=clones[0]
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/pagoda_sidewalk_terrain.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
    bpy.data.libraries.write(str(OUT/'pagoda_sidewalk_terrain.blend'),set(clones),fake_user=True,compress=True)
    # Modify only the sidewalk and its ground in the existing reusable landmark.
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'north_pagoda.blend'))
    stone=bpy.data.objects['North_Pagoda_Pagoda_Limestone'];mesh=stone.data
    if not stone.get('sidewalk_path_separated'):
        prefix_polys=len(mesh.polygons)-3*(len(old_path)-1)
        assert prefix_polys==78,prefix_polys
        faces=[tuple(poly.vertices) for poly in mesh.polygons[:prefix_polys]];used=max(max(f) for f in faces)+1
        replacement=bpy.data.meshes.new('Pagoda_Limestone_Structure');replacement.from_pydata([tuple(v.co) for v in mesh.vertices[:used]],[],faces)
        for mat in mesh.materials:replacement.materials.append(mat)
        stone.data=replacement;stone['sidewalk_path_separated']=True
    uv=stone.data.uv_layers.get('UVMap') or stone.data.uv_layers.new(name='UVMap')
    for poly in stone.data.polygons:
        dominant=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=dominant]
        for li in poly.loop_indices:
            co=stone.data.vertices[stone.data.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]*.3,co[axes[1]]*.3)
    grade(bpy.data.objects['North_Pagoda_Pagoda_Meadow_Ground'],routes)
    vertices=[];input_faces=[]
    for route in routes:
        points=route['points'];edges=[]
        for i,p in enumerate(points):
            d=points[min(i+1,len(points)-1)]-points[max(0,i-1)];d.z=0.;d.normalize();n=Vector((-d.y,d.x,0.))
            edges.append((len(vertices),len(vertices)+1));vertices.extend([Vector((p.x+n.x*route['widths'][i],p.y+n.y*route['widths'][i])),Vector((p.x-n.x*route['widths'][i],p.y-n.y*route['widths'][i]))])
        for a,b in zip(edges,edges[1:]):input_faces.append([a[0],a[1],b[1],b[0]])
        vertices.extend(Vector((p.x,p.y)) for p in points)
    coords,_,faces,_,_,ids=delaunay_2d_cdt(vertices,[],input_faces,1,1e-5,True)
    top=[]
    for co in coords:
        near=[nearest(Vector((co.x,co.y,0.)),r) for r in routes]
        # The bridge branch and junction share the same flat elevation.
        z=min(near,key=lambda row:row[0])[1];top.append((co.x,co.y,z))
    # Retain only the union of the input faces. CDT emits each shared triangle once.
    faces=[tuple(f) for f,source_ids in zip(faces,ids) if source_ids]
    for i,face in enumerate(faces):
        a,b,c=[Vector(top[j]) for j in face[:3]]
        if (b-a).cross(c-a).z<0:faces[i]=tuple(reversed(face))
    from collections import Counter
    edge_count=Counter()
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):edge_count[tuple(sorted((a,b)))]+=1
    allverts=list(top);allfaces=list(faces)
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            if edge_count[tuple(sorted((a,b)))]!=1:continue
            c=len(allverts);allverts.extend([(top[a][0],top[a][1],top[a][2]-.18),(top[b][0],top[b][1],top[b][2]-.18)])
            allfaces.append((b,a,c,c+1))
    existing=bpy.data.objects.get('North_Pagoda_Pagoda_Sidewalk')
    if existing:bpy.data.objects.remove(existing,do_unlink=True)
    mesh=bpy.data.meshes.new('Pagoda_Continuous_Sidewalk');mesh.from_pydata(allverts,[],allfaces);mesh.update();mesh.materials.append(stone.data.materials[0]);uv=mesh.uv_layers.new(name='UVMap')
    for poly in mesh.polygons:
        dominant=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=dominant]
        for li in poly.loop_indices:
            co=mesh.vertices[mesh.loops[li].vertex_index].co;uv.data[li].uv=(co[axes[0]]*.3,co[axes[1]]*.3)
    obj=bpy.data.objects.new('North_Pagoda_Pagoda_Sidewalk',mesh);bpy.data.collections['North Pagoda'].objects.link(obj)
    collider=next(c for c in plan['colliders'] if c['type']=='trimesh')
    if 'sidewalk_previous_path' not in plan:collider['faces']=collider['faces'][:-6*(len(old_path)-1)]
    else:collider['faces']=collider['faces'][:plan['sidewalk_structure_collision_vertices']]
    structure_count=len(collider['faces'])
    for face in faces:
        for i in range(1,len(face)-1):collider['faces'].extend([list(top[face[0]]),list(top[face[i]]),list(top[face[i+1]])])
    plan['sidewalk_structure_collision_vertices']=structure_count
    plan['sidewalk_previous_path']=old_path;plan['path']=route_data(routes[0])['path'];plan['sidewalk_routes']=[route_data(r) for r in routes]
    plan['entry']=plan['path'][-1];plan['path_half_width']=1.12;plan['sidewalk_flush_bridge_landings']=True;plan['sidewalk_top_triangles']=len(faces)
    for path in [PROJECT/'assets/north_pagoda.json',OUT/'north_pagoda.json']:path.write_text(json.dumps(plan,indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'north_pagoda.blend'),compress=True)
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/north_pagoda.glb'),export_format='GLB',export_cameras=False,export_lights=False,export_animations=False)
    report={'graded_vertices':counts,'grounded_props':props,'reseated_lamps':lamps,'grass_reseated_before_clearing':moved_grass,'top_triangles':len(faces),'slab_thickness':.18,'bridge_landings':2,'uniform_riser_uvs':True}
    for path in [PROJECT/'assets/pagoda_sidewalk_repairs.json',OUT/'pagoda_sidewalk_repairs.json']:path.write_text(json.dumps(report,indent=2))
    return report


def install_saved():
    path=bpy.data.filepath;report=json.loads((PROJECT/'assets/pagoda_sidewalk_repairs.json').read_text())
    with bpy.data.libraries.load(str(OUT/'pagoda_sidewalk_terrain.blend'),link=False) as (src,dst):dst.objects=list(src.objects)
    for obj in dst.objects:
        name=obj.name.removeprefix('Sidewalk_');target=bpy.data.objects.get(name) or bpy.data.objects.get(name+'-col')
        assert target is not None,name;target.data=obj.data;bpy.data.objects.remove(obj,do_unlink=True)
    changed=['North_Pagoda_Pagoda_Limestone','North_Pagoda_Pagoda_Meadow_Ground','North_Pagoda_Pagoda_Sidewalk']
    for name in changed:
        obj=bpy.data.objects.get(name)
        if obj:bpy.data.objects.remove(obj,do_unlink=True)
    with bpy.data.libraries.load(str(OUT/'north_pagoda.blend'),link=False) as (src,dst):dst.objects=changed
    for obj in dst.objects:bpy.data.collections['North Pagoda'].objects.link(obj)
    for row in report['grounded_props']:
        obj=bpy.data.objects.get(row['name']) or bpy.data.objects.get(row['name']+'-col') or bpy.data.objects.get(row['name']+'-convcol')
        assert obj is not None,row['name'];obj.location=row['blender_position']
    for row in json.loads((PROJECT/'assets/island_lantern_positions.json').read_text()):
        obj=bpy.data.objects.get(row['name'])
        if obj:obj.location=row['blender_position']
    # Synchronize retained point attributes and clear exactly the runtime rows.
    import bmesh
    rows=json.loads((PROJECT/'assets/gscatter_ground_cover_instances.json').read_text());rows+=json.loads((PROJECT/'assets/north_pagoda_cover.json').read_text())
    lookup={(r['asset'],round(r['origin'][0],3),round(-r['origin'][2],3)):r['origin'][1] for r in rows}
    # Pagoda cover starts as double precision random samples. Rebuild its three
    # point meshes directly, avoiding rounding-boundary loss on Blender float32.
    pagoda_rows=json.loads((PROJECT/'assets/north_pagoda_cover.json').read_text())
    for i in range(3):
        obj=bpy.data.objects.get(f'North_Pagoda_Meadow_{i}')
        if obj is None:continue
        points=[r for r in pagoda_rows if r['asset']==f'GScatter_ShortSward_{i}']
        mesh=bpy.data.meshes.new(f'North_Pagoda_Meadow_{i}_Synced')
        mesh.from_pydata([(r['origin'][0],-r['origin'][2],r['origin'][1]) for r in points],[],[])
        rotation=mesh.attributes.new('rotation','FLOAT_VECTOR','POINT');scale=mesh.attributes.new('scale','FLOAT_VECTOR','POINT')
        for j,row in enumerate(points):rotation.data[j].vector=row['blender_rotation'];scale.data[j].vector=row['blender_scale']
        obj.data=mesh
    removed=0;reseated=len(pagoda_rows)
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH':continue
        if obj.name.startswith('GScatter_') and obj.name.endswith('_Meadow'):asset=obj.name.removesuffix('_Meadow')
        else:continue
        bm=bmesh.new();bm.from_mesh(obj.data);delete=[];inverse=obj.matrix_world.inverted()
        for v in bm.verts:
            p=obj.matrix_world@v.co;key=(asset,round(p.x,3),round(p.y,3))
            if key not in lookup:delete.append(v)
            else:p.z=lookup[key];v.co=inverse@p;reseated+=1
        removed+=len(delete);bmesh.ops.delete(bm,geom=delete,context='VERTS');bm.to_mesh(obj.data);bm.free()
    bpy.context.scene['pagoda_sidewalk_repair']='Continuous triangulated paving, two flush bridge landings, square stair threshold and graded supporting ground; scoped exports only.'
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=path,compress=True)
    return {'saved':path,'meadow_points_removed':removed,'meadow_points_synced':reseated}
