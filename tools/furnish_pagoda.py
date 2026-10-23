"""Scoped couch, pagoda furnishings, and continuous bowl outlet via Blender MCP.

build() runs in the optimized map; install() in the artistic map; install_pagoda()
in the standalone pagoda. Never rebuilds the optimized map or landmark export.
"""
from pathlib import Path
import math
import json
import hashlib
import struct

ROOT = Path(__file__).resolve().parent.parent
OUT = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
PILLOWS = ['Lab_Sofa_Ivory_Pillow', 'Lab_Sofa_Ochre_Pillow']
FLOORS = ['Pagoda_Interior_Tea', 'Pagoda_Interior_Reading', 'Pagoda_Interior_Gallery']
WATER = ['Fountain_Hollow_Stone_Bowl', 'Bowl_Overflow_Bridge', 'Bowl_Overflow_Surface', 'Bowl_Overflow_Stream']
YAW = -.88


def make_textures():
    from PIL import Image
    import random
    rng = random.Random(404)
    im = Image.new('RGB', (512, 512))
    pixels = []
    for y in range(512):
        for x in range(512):
            base = (222, 207, 171) if y < 256 else (190, 139, 61)
            weave = ((x % 4 < 2) - .5)*8 + ((y % 4 < 2) - .5)*6 + rng.uniform(-3, 3)
            pixels.append(tuple(max(0, min(255, round(c+weave))) for c in base))
    im.putdata(pixels); im.save(ROOT/'assets/textures/couch_pillow_weave.png')
    from tools.detail_pagoda_furnishings import make_wood_texture
    make_wood_texture(ROOT/'assets/textures/pagoda_furniture_wood.png')
    from tools.detail_pagoda_books import make_atlas
    make_atlas(ROOT/'assets/textures/pagoda_book_bindings.png')


def material(name, color, rough=.65, metal=0, texture=None):
    import bpy
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True; m.diffuse_color=(*color,1)
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metal
    if texture:
        tex=m.node_tree.nodes.get('Original woven texture') or m.node_tree.nodes.new('ShaderNodeTexImage')
        tex.name='Original woven texture'; tex.image=bpy.data.images.load(str(texture),check_existing=True)
        tex.image.reload(); tex.image.pack()
        m.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    return m


class Maker:
    def __init__(self, collection, transform=lambda p:p):
        self.collection=collection; self.transform=transform; self.parts=[]

    def mesh(self, name, vs, fs, mat, smooth=False):
        import bpy
        me=bpy.data.meshes.new(name); me.from_pydata([self.transform(v) for v in vs],[],fs); me.update()
        me.materials.append(mat)
        for p in me.polygons:p.use_smooth=smooth
        # World-projected per-face UVs for original wood and cloth images.
        uv=me.uv_layers.new(name='Craft UV')
        for p in me.polygons:
            axis=max(range(3),key=lambda i:abs(p.normal[i])); a,b=[i for i in range(3) if i!=axis]
            for li in p.loop_indices:
                v=me.vertices[me.loops[li].vertex_index].co
                uv.data[li].uv=(v[a]*1.2,v[b]*1.2)
        o=bpy.data.objects.new(name,me);self.collection.objects.link(o);self.parts.append(o)
        if mat.name in ['Interior | oiled walnut','Interior | recessed walnut']:
            from tools.detail_pagoda_furnishings import wood_uv
            wood_uv(me, vs)
        return o

    def box(self, name, c, size, mat, bevel=.008):
        import bmesh
        from mathutils import Vector
        bm=bmesh.new();bmesh.ops.create_cube(bm,size=1)
        for v in bm.verts:v.co=Vector(c)+Vector([v.co[i]*size[i] for i in range(3)])
        if bevel:bmesh.ops.bevel(bm,geom=list(bm.edges),offset=min(bevel,min(size)*.22),segments=2,affect='EDGES')
        bm.normal_update();bm.verts.ensure_lookup_table();bm.verts.index_update()
        vs=[tuple(v.co) for v in bm.verts];fs=[tuple(v.index for v in f.verts) for f in bm.faces];bm.free()
        return self.mesh(name,vs,fs,mat)

    def lathe(self, name, c, profile, mat, n=32):
        vs=[];fs=[]
        for r,z in profile:
            for i in range(n):
                a=math.tau*i/n;vs.append((c[0]+r*math.cos(a),c[1]+r*math.sin(a),c[2]+z))
        for j in range(len(profile)-1):
            for i in range(n):
                a=j*n+i;b=j*n+(i+1)%n;fs.append((a,b,b+n,a+n))
        fs += [tuple(reversed(range(n))),tuple((len(profile)-1)*n+i for i in range(n))]
        return self.mesh(name,vs,fs,mat,True)

    def tube(self, name, points, radius, mat, n=8, closed=False):
        from mathutils import Vector
        points=[Vector(p) for p in points];vs=[];fs=[]
        for j,p in enumerate(points):
            d=points[(j+1)%len(points)]-points[(j-1)%len(points)] if closed else points[min(j+1,len(points)-1)]-points[max(0,j-1)]
            d.normalize();a=d.cross(Vector((0,0,1)))
            if a.length<.01:a=d.cross(Vector((0,1,0)))
            a.normalize();b=d.cross(a).normalized()
            for k in range(n):
                t=math.tau*k/n;vs.append(p+radius*(a*math.cos(t)+b*math.sin(t)))
        for j in range(len(points) if closed else len(points)-1):
            for k in range(n):fs.append((j*n+k,j*n+(k+1)%n,((j+1)%len(points))*n+(k+1)%n,((j+1)%len(points))*n+k))
        if not closed:fs += [tuple(reversed(range(n))),tuple((len(points)-1)*n+i for i in range(n))]
        return self.mesh(name,vs,fs,mat,True)

    def join(self, name):
        import bpy
        bpy.ops.object.select_all(action='DESELECT')
        for o in self.parts:o.select_set(True)
        bpy.context.view_layer.objects.active=self.parts[0];bpy.ops.object.join()
        o=bpy.context.object;o.name=name;o['interior_detail_version']=3
        return o


def collection(name):
    import bpy
    c=bpy.data.collections.get(name)
    if not c:c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
    return c


def find(name):
    import bpy
    return bpy.data.objects.get(name+'-col') or bpy.data.objects.get(name)


def pillow(name, y, lean, atlas_slot):
    import bpy
    from mathutils import Vector, Euler
    o=find(name)
    for modifier in list(o.modifiers):o.modifiers.remove(modifier)
    m=Maker(o.users_collection[0]); mat=material('Interior | woven cushion cloth',(1,1,1),.95,texture=ROOT/'assets/textures/couch_pillow_weave.png')
    vs=[];fs=[];N=26
    # Two bulging cloth panels, softly rounded corners, gathered near the seam.
    for side in [-1,1]:
        for j in range(N+1):
            v=j/N*2-1
            for i in range(N+1):
                u=i/N*2-1
                yy=.27*u*math.sqrt(1-.16*v*v);zz=.285*v*math.sqrt(1-.16*u*u)
                bulge=max(0,(1-u*u)*(1-v*v))**.55
                gather=.003*math.sin(u*24+v*7)*math.exp(-((abs(v)-.82)/.13)**2)*(1-u*u)
                vs.append((side*(.017+.102*bulge+gather),yy,zz))
    stride=(N+1)**2
    for panel in range(2):
        for j in range(N):
            for i in range(N):
                a=panel*stride+j*(N+1)+i;q=(a,a+1,a+N+2,a+N+1)
                fs.append(tuple(reversed(q)) if panel==0 else q)
    boundary=list(range(N+1))+[j*(N+1)+N for j in range(1,N+1)]+[N*(N+1)+i for i in range(N-1,-1,-1)]+[j*(N+1) for j in range(N-1,0,-1)]
    for a,b in zip(boundary,boundary[1:]+boundary[:1]):fs.append((a,b,b+stride,a+stride))
    panel=m.mesh(name+' soft panels',vs,fs,mat,True)
    for p in panel.data.polygons:
        for li in p.loop_indices:
            co=panel.data.vertices[panel.data.loops[li].vertex_index].co
            panel.data.uv_layers.active.data[li].uv=((co.y/.54+.5),(.5+(co.z/.57+.5)*.5) if atlas_slot==0 else (co.z/.57+.5)*.5)
    cord=material('Interior | ivory piping' if atlas_slot==0 else 'Interior | ochre piping',(.69,.60,.40) if atlas_slot==0 else (.34,.20,.065),.88)
    m.tube('stitched perimeter',[(0,vs[i][1],vs[i][2]) for i in boundary],.0045,cord,closed=True)
    built=m.join(name+' new')
    o.data=built.data;bpy.data.objects.remove(built,do_unlink=True)
    o.rotation_euler=Euler((lean,.26,-.08 if atlas_slot==0 else .08));o.location=(-1.825,y,0)
    bpy.context.view_layer.update()
    low=min((o.matrix_world@v.co).z for v in o.data.vertices)
    o.location.z=5.137-low
    o['soft_cushion']=True
    bpy.context.view_layer.update()
    return o


def world(p):
    x,y,z=p;c,s=math.cos(YAW),math.sin(YAW)
    return (92+c*x-s*y,64+s*x+c*y,5.5+z)


def furnishings():
    import bpy
    c=collection('Pagoda interior furnishings')
    for o in list(c.objects):bpy.data.objects.remove(o,do_unlink=True)
    wood=material('Interior | oiled walnut',(.30,.15,.07),.48,texture=ROOT/'assets/textures/pagoda_furniture_wood.png')
    dark=material('Interior | dark end grain',(.075,.035,.019),.7)
    bronze=material('Interior | brushed bronze',(.43,.26,.075),.35,.65)
    jade=material('Interior | celadon glaze',(.15,.34,.28),.25,.10)
    ivory=material('Interior | porcelain',(.72,.69,.55),.28)
    tea=material('Interior | dark tea',(.09,.035,.009),.13)
    paper=material('Interior | rice paper',(.73,.65,.45),.93)
    fabric=material('Interior | moss woven seats',(.19,.27,.15),.94)
    rust=material('Interior | muted terracotta',(.37,.13,.055),.88)
    ink=material('Interior | ink',(.018,.028,.025),.8)
    from tools.detail_pagoda_furnishings import bonsai as detailed_bonsai, cabinet as detailed_cabinet
    bark=material('Interior | bonsai bark',(.17,.095,.043),.94,texture=ROOT/'assets/textures/pagoda_bonsai_bark.png')
    leaf_mats=[material('Interior | bonsai leaf '+str(i),color,.88) for i,color in enumerate([(.065,.18,.042),(.105,.24,.059),(.15,.29,.078),(.035,.115,.03)])]
    moss=material('Interior | planter moss',(.12,.18,.042),1)
    stone=material('Interior | planter gravel',(.30,.25,.17),.95)
    panel=material('Interior | recessed walnut',(.16,.075,.030),.53,texture=ROOT/'assets/textures/pagoda_walnut_inset.png')
    from tools.detail_pagoda_books import shelf_books
    bindings=material('Interior | original book bindings',(1,1,1),.82,texture=ROOT/'assets/textures/pagoda_book_bindings.png')
    papers=[material('Interior | book paper '+str(i),color,.95) for i,color in enumerate([(.64,.56,.40),(.79,.73,.59),(.53,.47,.34)])]
    props=[];colliders=[];libraries=[]
    def record(name,level,center,size):
        props.append({'name':name,'floor':level+1,'local_center':list(center),'size':list(size)})
        colliders.append({'name':name,'center':list(world(center)),'size':list(size),'yaw':YAW})
    def table(m,x,y,z,w,d,h,name,level):
        m.box(name+' slab',(x,y,z+h-.045),(w,d,.09),wood,.025)
        m.box('inlaid border',(x,y,z+h+.003),(w-.12,d-.12,.008),dark,.002)
        for dx in [-w*.39,w*.39]:
            for dy in [-d*.32,d*.32]:m.box('square mortise leg',(x+dx,y+dy,z+(h-.09)/2),(.09,.09,h-.09),wood)
        for dy in [-d*.32,d*.32]:m.box('long apron',(x,y+dy,z+h-.17),(w*.83,.055,.19),wood)
        record(name,level,(x,y,z+h/2),(w,d,h))
    def vessel(m,x,y,z,scale=1,mat=jade):
        p=[(.11,0),(.13,.025),(.15,.13),(.13,.25),(.07,.31),(.07,.38),(.086,.4),(.086,.42),(.062,.42),(.058,.36),(.05,.34)]
        m.lathe('glazed vase',(x,y,z),[(r*scale,h*scale) for r,h in p],mat,40)
        for h,r in [(.035,.134),(.29,.093)]:m.lathe('ceramic gold band',(x,y,z+h*scale),[(r*scale,0),(r*scale,.009*scale)],bronze)
    def cabinet(m,x,y,z,w,d,h,name,level):
        detailed_cabinet(m,x,y,z,w,d,h,name,wood,dark,bronze,panel)
        record(name,level,(x,y,z+h/2),(w,d+.04,h))
    def bonsai(m,x,y,z,level):
        variant=level+(1 if x>0 else 0)
        detailed_bonsai(m,x,y,z,variant,jade,dark,bark,leaf_mats,moss,stone)
        record('bonsai',level,(x,y,z+.36),(.64,.64,.72))
    for level,z in enumerate([1.,5.4,9.8]):
        m=Maker(c,world)
        if level==0:
            table(m,0,4.65,z,2.15,.84,.53,'tea table',level)
            # Serving tray, open cups, teapot, handle and an actually joined spout.
            m.box('tea tray',(0,4.65,z+.55),(1.35,.58,.035),wood,.04)
            m.lathe('teapot',(0,4.65,z+.57),[(.08,0),(.15,.04),(.17,.13),(.12,.21),(.09,.23)],jade,40)
            m.lathe('teapot lid',(0,4.65,z+.8),[(.10,0),(.11,.012),(.07,.032),(.025,.04),(.025,.065)],jade)
            m.tube('teapot handle',[(.12+.14*math.sin(a),4.65,z+.70+.13*math.cos(a)) for a in [i*math.pi/16 for i in range(17)]],.023,jade)
            m.tube('teapot spout',[(-.12,4.65,z+.66),(-.23,4.65,z+.71),(-.29,4.65,z+.82)],.035,jade,12)
            for x,y in [(-.46,4.5),(.43,4.5),(.43,4.85)]:
                m.lathe('tea cup',(x,y,z+.58),[(.045,0),(.065,.015),(.075,.09),(.065,.095),(.053,.02)],ivory)
                m.lathe('tea surface',(x,y,z+.65),[(.061,0),(.061,.001)],tea)
                m.lathe('cup saucer',(x,y,z+.57),[(.085,0),(.095,.012),(.073,.016)],jade)
            for x in [-.68,.68]:
                m.lathe('round floor cushion',(x,3.93,z),[(.25,.012),(.32,.045),(.33,.10),(.30,.16),(.12,.18),(.015,.175)],fabric,48)
                record('tea cushion',level,(x,3.93,z+.085),(.62,.62,.17))
            cabinet(m,-4.6,4.85,z,1.35,.55,1.15,'tea cabinet',level)
            vessel(m,-4.83,4.85,z+1.15,.60,ivory)
            libraries.append({'floor':1,'books':shelf_books(m,-4.6,4.81,z+.6075,1.15,1,0,bindings,papers,bronze,dark)})
            # Corner planting and a long low bench occupy the outside bays.
            table(m,4.9,3.9,z,.66,.66,.50,'bonsai stand',level)
            bonsai(m,4.9,3.9,z+.50,level)
            table(m,-4.95,-.7,z,.65,2.2,.45,'entry bench',level)
        elif level==1:
            table(m,0,4.5,z,2.5,.66,.78,'reading desk',level)
            m.box('open manuscript',(0,4.48,z+.805),(.60,.40,.035),paper,.008)
            m.box('book spine',(0,4.48,z+.825),(.014,.39,.006),dark,.001)
            for dx in [-.15,.15]:
                for j in range(7):m.box('ink manuscript lines',(dx,4.34+j*.043,z+.825),(.22,.005,.002),ink,.0004)
            m.lathe('brush pot',(.87,4.52,z+.78),[(.075,0),(.082,.15),(.073,.16),(.057,.145)],jade)
            for i in range(3):m.tube('calligraphy brush',[(.83+i*.035,4.52,z+.84),(.81+i*.047,4.53,z+1.16)],.008,dark)
            m.box('inkstone',(-.82,4.49,z+.81),(.18,.12,.035),ink,.02)
            cabinet(m,-3.55,-4.55,z,1.50,.54,1.35,'book cabinet',level)
            libraries.append({'floor':2,'books':shelf_books(m,-3.55,-4.55,z+.7075,1.30,-1,1,bindings,papers,bronze,dark)})
            vessel(m,3.7,4.58,z,.90,rust)
            m.lathe('reading cushion',(0,3.83,z),[(.25,.01),(.30,.05),(.31,.11),(.23,.17),(.02,.17)],rust,48)
            record('reading cushion',level,(0,3.83,z+.085),(.60,.60,.17))
        else:
            table(m,0,4.02,z,2.20,.55,.84,'ceramic display console',level)
            for x,s,mt in [(-.68,.9,ivory),(0,.68,jade),(.65,1.16,rust)]:vessel(m,x,4.02,z+.84,s,mt)
            for x in [-3.75,3.75]:
                table(m,x,3.75,z,.62,.62,.48,'corner bonsai stand',level)
                bonsai(m,x,3.75,z+.48,level)
            # An observation writing tray is separate from the stair opening.
            table(m,-2.8,-4.03,z,1.4,.52,.60,'observation writing table',level)
            m.box('rolled map',(-2.8,-4.03,z+.62),(.76,.30,.025),paper)
            for dx in [-.38,.38]:m.tube('map scroll roller',[(-2.8+dx,-4.22,z+.65),(-2.8+dx,-3.84,z+.65)],.028,wood,12)
        m.join(FLOORS[level])
    data={'version':3,'detail':{'painting':False,'bonsai_count':3,'individual_leaves':3168,'cabinets_with_joinery':2,'closed_cabinet_seams':True,'branches_anchored_to_trunk':True},'libraries':libraries,'floors':FLOORS,'props':props,'colliders':colliders,'stairs_clear_radius':3.55,'source':'Original procedural geometry and textures; no downloaded models'}
    (ROOT/'assets/pagoda_interior.json').write_text(json.dumps(data,indent=2)+'\n')
    return [bpy.data.objects[n] for n in FLOORS]


def overflow():
    import bpy
    from mathutils import Vector
    bowl=find(WATER[0]);bowl.data=bowl.data.copy()
    # Lower the three southern rim vertices per ring to form a real spill notch.
    for v in bowl.data.vertices:
        p=bowl.matrix_world@v.co
        if abs(p.x-3.4)<.18 and p.y<2.6 and p.z>4.44:
            p.z=min(p.z,4.46);v.co=bowl.matrix_world.inverted()@p
    bowl.data.update()
    bridge=find(WATER[1]);bridge.data=bridge.data.copy()
    for v in bridge.data.vertices:
        if v.co.z>4.44:v.co.z=4.45
    bridge.data.update()
    for name,start,end in [('Bowl_Overflow_Surface',0,.24),('Bowl_Overflow_Stream',.24,1)]:
        o=find(name);mat=o.data.materials[0];vs=[];fs=[];uvs=[];rings=14 if end<1 else 48;n=40
        for j in range(rings+1):
            t=start+(end-start)*j/rings
            if t<=.24:y=2.56-.33*t/.24;z=4.466;d=Vector((0,-1,0));width=.24;thick=.028
            else:
                q=(t-.24)/.76;y=2.23-.33*q;z=4.466-.86*q*q
                d=Vector((0,-.33,-1.72*q)).normalized();width=.24-.06*q;thick=.028+.035*q
            cross=Vector((1,0,0));normal=cross.cross(d).normalized()
            for i in range(n):
                a=math.tau*i/n;p=Vector((3.4,y,z))+cross*(width/2*math.cos(a))+normal*(thick/2*math.sin(a))
                vs.append(p);uvs.append((i/n,t))
        for j in range(rings):
            for i in range(n):
                a=j*n+i;b=j*n+(i+1)%n;fs.append((a,a+n,b+n,b))
        # Only the two remote ends are capped; shared ring is exactly identical.
        if start==0:fs.append(tuple(reversed(range(n))))
        if end==1:fs.append(tuple(rings*n+i for i in range(n)))
        if o.type!='MESH':
            old=o;old.name=name+' retired curve';o=bpy.data.objects.new(name,bpy.data.meshes.new(name));old.users_collection[0].objects.link(o)
            bpy.data.objects.remove(old,do_unlink=True)
        me=bpy.data.meshes.new(name+' continuous volume');me.from_pydata(vs,[],fs);me.update();me.materials.append(mat)
        uv=me.uv_layers.new(name='Continuous downhill flow')
        for p in me.polygons:
            p.use_smooth=len(p.vertices)==4
            for li in p.loop_indices:uv.data[li].uv=uvs[me.loops[li].vertex_index]
        for modifier in list(o.modifiers):o.modifiers.remove(modifier)
        o.data=me;o.matrix_world.identity();o['connected_bowl_outlet']=True
    return [find(n) for n in WATER]


def export(objects,path):
    import bpy
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path),export_format='GLB',use_selection=True,export_cameras=False,export_lights=False,export_animations=False)


def build():
    import bpy
    assert Path(bpy.data.filepath)==ROOT/'assets/mediterranean_temple.blend'
    pillows=[pillow(PILLOWS[0],7.09,-.09,0),pillow(PILLOWS[1],8.97,.12,1)]
    interior=furnishings();water=overflow()
    export(pillows,ROOT/'assets/couch_pillows.glb')
    export(interior,ROOT/'assets/pagoda_interior.glb')
    export(water,ROOT/'assets/bowl_outlet_detail.glb')
    save();return report()


def refine_interior():
    import bpy
    assert Path(bpy.data.filepath)==ROOT/'assets/mediterranean_temple.blend'
    interior=furnishings()
    export(interior,ROOT/'assets/pagoda_interior.glb')
    save();return report(True)


def save():
    import bpy
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)


def install(only_pagoda=False):
    import bpy
    targets=FLOORS if only_pagoda else PILLOWS+FLOORS+WATER
    source=ROOT/'assets/mediterranean_temple.blend'
    previous={name:find(name) for name in targets}
    with bpy.data.libraries.load(str(source),link=False) as (src,dst):
        dst.objects=[n+'-col' if n+'-col' in src.objects else n for n in targets]
    for name,new in zip(targets,dst.objects):
        old=previous[name]
        if old:
            if old.type==new.type:old.data=new.data;old.matrix_basis=new.matrix_basis.copy();bpy.data.objects.remove(new,do_unlink=True)
            else:
                cols=list(old.users_collection);bpy.data.objects.remove(old,do_unlink=True);new.name=name
                for c in cols:c.objects.link(new)
        else:
            new.name=name
            collection('Pagoda interior furnishings').objects.link(new)
        new=find(name)
        if new:
            new.hide_render=False;new.hide_set(False)
            if name in PILLOWS+['Bowl_Overflow_Surface','Bowl_Overflow_Stream']:
                for modifier in list(new.modifiers):new.modifiers.remove(modifier)
    bpy.context.view_layer.update()
    save();return report(only_pagoda)


def install_pagoda():return install(True)


def report(only_pagoda=False):
    import bpy
    from mathutils import Vector
    rows=[]
    for n in (FLOORS if only_pagoda else PILLOWS+FLOORS+WATER):
        o=find(n);points=[o.matrix_world@v.co for v in o.data.vertices]
        digest=hashlib.sha256(b''.join(struct.pack('<3f',*v) for v in points)).hexdigest()
        rows.append({'name':n,'vertices':len(points),'sha256':digest,'local_sha256':hashlib.sha256(b''.join(struct.pack('<3f',*v.co) for v in o.data.vertices)).hexdigest(),'bounds':[[min(v[i] for v in points),max(v[i] for v in points)] for i in range(3)]})
    if not only_pagoda:
        a=find('Bowl_Overflow_Surface').data;b=find('Bowl_Overflow_Stream').data
        assert max((a.vertices[len(a.vertices)-40+i].co-b.vertices[i].co).length for i in range(40))<1e-6
    return {'saved_file':bpy.data.filepath,'meshes':rows,'outlet_shared_ring':not only_pagoda}
