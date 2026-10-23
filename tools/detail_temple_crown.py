"""Scoped temple crown, eroded spectrum stone and rear grove spacing via Blender MCP."""
import bpy, math, json, sys, hashlib, struct
from pathlib import Path
from mathutils import Vector
from mathutils.noise import noise_vector, noise
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).parent))
import detail_temple_architecture as architecture
import repair_temple_clearance as clearance
import repair_tree_clearance as trees
ROOT=Path(__file__).resolve().parent.parent
OPT=ROOT/'assets/mediterranean_temple.blend'
ART=architecture.ART
ROOF='Temple_Entablature-col'

def rod(builder,a,b,width,depth,material=0):
    a,b=Vector(a),Vector(b);direction=(b-a).normalized()
    side=direction.cross(Vector((0,1,0))).normalized()*width*.5
    rear=Vector((0,depth*.5,0));offset=len(builder.vertices)
    builder.vertices.extend([tuple(p+s*side+r*rear) for p in (a,b) for r in (-1,1) for s in (-1,1)])
    for f in [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]:builder.face(tuple(offset+i for i in f),material)

def relief(builder,y,front):
    # Layered tympanum frame and an original compass/sun relief, carved in stone.
    sign=-1 if front else 1
    for inset,width,depth in [(.0,.17,.17),(.24,.075,.13)]:
        left=Vector((-8.97+inset,y,12.52+inset*.25));right=Vector((1.97-inset,y,12.52+inset*.25));top=Vector((-3.5,y,14.82-inset*.55))
        for a,b in [(left,top),(top,right),(left,right)]:rod(builder,a,b,width,depth,1)
    center=Vector((-3.5,y+sign*.09,13.32))
    for radius,thick in [(.47,.065),(.34,.028)]:
        for i in range(64):
            a=i*math.tau/64;b=(i+1)*math.tau/64
            rod(builder,center+Vector((math.cos(a)*radius,0,math.sin(a)*radius)),center+Vector((math.cos(b)*radius,0,math.sin(b)*radius)),thick,.08,1)
    for i in range(12):
        a=i*math.tau/12
        rod(builder,center+Vector((math.cos(a)*.12,0,math.sin(a)*.12)),center+Vector((math.cos(a)*.27,0,math.sin(a)*.27)),.055,.085,0)
    # Paired olive sprays fit within the triangle, with raised almond leaves.
    for signx in [-1,1]:
        for j in range(6):
            x=-3.5+signx*(.85+j*.38);z=12.90+.045*j
            rod(builder,(x-signx*.24,y,z-.04),(x+signx*.24,y,z+.04),.038,.085,2)
            for up in [-1,1]:
                a=Vector((x,y+sign*.07,z));b=a+Vector((signx*.25,0,up*.18));d=(b-a).normalized();side=Vector((-d.z,0,d.x))*.065
                off=len(builder.vertices);mid=(a+b)*.5
                builder.vertices.extend([a,mid+side,b,mid-side,mid+Vector((0,sign*.055,0))])
                for f in [(0,1,4),(1,2,4),(2,3,4),(3,0,4)]:builder.face(tuple(off+i for i in f),1)

def crown():
    mats=architecture.stone_materials();b=architecture.StoneMesh()
    # Three architrave fasciae, shadow reveals, a metope frieze and layered cornice.
    for lo,hi,z0,z1 in [((-8.7,-1.3),(1.7,14.3),10.745,10.94),((-8.74,-1.34),(1.74,14.34),10.94,11.14),((-8.79,-1.39),(1.79,14.39),11.14,11.35),((-8.80,-1.40),(1.80,14.40),11.35,11.96)]:
        b.box((*lo,z0),(*hi,z1),0)
    for row,(pad,z0,z1) in enumerate([(0,11.94,12.02),(.10,12.02,12.10),(.20,12.10,12.19),(.30,12.19,12.34),(.34,12.34,12.445)]):
        architecture.perimeter(b,(-8.8-pad,-1.4-pad),(1.8+pad,14.4+pad),z0,z1,1.35,row,.28)
    # Triglyphs and metope rosettes around all four sides, with dentils above.
    for axis,start,end,edges in [(0,-8.45,1.45,(-1.43,14.43)),(1,-1.05,14.05,(-8.83,1.83))]:
        count=round((end-start)/.94)
        for j in range(count+1):
            p=start+(end-start)*j/count
            for edge in edges:
                for d in [-.10,0,.10]:
                    if axis==0:b.box((p+d-.022,edge-.042,11.43),(p+d+.022,edge+.042,11.87),2)
                    else:b.box((edge-.042,p+d-.022,11.43),(edge+.042,p+d+.022,11.87),2)
        for j in range(round((end-start)/.23)+1):
            p=start+j*.23
            for edge in edges:
                if axis==0:b.box((p-.065,edge-.14,11.985),(p+.065,edge+.14,12.10),1)
                else:b.box((edge-.14,p-.065,11.985),(edge+.14,p+.065,12.10),1)
    # Solid front and rear tympana.
    for y0,y1 in [(-1.70,-1.10),(14.10,14.70)]:
        offset=len(b.vertices);b.vertices.extend([(-9.1,y0,12.445),(2.1,y0,12.445),(-3.5,y0,14.845),(-9.1,y1,12.445),(2.1,y1,12.445),(-3.5,y1,14.845)])
        for f in [(0,2,1),(3,4,5),(0,1,4,3),(1,2,5,4),(2,0,3,5)]:b.face(tuple(offset+i for i in f),0)
    relief(b,-1.78,True);relief(b,14.78,False)
    # Individual overlapping roof tiles follow the two pitched planes.
    for side in [-1,1]:
        for row in range(10):
            d0=row*.565;d1=(row+1)*.565+.035
            x0=-3.5+side*d0;x1=-3.5+side*d1
            z0=14.985-d0*(2.54/5.824);z1=14.985-d1*(2.54/5.824)
            for col in range(24):
                y0=-1.48+col*.67;y1=y0+.652
                offset=len(b.vertices)
                for dz in [-.035,.018]:b.vertices.extend([(x0,y0,z0+dz),(x1,y0,z1+dz),(x1,y1,z1+dz),(x0,y1,z0+dz)])
                for f in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]:b.face(tuple(offset+i for i in f),(row+col)%3)
    for j in range(24):
        y=-1.5+j*.67
        b.box((-3.61,y,14.945),(-3.39,y+.65,15.08),1)
    # Restrained ridge finials echo the pediment medallion.
    for y in [-1.20,14.20]:
        b.lathe(-3.5,y,[(15.02,.23),(15.10,.27),(15.18,.23),(15.23,.14),(15.31,.17),(15.47,.12),(15.62,.015)],32,material=1)
    o=b.replace(ROOF,mats,.008)
    o['crown_detail']='Layered fasciae; triglyphs; dentils; tympanum sun and olive relief; 480 roof tiles'
    clearance.export(ROOT/'assets/temple_crown_detail.glb',[o])
    return len(o.data.vertices)

def erode_sea():
    for index,name in enumerate(clearance.SEA):
        o=clearance.obj(name);me=o.data
        attr=me.attributes.get('Unweathered position')
        if attr is None:
            attr=me.attributes.new('Unweathered position','FLOAT_VECTOR','POINT')
            for v,d in zip(me.vertices,attr.data):d.vector=v.co
        # Calculate displacement from saved pre-weathering coordinates each time.
        for v,d in zip(me.vertices,attr.data):v.co=d.vector
        me.update();normals=[v.normal.copy() for v in me.vertices];inv=o.matrix_world.inverted().to_3x3()
        for v,d,n in zip(me.vertices,attr.data,normals):
            p=o.matrix_world@d.vector
            seed=Vector((index*7.3,index*2.4,index*1.7))
            coarse=noise(p*.62+seed,noise_basis='PERLIN_ORIGINAL')
            fine=noise(p*2.1+seed,noise_basis='PERLIN_ORIGINAL')
            layers=math.sin(p.z*6.1+.8*math.sin(p.x*.63+p.y*.32))
            amount=.45*coarse+.13*fine+.12*layers
            normal=(o.matrix_world.to_3x3()@n).normalized()
            v.co=d.vector+inv@(normal*amount)
        me.update()
        for p in me.polygons:p.use_smooth=True
        # World-scaled projected UVs, preserving the established spectrum colors.
        uv=me.uv_layers.active or me.uv_layers.new(name='Weathered stone UV')
        for poly in me.polygons:
            axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis]
            for li in poly.loop_indices:
                p=o.matrix_world@me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv=(p[axes[0]]*.8,p[axes[1]]*.8)
        o['weathered_spectrum']='Eroded shelves and fissures; original spectrum retained'
    # Rock grain and normals also appear in the editable Blender sources.
    mat=clearance.obj(clearance.SEA[0]).data.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links
    bs=next(n for n in nodes if n.type=='BSDF_PRINCIPLED');bs.inputs['Roughness'].default_value=.85
    col=next(n for n in nodes if n.type=='VERTEX_COLOR')
    links.new(col.outputs['Color'],bs.inputs['Base Color'])
    normaltex=nodes.get('Stone normal') or nodes.new('ShaderNodeTexImage');normaltex.name='Stone normal';normaltex.image=bpy.data.images.load(str(ROOT/'assets/textures/coastal_rock_normal.png'),check_existing=True);normaltex.image.colorspace_settings.name='Non-Color';normaltex.image.pack()
    normal=nodes.get('Stone normal map') or nodes.new('ShaderNodeNormalMap');normal.name='Stone normal map';normal.inputs['Strength'].default_value=.8;links.new(normaltex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bs.inputs['Normal'])
    objects=[clearance.obj(n) for n in clearance.SEA]
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/offshore_spectrum.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='Reference spectrum')

def wood_bvh(o):
    return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons if p.material_index==0])

def grove():
    # Solve the close rear pair on the existing grass shelf; keep other trees intact.
    o=clearance.obj('Olive_Ridge_BG_2');original=o.matrix_world.copy()
    terrain=trees.bvh(clearance.obj('Cliff_Terrain'))
    z=terrain.ray_cast(Vector((10.9,18.5,60)),Vector((0,0,-1)))[0]
    assert z is not None
    bottom=min((original@v.co).z-original.translation.z for v in o.data.vertices)
    o.location=(10.9,18.5,z.z-bottom-.045)
    bpy.context.view_layer.update()
    plan=json.loads((ROOT/'assets/tree_clearance_repairs.json').read_text())
    row=next(r for r in plan['trees'] if r['name']==o.name)
    row['blender_position']=list(o.location);row['position']=[o.location.x,o.location.z,-o.location.y];row['spacing_reason']='Separated rear temple canopies and woody branches'
    (ROOT/'assets/tree_clearance_repairs.json').write_text(json.dumps(plan,indent=2)+'\n')

def urn():
    o=clearance.obj('Fountain_Offering_Vase')
    # The reported vessel was a second urn, left out of the earlier repair.
    o.location=(4.30,5.40,3.5476567)
    plan=json.loads(clearance.PLAN.read_text());plan['positions'][o.name]=[o.location.x,o.location.z,-o.location.y]
    clearance.PLAN.write_text(json.dumps(plan,indent=2)+'\n')

def report():
    roof=clearance.obj('Temple_Entablature')
    data={'source':bpy.data.filepath,'crown_vertices':len(roof.data.vertices),'crown_sha256':architecture.fingerprint(roof),'sea':{n:architecture.fingerprint(clearance.obj(n)) for n in clearance.SEA},'urn':list(clearance.obj('Fountain_Offering_Vase').location),'tree':list(clearance.obj('Olive_Ridge_BG_2').location)}
    u=clearance.obj('Fountain_Offering_Vase');ub=trees.bvh(u);box=trees.bounds(u)
    hits=[]
    for o,b in trees.scene_obstacles():
        if o==u or not trees.intersects(box,b):continue
        if ub.overlap(trees.bvh(o)):hits.append(o.name)
    assert not hits,hits
    data['urn_intersections']=hits
    target=clearance.obj('Olive_Ridge_BG_2');tb=wood_bvh(target);bb=trees.bounds(target);hits=[]
    for o in bpy.data.objects:
        if o==target or not trees.is_tree(o) or o.hide_render or o.name.removesuffix('-convcol') in trees.removed or not trees.intersects(bb,trees.bounds(o)):continue
        if tb.overlap(wood_bvh(o)):hits.append(o.name)
    assert not hits,hits
    back=clearance.obj('Olive_Temple_Back_R');assert not wood_bvh(back).overlap(tb)
    data['moved_tree_woody_intersections']=hits
    data['rear_pair_trunk_spacing']=(target.location-back.location).xy.length
    return data

def build():
    assert Path(bpy.data.filepath)==OPT
    crown();erode_sea();grove();urn();bpy.context.view_layer.update()
    data=report()
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(OPT),compress=True)
    return data

def install():
    targets=[clearance.obj('Temple_Entablature')]+[clearance.obj(n) for n in clearance.SEA]
    names=[ROOF]+[n+'-col' for n in clearance.SEA]
    with bpy.data.libraries.load(str(OPT),link=False) as (src,dst):dst.objects=names
    for t,s in zip(targets,dst.objects):t.data=s.data;bpy.data.objects.remove(s,do_unlink=True)
    for n,p in json.loads(clearance.PLAN.read_text())['positions'].items():clearance.obj(n).location=(p[0],-p[2],p[1])
    plan=json.loads((ROOT/'assets/tree_clearance_repairs.json').read_text())
    for row in plan['trees']:clearance.obj(row['name']).location=row['blender_position']
    bpy.context.view_layer.update();data=report()
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(ART),compress=True)
    return data
