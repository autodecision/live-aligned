"""Unify the north island's intersecting cliff/meadow surfaces via Blender MCP.

Run build() in the pre-pass optimized map, then install() in the artistic and
standalone pagoda files. The south island and all independent structure GLBs stay
intact. This supersedes the western-toe-only repair.
"""
import bpy, bmesh, hashlib, json, math, random, runpy
import numpy as np
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
NAME = 'North_Pagoda_Pagoda_Meadow_Ground'
BASE = 'Pagoda_Coastal_Distant_Islands'
H = runpy.run_path(str(ROOT/'tools/repair_pagoda_shore.py'))
P = runpy.run_path(str(ROOT/'tools/finish_shore_planting.py'))


def snapshot():
    return {o.name: (H['digest'](o), tuple(v for r in o.matrix_world for v in r))
            for o in bpy.context.scene.objects if o.type == 'MESH'
            and o.name not in [NAME, 'Distant_Islands-col', 'Distant_Islands']
            and not ('Meadow' in o.name and len(o.data.polygons) == 0)}


def smooth(a, b, x):
    t = np.clip((x-a)/(b-a), 0, 1)
    return t*t*(3-2*t)


def tree(o):
    return BVHTree.FromObject(o, bpy.context.evaluated_depsgraph_get())


def sample(b, x, y):
    p, n, _, _ = b.ray_cast(Vector((float(x), float(y), 40)), Vector((0, 0, -1)))
    return (p, n) if p is not None else None


def make_mesh(name, vertices, faces, materials):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    for m in materials: mesh.materials.append(m)
    uv = mesh.uv_layers.new(name='UVMap')
    for p in mesh.polygons:
        p.use_smooth = True
        for li in p.loop_indices:
            v = mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv = (v.x*.25, v.y*.25)
    return mesh


def unified_ground():
    obj = bpy.data.objects[NAME]
    distant = P['obj']('Distant_Islands-col')
    bank = P['obj']('Landing_Bank_Main_North')
    floor = tree(bpy.data.objects['Ocean_Seabed'])
    surfaces = [tree(o) for o in [obj, distant, bank]]
    xs, ys = np.arange(16, 148.01, .5), np.arange(8, 108.01, .5)
    x, y = np.meshgrid(xs, ys, indexing='ij')
    bed = np.empty(x.shape)
    base = np.empty(x.shape)
    for i, px in enumerate(xs):
        for j, py in enumerate(ys):
            bed[i,j] = sample(floor, px, py)[0].z-.5
            base[i,j] = max([bed[i,j]]+[h[0].z for b in surfaces if (h := sample(b, px, py))])
    # Exact sidewalk elevations are fixed constraints, including the bridge joins.
    plan = json.loads((ROOT/'assets/north_pagoda.json').read_text())
    path_distance = np.full(x.shape, 1e6)
    path_height = np.zeros(x.shape)
    for route in plan['sidewalk_routes']:
        pts = route['path']; widths = route['half_widths']
        for k in range(len(pts)-1):
            ax, az, ay = pts[k][0], pts[k][1], -pts[k][2]
            bx, bz, by = pts[k+1][0], pts[k+1][1], -pts[k+1][2]
            t = np.clip(((x-ax)*(bx-ax)+(y-ay)*(by-ay))/((bx-ax)**2+(by-ay)**2), 0, 1)
            dist = np.hypot(x-(ax+t*(bx-ax)), y-(ay+t*(by-ay)))-(widths[k]+t*(widths[k+1]-widths[k]))
            nearer = dist < path_distance
            path_distance[nearer] = dist[nearer]
            path_height[nearer] = (az+t*(bz-az)-.07)[nearer]
    base = np.where(path_distance < .35, path_height, base)
    h = base.copy()
    # Spread the existing shoulders at a limited rise/run. This fills cliff cuts
    # without lowering the ridge, trees or rocks. Longer neighbors avoid diamond
    # shapes; subsequent averaging rounds the shoulder into the beach.
    offsets = [(1,0),(0,1),(1,1),(1,-1),(2,1),(2,-1),(1,2),(1,-2)]
    for iteration in range(60):
        previous = h.copy()
        for dx, dy in offsets:
            cost = .67*.5*math.hypot(dx,dy)
            for sign in [-1,1]:
                a,b = dx*sign,dy*sign
                si = slice(max(0,-a),min(h.shape[0],h.shape[0]-a))
                sj = slice(max(0,-b),min(h.shape[1],h.shape[1]-b))
                ti = slice(max(0,a),min(h.shape[0],h.shape[0]+a))
                tj = slice(max(0,b),min(h.shape[1],h.shape[1]+b))
                h[ti,tj] = np.maximum(h[ti,tj],previous[si,sj]-cost)
        if np.max(h-previous)<.0001: break
    for _ in range(12):
        p = np.pad(h, 1, mode='edge')
        h = (4*p[1:-1,1:-1]+p[:-2,1:-1]+p[2:,1:-1]+p[1:-1,:-2]+p[1:-1,2:]
             +p[:-2,:-2]+p[:-2,2:]+p[2:,:-2]+p[2:,2:])/12
    h = np.maximum(base,h)
    # The plateau and route bed keep their original elevations; changes feather
    # outward through the shoulders rather than raising soil through the paving.
    cap = path_height+.67*np.maximum(path_distance-.35,0)
    h = np.where(path_distance<3, np.minimum(h,cap), h)
    h = np.where(path_distance<.35,path_height,h)
    # Preserve open water around the existing offshore formations. Their meshes,
    # transforms and fitted submerged roots do not need to move for this repair.
    previous_objects=set(bpy.data.objects)
    previous_meshes=set(bpy.data.meshes)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/offshore_spectrum.glb'))
    imported=set(bpy.data.objects)-previous_objects
    rock_points=[Vector((p.x,p.y,0)) for rock in imported if rock.type=='MESH'
                 for v in rock.data.vertices if (p:=rock.matrix_world@v.co).z>-5.2]
    for rock in imported:bpy.data.objects.remove(rock,do_unlink=True)
    for mesh in set(bpy.data.meshes)-previous_meshes:
        if mesh.users==0:bpy.data.meshes.remove(mesh)
    kd=KDTree(len(rock_points))
    for i,p in enumerate(rock_points):kd.insert(p,i)
    kd.balance()
    for i,px in enumerate(xs):
        for j,py in enumerate(ys):
            _,_,distance=kd.find(Vector((px,py,0)))
            if distance<4.5:h[i,j]-=max(h[i,j]+5.9,0)*(1-float(smooth(1,4.5,distance)))
    margin = np.minimum.reduce([x-xs[0],xs[-1]-x,y-ys[0],ys[-1]-y])
    rim = margin<5
    assert np.max(h[rim]) < -5.5, 'Only submerged ground may reach the perimeter'
    h = bed+(h-bed)*smooth(0,5,margin)
    vertices = np.stack([x,y,h],axis=-1).reshape(-1,3).tolist()
    nj = len(ys)
    faces = []
    for i in range(len(xs)-1):
        for j in range(len(ys)-1):
            a=i*nj+j; b=a+nj
            if (i+j)%2: faces.extend([(a,b,a+1),(b,b+1,a+1)])
            else: faces.extend([(a,b,b+1),(a,b+1,a+1)])
    obj.data = make_mesh('Pagoda Continuous Coastal Ground',vertices,faces,list(obj.data.materials))
    attr = obj.data.attributes.new('sidewalk_original_z','FLOAT','POINT')
    for d,z in zip(attr.data,h.ravel()): d.value=z
    obj['continuous_coast'] = True
    obj['western_shore_closed'] = True
    # The old north shell is redundant, including its vertical faces and folds.
    # Retain every south-island vertex and face exactly as saved before this pass.
    old=distant.data
    old_vertices=[tuple(v.co) for v in old.vertices]
    south_faces=[tuple(p.vertices) for p in old.polygons if max(old.vertices[i].co.y for i in p.vertices)<0]
    assert all(min(old.vertices[i].co.y for i in p.vertices)>0 or max(old.vertices[i].co.y for i in p.vertices)<0 for p in old.polygons)
    retained=old.copy();retained.name='Distant Islands South Preserved'
    bm=bmesh.new();bm.from_mesh(retained)
    for face in list(bm.faces):
        if min(v.co.y for v in face.verts)>0:bm.faces.remove(face)
    bm.to_mesh(retained);bm.free();retained.update();distant.data=retained
    assert [tuple(v.co) for v in distant.data.vertices]==old_vertices
    assert [tuple(p.vertices) for p in distant.data.polygons]==south_faces
    # The master ground now includes the landing's upper surface. Keep its old
    # editable data, hidden, so a second shell cannot show through the new slope.
    bank.hide_render=True
    bank['integrated_into_pagoda_coast']=True
    bpy.context.view_layer.update()
    return {'grid_step':.5,'grid_shape':list(x.shape),'vertices':len(vertices),'faces':len(faces),
            'south_faces_preserved':len(south_faces),'old_north_faces_removed':len(old.polygons)-len(south_faces),
            'raised_grid_points':int(np.count_nonzero(h-base>.02)),'maximum_fill':float(np.max(h-base)),
            'perimeter_max_above_bed':float(np.max((h-bed)[margin==0]))}, tree(obj), path_distance, (xs,ys)


def grass(ground, path_distance, grid, backup=None):
    rng=random.Random(20102026)
    files=['gscatter_ground_cover_instances.json','north_pagoda_cover.json']
    paths=[Path(backup)/str(ROOT/'assets'/f).lstrip('/') if backup else ROOT/'assets'/f for f in files]
    batches=[json.loads(p.read_text()) for p in paths]
    C=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
    main_ground=tree(P['obj']('Cliff_Terrain-col'))
    buckets={}; moved=0
    def bucket(x,y): return (math.floor(x/.5),math.floor(y/.5))
    def orient(row,n):
        if 'blender_scale' in row:
            scale=Vector(row['blender_scale']);yaw=row['blender_rotation'][2]
        else:
            previous=C.inverted()@Matrix(row['basis']).transposed()@C
            scale=previous.to_scale();yaw=previous.to_euler().z
        rotation=Vector((0,0,1)).rotation_difference(n).to_matrix()@Matrix.Rotation(yaw,3,'Z')
        basis=C@rotation@Matrix.Diagonal(scale)@C.inverted()
        row['basis']=[list(basis.col[i]) for i in range(3)]
        row['blender_rotation']=list(rotation.to_euler())
        row['blender_scale']=list(scale)
    for batch in batches:
        for row in batch:
            x,y=row['origin'][0],-row['origin'][2]
            if 16<x<148 and 8<y<108:
                hit=sample(ground,x,y)
                mainland=sample(main_ground,x,y)
                if mainland and abs(mainland[0].z-(row['origin'][1]+.028))<.4:
                    buckets.setdefault(bucket(x,y),[]).append((x,y));continue
                if hit:
                    z=hit[0].z-.028
                    if abs(z-row['origin'][1])>.003:
                        row['origin'][1]=z;orient(row,hit[1]);moved+=1
            buckets.setdefault(bucket(x,y),[]).append((x,y))
    # Fill only newly supported/reshaped dry ground. Existing plants retain their
    # distribution and share the same three meshes/material as the rest of town.
    obstacles=[]
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render or o.name in P['SURFACES']:continue
        if any(s in o.name for s in ['Meadow','GScatter','Water','water','Sea','Cloud','Koi','leaves','foliage']):continue
        pts=[o.matrix_world@Vector(c) for c in o.bound_box]
        bounds=(min(p.x for p in pts),max(p.x for p in pts),min(p.y for p in pts),max(p.y for p in pts))
        if bounds[1]<26 or bounds[0]>85 or bounds[3]<20 or bounds[2]>85:continue
        obstacles.append((o,bounds))
    cache={};added=0
    for ix in range(170):
        for iy in range(182):
            x=26+(ix+rng.uniform(.1,.9))*.34;y=20+(iy+rng.uniform(.1,.9))*.34
            hit=sample(ground,x,y)
            if hit is None:continue
            p,n=hit
            mainland=sample(main_ground,x,y)
            if mainland and mainland[0].z>p.z-.1:continue
            if p.z<-.8 or n.z<.79:continue
            i=round((x-grid[0][0])/.5);j=round((y-grid[1][0])/.5)
            if path_distance[i,j]<.55:continue
            if rng.random()>.74*float(smooth(-.8,.5,p.z)):continue
            bx,by=bucket(x,y)
            if any((px-x)**2+(py-y)**2<.23**2 for a in range(bx-1,bx+2) for b in range(by-1,by+2) for px,py in buckets.get((a,b),[])):continue
            blocked=False
            for o,(a,b,c,d) in obstacles:
                if not(a-.3<x<b+.3 and c-.3<y<d+.3):continue
                if o.name not in cache:cache[o.name]=P['bvh'](o)
                if any(cache[o.name].ray_cast(Vector((x+dx,y+dy,p.z+1.2)),Vector((0,0,-1)),1.5)[0] is not None for dx,dy in [(0,0),(.24,0),(-.24,0),(0,.24),(0,-.24)]):blocked=True;break
            if blocked:continue
            s=rng.uniform(.85,1.12)
            row={'asset':'GScatter_ShortSward_'+str(rng.randrange(3)), 'origin':[x,p.z-.028,-y],
                 'blender_rotation':[0,0,rng.random()*math.tau],'blender_scale':[s]*3,'pagoda_coast':True}
            orient(row,n);batches[1].append(row);buckets.setdefault(bucket(x,y),[]).append((x,y));added+=1
    for f,rows in zip(files,batches):
        for p in [ROOT/'assets'/f,OUT/f]:p.write_text(json.dumps(rows,separators=(',',':')))
    P['sync_meadow']()
    return {'reseated':moved,'added':added,'total':sum(map(len,batches))}


def export():
    o=bpy.data.objects[NAME];distant=P['obj']('Distant_Islands-col')
    clone=distant.copy();clone.name=BASE;bpy.context.scene.collection.objects.link(clone)
    bpy.ops.object.select_all(action='DESELECT')
    for ob in [o,clone]:ob.hide_set(False);ob.select_set(True)
    bpy.context.view_layer.objects.active=o
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/pagoda_shore.glb'),export_format='GLB',use_selection=True,
                              export_cameras=False,export_lights=False,export_animations=False)
    bpy.data.libraries.write(str(OUT/'pagoda_shore.blend'),{o,clone},fake_user=True,compress=True)
    bpy.data.objects.remove(clone,do_unlink=True)


def build(backup=None):
    assert not bpy.data.objects[NAME].get('continuous_coast'), 'Already installed; rebuild from scoped backup'
    before=snapshot()
    geometry,ground,path_distance,grid=unified_ground()
    planting=grass(ground,path_distance,grid,backup)
    assert before==snapshot(), 'Unrelated mesh or placement changed'
    export()
    report={'mesh':NAME,'base_mesh':BASE,'stage':'continuous north coast','geometry':geometry,'grass':planting,
            'sha256':H['digest'](bpy.data.objects[NAME]),'distant_sha256':H['digest'](P['obj']('Distant_Islands-col')),
            'preserved_other_meshes':len(before)}
    for p in [ROOT/'assets/pagoda_shore.json',OUT/'pagoda_shore.json']:p.write_text(json.dumps(report,indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets/mediterranean_temple.blend'),compress=True)
    return report


def install():
    before=snapshot()
    with bpy.data.libraries.load(str(OUT/'pagoda_shore.blend'),link=False) as (src,dst): dst.objects=[NAME,BASE]
    master,base=dst.objects
    target=bpy.data.objects[NAME];target.data=master.data;target['continuous_coast']=True;target['western_shore_closed']=True
    distant=bpy.data.objects.get('Distant_Islands-col') or bpy.data.objects.get('Distant_Islands')
    if distant:
        distant.data=base.data
        bank=P['obj']('Landing_Bank_Main_North');bank.hide_render=True;bank['integrated_into_pagoda_coast']=True
        P['sync_meadow']()
    for o in [master,base]:bpy.data.objects.remove(o,do_unlink=True)
    assert before==snapshot(), 'Unrelated mesh or placement changed'
    H['save']()
    return audit()


def audit():
    plan=json.loads((ROOT/'assets/pagoda_shore.json').read_text())
    master=bpy.data.objects[NAME]
    assert H['digest'](master)==plan['sha256']
    distant=bpy.data.objects.get('Distant_Islands-col') or bpy.data.objects.get('Distant_Islands') or bpy.data.objects.get(BASE)
    if distant:assert H['digest'](distant)==plan['distant_sha256']
    return {'saved':bpy.data.filepath,'sha256':H['digest'](master),'vertices':len(master.data.vertices),
            'faces':len(master.data.polygons),'distant_sha256':H['digest'](distant) if distant else None,
            'scene_meshes':sum(o.type=='MESH' for o in bpy.context.scene.objects),
            'grass_points':sum(len(o.data.vertices) for o in bpy.context.scene.objects if o.type=='MESH' and 'Meadow' in o.name and len(o.data.polygons)==0)}
