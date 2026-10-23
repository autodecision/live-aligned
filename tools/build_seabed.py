"""Scoped seabed and submerged foundations. Run build/install via Blender MCP."""
import bpy, bmesh, math, json, hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
COLLECTION='Ocean Ground and Foundations'
TERRAINS=['Cliff_Terrain-col','Distant_Islands-col','North_Pagoda_Pagoda_Meadow_Ground',
          'Landing_Bank_Main_North','Landing_Bank_Main_South','Landing_Bank_North_South']

# A height field fills beneath each real island edge and rolls into the basin.
# It replaces vertical boundary skirts; all new relief remains below the waves.
FLOOR_BOUNDS=(-96,200,-150,140)
FLOOR_GRID=None

def prepare_floor():
    global FLOOR_GRID
    xs=np.arange(-96,201,dtype=float)[:,None];ys=np.arange(-150,141,dtype=float)[None,:]
    base=-11.3+.36*np.sin(xs*.071)*np.cos(ys*.063)+.22*np.sin(xs*.14+ys*.092)+.13*np.cos(xs*.24-ys*.17)
    height=base.copy();contacts=[]
    for name in TERRAINS:
        source=bpy.data.objects[name];bm=bmesh.new();bm.from_mesh(source.data)
        seeds={v for e in bm.edges if e.is_boundary for v in e.verts}
        samples=[]
        for v in seeds:
            p=source.matrix_world@v.co
            top=min(p.z+.38,-5.48)
            if top < -11.9:continue
            # Overlapping bells round convex corners and dissolve straight toes.
            width=5.8+.65*math.sin(p.x*.23+p.y*.19)+.35*math.cos(p.y*.31)
            i0=max(0,int(p.x-20)+96);i1=min(297,int(p.x+21)+96)
            j0=max(0,int(p.y-20)+150);j1=min(291,int(p.y+21)+150)
            if i1<=i0 or j1<=j0:continue
            d=np.sqrt((xs[i0:i1]-p.x)**2+(ys[:,j0:j1]-p.y)**2)
            local=base[i0:i1,j0:j1]
            bell=local+(top-local)*np.exp(-(d/width)**2.2)
            height[i0:i1,j0:j1]=np.maximum(height[i0:i1,j0:j1],bell)
            if p.z<=-5.4:samples.append([p.x,min(p.z,-11.8),-p.y])
        bm.free();contacts.append({'source':name,'contact_samples':samples})
    FLOOR_GRID=height
    return contacts

def floor_height(x,y):
    assert FLOOR_GRID is not None
    u=max(0,min(295.999999,x+96));v=max(0,min(289.999999,y+150))
    i=int(u);j=int(v);u-=i;v-=j
    a,b,c,d=[float(h) for h in [FLOOR_GRID[i,j],FLOOR_GRID[i+1,j],FLOOR_GRID[i+1,j+1],FLOOR_GRID[i,j+1]]]
    # Match the exported alternating triangle diagonal, including its contact height.
    if (i+j)%2==0:return a+(b-a)*u+(c-b)*v if v<=u else a+(c-d)*u+(d-a)*v
    return a+(b-a)*u+(d-a)*v if u+v<=1 else b*(1-v)+d*(1-u)+c*(u+v-1)

def mesh(name,vertices,faces,material,collection):
    data=bpy.data.meshes.new(name);data.from_pydata(vertices,[],faces);data.update()
    data.materials.append(material)
    uv=data.uv_layers.new(name='UVMap')
    for p in data.polygons:
        p.use_smooth='Seabed' in name or 'Scattered' in name or 'Rock_Base' in name
        for li in p.loop_indices:
            co=data.vertices[data.loops[li].vertex_index].co
            uv.data[li].uv=(co.x*.2+co.z*.15,co.y*.2+co.z*.15)
    o=bpy.data.objects.new(name,data);collection.objects.link(o);return o

def groups(obj):
    bm=bmesh.new();bm.from_mesh(obj.data);todo=set(bm.verts);result=[]
    while todo:
        first=todo.pop();group={first};stack=[first]
        while stack:
            v=stack.pop()
            for e in v.link_edges:
                q=e.other_vert(v)
                if q in todo:todo.remove(q);group.add(q);stack.append(q)
        result.append([obj.matrix_world@v.co for v in group])
    bm.free();return result

def save():
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)

def digest(objects):
    h=hashlib.sha256()
    for o in sorted(objects,key=lambda o:o.name):
        h.update(o.name.encode())
        for v in o.data.vertices:h.update(bytes(str(tuple(round(c,6) for c in v.co)),'ascii'))
    return h.hexdigest()

def build():
    assert not bpy.data.collections.get(COLLECTION),'Seabed already installed'
    col=bpy.data.collections.new(COLLECTION);bpy.context.scene.collection.children.link(col)
    sediment=bpy.data.materials.new('Ocean ground | sand silt and weathered stone')
    sediment.diffuse_color=(.34,.33,.25,1);sediment.use_nodes=True
    bsdf=sediment.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value=sediment.diffuse_color;bsdf.inputs['Roughness'].default_value=.96
    closure_report=prepare_floor()
    nx,ny=297,291
    vs=[(-96+i,-150+j,float(FLOOR_GRID[i,j])) for i in range(nx) for j in range(ny)]
    fs=[]
    for i in range(nx-1):
        for j in range(ny-1):
            a=i*ny+j;b=a+ny
            fs.extend([(a,b,b+1),(a,b+1,a+1)] if (i+j)%2==0 else [(a,b,a+1),(b,b+1,a+1)])
    mesh('Ocean_Seabed',vs,fs,sediment,col)
    # Water only beyond the finite playable map. The near edge uses the exact
    # delivered sea rectangle; its shader shares the original wave phase.
    water=bpy.data.materials.new('Ocean horizon water');water.diffuse_color=(.035,.24,.28,1)
    vs=[];fs=[];xmin,xmax,ymin,ymax=-55.15751,160.0,-110.0,100.0
    distances=[0,1,2,4,7,12,20,35,60,100,180,300,500,850,1400,2400]
    edge_rows=json.loads((ROOT/'assets/ocean_horizon_edges.json').read_text())
    for side,edge in enumerate(edge_rows):
        axis=1 if side<2 else 0
        edge=sorted(set(tuple(p) for p in edge),key=lambda p:p[axis])
        start=len(vs);n=len(edge)
        for d in distances:
            for j,p in enumerate(edge):
                t=(p[axis]-edge[0][axis])/(edge[-1][axis]-edge[0][axis])
                x,y,z=p
                if side==0:x-=d;y+=d*(2*t-1)
                elif side==1:x+=d;y+=d*(2*t-1)
                elif side==2:y-=d;x+=d*(2*t-1)
                else:y+=d;x+=d*(2*t-1)
                vs.append((x,y,z))
        for row in range(len(distances)-1):
            for j in range(n-1):
                a=start+row*n+j;b=a+n;fs.extend([(a,b,b+1),(a,b+1,a+1)])
    mesh('Ocean_Horizon_Water',vs,fs,water,col)

    # Continue each existing limestone sleeve down into solid seabed. The timber
    # piles already overlap the sleeve; their visible upper portions are untouched.
    footings=[]
    for source in list(bpy.context.scene.objects):
        if source.type!='MESH' or not source.name.endswith('Bridge_Coastal_Limestone'):continue
        vs=[];fs=[]
        for ps in groups(source):
            low=min(p.z for p in ps)
            if abs(low+7.5)>.001:continue
            corners=sorted([p for p in ps if abs(p.z-low)<.001],key=lambda p:math.atan2(p.y-sum(q.y for q in ps)/len(ps),p.x-sum(q.x for q in ps)/len(ps)))
            assert len(corners)==4
            k=len(vs)
            bottom=min(low-.28,min(floor_height(p.x,p.y) for p in corners)-.28)
            vs.extend([(p.x,p.y,bottom) for p in corners]);vs.extend([(p.x,p.y,low+.025) for p in corners])
            fs.extend([tuple(k+i for i in (0,3,2,1)),tuple(k+i for i in (4,5,6,7))])
            for j in range(4):fs.append((k+j,k+(j+1)%4,k+4+(j+1)%4,k+4+j))
            footings.append({'bridge':source.name,'bottom':[[p.x,bottom,-p.y] for p in corners],
                             'top':[[p.x,low+.025,-p.y] for p in corners]})
        mesh('Ocean_Footings_'+source.name,vs,fs,source.data.materials[0],col)
    assert len(footings)==30,len(footings)
    rocks=[];rock_sources=[]
    # The scoped GLB has the active eroded silhouette, while older editable rock
    # datablocks still contained a larger buried apron. Use the delivered mesh.
    before=set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(ROOT/'assets/offshore_spectrum.glb'))
    imported=set(bpy.data.objects)-before
    for active in sorted(imported,key=lambda o:o.name):
        if active.type!='MESH':continue
        name=active.name.split('.00')[0]
        source=bpy.data.objects[name]
        source.data=active.data;source.matrix_world=active.matrix_world.copy()
        source['ocean_ground_source']='Matches active offshore_spectrum.glb; previous apron preserved in external backup'
        rock_sources.append(source)
        # Merge UV/color split vertices only in a temporary working copy.
        bm=bmesh.new();bm.from_mesh(active.data)
        bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.0001)
        for v in bm.verts:v.co=active.matrix_world@v.co
        cut=-7.25
        cut_result=bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.00001,
                                         plane_co=(0,0,cut),plane_no=(0,0,1))
        edges=[e for e in cut_result['geom_cut'] if isinstance(e,bmesh.types.BMEdge)]
        vertices={v for e in edges for v in e.verts}
        assert len(edges)>8,(name,len(edges))
        # Displacement in the historical GLB split some face edges. A continuous
        # convex envelope closes those cracks instead of extruding each fragment.
        pts=sorted(set((round(v.co.x,5),round(v.co.y,5)) for v in vertices))
        def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
        lower_hull=[];upper=[]
        for p in pts:
            while len(lower_hull)>=2 and cross(lower_hull[-2],lower_hull[-1],p)<=0:lower_hull.pop()
            lower_hull.append(p)
        for p in reversed(pts):
            while len(upper)>=2 and cross(upper[-2],upper[-1],p)<=0:upper.pop()
            upper.append(p)
        hull=lower_hull[:-1]+upper[:-1]
        cx=sum(p[0] for p in hull)/len(hull);cy=sum(p[1] for p in hull)/len(hull)
        vs=[];fs=[];lower=[];n=len(hull)
        for level in range(3):
            for j,(x,y) in enumerate(hull):
                scale=1.0 if level==0 else (1.045+.015*math.sin(j*1.73) if level==1 else 1.10)
                x=cx+(x-cx)*scale;y=cy+(y-cy)*scale
                z=cut if level==0 else (-8.8+.07*math.sin(j*2.1) if level==1 else min(cut-.5,floor_height(x,y)-.25))
                vs.append((x,y,z))
                if level==2:lower.append([x,z,-y])
        for level in range(2):
            for j in range(n):
                a=level*n+j;b=level*n+(j+1)%n;c=b+n;d=a+n
                fs.extend([(a,b,c),(a,c,d)])
        fs.extend([tuple(reversed(range(n))),tuple(range(2*n,3*n))])
        bm.free()
        obj=mesh('Ocean_Rock_Base_'+name.replace('-col',''),vs,fs,sediment,col)
        # Eroded upper rock retains its reference spectrum. The new buried root
        # uses dark mineral sediment, only visible below the lower blue band.
        rock_points=[source.matrix_world@v.co for v in source.data.vertices]
        lows=[p for p in rock_points if p.z< -7.65]
        rocks.append({'name':name.replace('-col',''),'foundation':obj.name,'lower_samples':lower,
                      'base_samples':[[p.x,p.z,-p.y] for p in lows[::max(1,len(lows)//12)]]})
    bpy.data.libraries.write(str(OUT/'ocean_rock_sources.blend'),set(rock_sources),fake_user=True,compress=True)
    for o in imported:bpy.data.objects.remove(o,do_unlink=True)
    assert len(rocks)==9,len(rocks)
    objects=list(col.objects)
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/ocean_ground.glb'),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
    # The distant ring spans kilometres. Quantized mesh positions would move
    # near shore edge vertices by centimetres and expose a bright water seam.
    config=ROOT/'assets/ocean_ground.glb.import'
    if config.exists():
        text=config.read_text().replace('meshes/force_disable_compression=false','meshes/force_disable_compression=true').replace('meshes/generate_lods=true','meshes/generate_lods=false')
        config.write_text(text)

    # Write the object library first; a separate reopen links its scene safely.
    bpy.data.libraries.write(str(OUT/'ocean_ground.blend'),set(objects),fake_user=True,compress=True)
    report={'bounds_blender':list(FLOOR_BOUNDS),'floor_vertices':nx*ny,'floor_triangles':(nx-1)*(ny-1)*2,
            'floor_height_range':[float(FLOOR_GRID.min()),float(FLOOR_GRID.max())],
            'design':'Continuous rolling basin and rounded island aprons; no vertical terrain skirts',
            'footings':footings,'terrain_closures':closure_report,'rocks':rocks,'sha256':digest(objects)}
    # Face count belongs to the floor, independent of batched footing geometry.
    report['floor_triangles']=(nx-1)*(ny-1)*2
    for p in [ROOT/'assets/ocean_ground.json',OUT/'ocean_ground.json']:p.write_text(json.dumps(report,indent=2))
    save()
    return {'saved':bpy.data.filepath,'meshes':len(objects),'footings':len(footings),'rocks':len(rocks),'sha256':report['sha256']}

def install():
    assert not bpy.data.collections.get(COLLECTION),'Seabed already installed'
    col=bpy.data.collections.new(COLLECTION);bpy.context.scene.collection.children.link(col)
    with bpy.data.libraries.load(str(OUT/'ocean_ground.blend'),link=False) as (src,dst):dst.objects=list(src.objects)
    for o in dst.objects:col.objects.link(o)
    names=[r['name']+'-col' for r in json.loads((ROOT/'assets/ocean_ground.json').read_text())['rocks']]
    targets={n:(bpy.data.objects.get(n) or bpy.data.objects.get(n.removesuffix('-col'))) for n in names}
    assert all(targets.values())
    with bpy.data.libraries.load(str(OUT/'ocean_rock_sources.blend'),link=False) as (src,dst):dst.objects=list(src.objects)
    for o in dst.objects:
        name=o.name.split('.00')[0];target=targets[name]
        target.data=o.data;target.matrix_world=o.matrix_world.copy()
        bpy.data.objects.remove(o,do_unlink=True)
    save();return {'saved':bpy.data.filepath,'meshes':len(col.objects),'sha256':digest(col.objects)}

def rebuild():
    """Replace only this task's independently added collection."""
    col=bpy.data.collections.get(COLLECTION)
    if col:
        for o in list(col.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(col)
    return build()

def reinstall():
    col=bpy.data.collections.get(COLLECTION)
    if col:
        for o in list(col.objects):bpy.data.objects.remove(o,do_unlink=True)
        bpy.data.collections.remove(col)
    return install()
