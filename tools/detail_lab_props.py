"""Original microscope and fourteen reagent bottles; scoped Blender MCP build.

Run make_labels() with regular Python, then build_and_export() in the optimized
map and install_saved() in the artistic map. No full-map export is performed.
"""
from pathlib import Path
import math
import hashlib
import struct

ROOT = Path(__file__).resolve().parent.parent
ART = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
ATLAS = ROOT / 'assets/textures/lab_reagent_labels.png'
NAMES = ['LabDetail_Microscope', 'LabDetail_Reagents', 'LabDetail_Glass']
SPECIMENS = ['SEAWATER', 'BUFFER', 'NaCl', 'ALGAE', 'SILT', 'INDICATOR', 'BLANK',
             'ESTUARY', 'TRACE', 'MgCl2', 'CULTURE', 'SEDIMENT', 'pH DYE', 'CONTROL']
COLORS = [(29, 111, 131), (171, 108, 44), (57, 101, 128), (58, 119, 83),
          (140, 90, 50), (127, 72, 106), (63, 115, 120)]


def make_labels():
    from PIL import Image, ImageDraw, ImageFont
    im = Image.new('RGB', (2048, 1024), (226, 224, 205))
    d = ImageDraw.Draw(im)
    fonts = '/usr/share/fonts/TTF/'
    def font(size, bold=False):
        return ImageFont.truetype(fonts + ('DejaVuSans-Bold.ttf' if bold else 'DejaVuSans.ttf'), size)
    for i, title in enumerate(SPECIMENS):
        x, y = (i % 4) * 512, (i // 4) * 256
        c = COLORS[i % 7]
        d.rounded_rectangle((x+4, y+4, x+508, y+252), radius=15, fill=(237, 234, 213), outline=(172, 177, 160), width=3)
        d.rectangle((x+12, y+12, x+500, y+51), fill=c)
        d.text((x+28, y+17), 'PELAGIC   /   FIELD LAB', font=font(23, True), fill=(249, 245, 224))
        d.text((x+28, y+64), title, font=font(40, True), fill=(28, 52, 51))
        d.text((x+29, y+117), f'{"100" if i%3==0 else "250"} mL   |   LOT P-{i+1:02d}', font=font(24), fill=(53, 74, 66))
        d.line((x+27, y+154, x+485, y+154), fill=c, width=3)
        d.text((x+28, y+166), 'SAMPLE / RESEARCH', font=font(20), fill=(57, 77, 68))
        for j in range(56):
            w = 2 if (j*7+i)%5 else 4
            d.rectangle((x+29+j*5, y+203, x+29+j*5+w, y+232), fill=(43, 58, 51))
        d.text((x+343, y+199), f'{i+1:02d}', font=font(31, True), fill=c)
    ATLAS.parent.mkdir(parents=True, exist_ok=True)
    im.save(ATLAS)
    return str(ATLAS)


def original(o):
    return o.name.startswith(('Lab_Microscope_', 'Lab_Reagent_Bottle', 'Lab_Bottle_Cap', 'Lab_Bottle_Label')) or o.name == 'Lab_Glass_Slide'


def build_and_export():
    import bpy
    import bmesh
    from mathutils import Vector
    for name in NAMES:
        old = bpy.data.objects.get(name)
        if old:
            bpy.data.objects.remove(old, do_unlink=True)
    collection = bpy.data.collections.get('Lab optical and reagent detail')
    if not collection:
        collection = bpy.data.collections.new('Lab optical and reagent detail')
        bpy.context.scene.collection.children.link(collection)
    def mat(name, color, rough=.4, metal=0, alpha=1):
        name = 'LabDetail | ' + name
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        p = m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value = (*color, 1)
        p.inputs['Roughness'].default_value = rough
        p.inputs['Metallic'].default_value = metal
        p.inputs['Alpha'].default_value = alpha
        m.diffuse_color = (*color, alpha)
        if alpha < 1:
            m.surface_render_method = 'BLENDED'
        return m
    ivory = mat('cast ivory enamel', (.56, .61, .57), .3, .12)
    teal = mat('teal enamel', (.025, .15, .15), .28, .25)
    black = mat('anodized graphite', (.015, .024, .032), .32, .35)
    rubber = mat('rubber grip', (.009, .013, .016), .68)
    steel = mat('machined nickel', (.44, .51, .52), .24, .82)
    brass = mat('objective brass', (.47, .31, .105), .26, .74)
    red = mat('objective red band', (.52, .03, .022), .38)
    blue = mat('objective blue band', (.025, .12, .42), .32)
    lens = mat('optical coated lens', (.015, .105, .125), .085, .48)
    opal = mat('opal illuminator', (.62, .77, .70), .2)
    p = opal.node_tree.nodes.get('Principled BSDF')
    p.inputs['Emission Color'].default_value = (.25, .48, .37, 1)
    p.inputs['Emission Strength'].default_value = .35
    glass = mat('clear bottle glass', (.48, .70, .68), .13, .08, .23)
    amber = mat('amber bottle glass', (.40, .18, .045), .16, .1, .38)
    slide = mat('glass slide edge', (.27, .49, .49), .13, .22)
    fills = [mat('sample '+str(i), c, .18, .08) for i, c in enumerate([
        (.035,.23,.27), (.32,.17,.038), (.14,.32,.33), (.055,.22,.08),
        (.20,.115,.045), (.28,.055,.13), (.19,.34,.35)])]
    label = mat('printed reagent labels', (.95,.93,.83), .64)
    img = bpy.data.images.load(str(ATLAS), check_existing=True)
    img.reload()
    tex = label.node_tree.nodes.get('Reagent atlas') or label.node_tree.nodes.new('ShaderNodeTexImage')
    tex.name = 'Reagent atlas'; tex.image = img
    label.node_tree.links.new(tex.outputs['Color'], label.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    parts = []
    def obj(name, mesh, material, group):
        o = bpy.data.objects.new(name, mesh); collection.objects.link(o)
        mesh.materials.append(material); parts.append((o,group)); return o
    def box(name, loc, size, material, group='scope', bevel=.006):
        bm = bmesh.new(); bmesh.ops.create_cube(bm, size=1)
        for v in bm.verts: v.co = Vector((v.co.x*size[0],v.co.y*size[1],v.co.z*size[2]))
        if bevel:
            bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=3, affect='EDGES')
        bm.normal_update(); me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
        o = obj(name,me,material,group); o.location = loc; return o
    def lathe(name, loc, profile, material, group='scope', segments=40, square=False, axis=None, ridges=0):
        vs=[]; fs=[]
        for r,z in profile:
            for i in range(segments):
                a = math.tau*i/segments
                cx,cy = math.cos(a),math.sin(a)
                if square:
                    cx=math.copysign(abs(cx)**.52,cx); cy=math.copysign(abs(cy)**.52,cy)
                rr = r * (1 + ridges * (i%2))
                vs.append((rr*cx,rr*cy,z))
        for j in range(len(profile)-1):
            for i in range(segments):
                a=j*segments+i; b=j*segments+(i+1)%segments
                fs.append((a,b,b+segments,a+segments))
        fs.extend([tuple(reversed(range(segments))),tuple((len(profile)-1)*segments+i for i in range(segments))])
        me=bpy.data.meshes.new(name); me.from_pydata(vs,[],fs); me.update()
        for p in me.polygons: p.use_smooth=len(p.vertices)==4 and not ridges
        o=obj(name,me,material,group); o.location=loc
        if axis: o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
        return o
    def cyl(name, loc, r, h, material, group='scope', axis=None, ridges=0):
        return lathe(name,loc,[(r*.94,-h/2),(r,-h/2+.002),(r,h/2-.002),(r*.94,h/2)],material,group,48,axis=axis,ridges=ridges)
    def rod(name, a, b, r, material):
        a,b=Vector(a),Vector(b)
        return cyl(name,(a+b)/2,r,(b-a).length,material,axis=b-a)
    origin=Vector((-1.61,3.37,5.496))
    def P(x,y,z): return origin+Vector((x,y,z))
    box('weighted base',P(0,0,.04),(.36,.40,.08),ivory,bevel=.027)
    box('base sole',P(0,0,.012),(.335,.375,.025),teal,bevel=.015)
    for x in [-.115,.115]:
        for y in [-.145,.145]:cyl('rubber foot',P(x,y,.002),.025,.012,rubber)
    # A cast curved support connects the base, head and turret mechanically.
    outline=[(.095,.065),(.175,.065),(.175,.52),(.145,.605),(.005,.665),(-.072,.65),(-.072,.592),(.078,.548),(.095,.48)]
    vs=[tuple(P(x,y,z)) for y in [.055,.137] for x,z in outline]; n=len(outline)
    fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    me=bpy.data.meshes.new('cast C support');me.from_pydata(vs,[],fs);me.update()
    arm=obj('cast C support',me,ivory,'scope')
    mod=arm.modifiers.new('Soft casting edges','BEVEL');mod.width=.012;mod.segments=3
    mod=arm.modifiers.new('Casting normals','WEIGHTED_NORMAL')
    box('rack mount',P(.105,.043,.31),(.055,.025,.30),black,bevel=.004)
    for z in [.19,.24,.29,.34,.39,.44]:box('rack tooth',P(.105,.027,z),(.05,.012,.006),steel,bevel=.001)
    # Aperture cut directly into the stage, aligned with the working objective.
    stage_z=.292; cx,cy=-.04,-.035; seg=64; vs=[]; fs=[]
    for z in [stage_z-.014,stage_z+.014]:
        for outer in [False,True]:
            for i in range(seg):
                a=math.tau*i/seg; dx,dy=math.cos(a),math.sin(a)
                r=.14/max(abs(dx),abs(dy)) if outer else .023
                vs.append(tuple(P(cx+r*dx,cy+r*dy,z)))
    for i in range(seg):
        j=(i+1)%seg
        fs.extend([(i,j,seg+j,seg+i),(2*seg+i,3*seg+i,3*seg+j,2*seg+j),
                   (i,2*seg+i,2*seg+j,j),(seg+i,seg+j,3*seg+j,3*seg+i)])
    me=bpy.data.meshes.new('mechanical stage with optical aperture');me.from_pydata(vs,[],fs);me.update();obj('mechanical stage',me,black,'scope')
    box('stage carriage',P(.065,.062,.315),(.09,.025,.022),steel,bevel=.003)
    box('specimen glass',P(cx,cy,.313),(.12,.045,.007),slide,bevel=.002)
    cyl('sample coverslip',P(cx,cy,.318),.011,.002,opal)
    for y in [cy-.027,cy+.027]:
        box('spring slide clip',P(-.075,y,.321),(.085,.009,.005),steel,bevel=.002)
        cyl('clip screw',P(-.112,y,.326),.006,.006,black)
    cyl('condenser',P(cx,cy,.247),.043,.050,black)
    cyl('iris collar',P(cx,cy,.219),.050,.013,steel)
    rod('iris lever',P(cx,cy,.219),P(cx-.075,cy-.01,.219),.004,steel)
    cyl('lamp bezel',P(cx,cy,.092),.053,.025,black)
    cyl('lamp lens',P(cx,cy,.107),.042,.007,opal)
    # Shared optical head, rotary nosepiece and three attached objectives.
    cyl('optical head',P(-.04,-.005,.625),.063,.09,ivory)
    cyl('revolving nosepiece bearing',P(-.04,-.005,.573),.047,.022,brass)
    cyl('revolving nosepiece',P(-.04,-.005,.554),.073,.025,black)
    for i,(dx,dy,length,band) in enumerate([(0,-.030,.20,blue),(.039,.023,.115,red),(-.039,.023,.145,brass)]):
        top=P(-.04+dx,-.005+dy,.545)
        direction=Vector((dx*.6,dy*.4,-1)).normalized()
        end=top+direction*length
        rod('objective barrel '+str(i),top,end,.021,steel)
        rod('objective grip '+str(i),top,top+direction*.035,.025,black)
        rod('objective color band '+str(i),end-direction*.038,end-direction*.025,.0225,band)
        rod('objective nose '+str(i),end,end+direction*.008,.016,brass)
        cyl('objective front lens',end+direction*.009,.012,.003,lens,axis=direction)
    a=P(-.04,-.005,.66); b=P(-.135,-.115,.807); direction=(b-a).normalized()
    rod('inclined viewing tube',a,b,.037,black)
    rod('tube chrome collar',a+direction*.025,a+direction*.043,.039,steel)
    rod('eyepiece diopter',b-direction*.028,b,.042,rubber)
    rod('rubber eyecup',b,b+direction*.025,.048,rubber)
    cyl('eyepiece coated glass',b+direction*.026,.034,.004,lens,axis=direction)
    for y,sign in [(-.003,-1),(.188,1)]:
        cyl('coarse focus',P(.128,y,.36),.048,.035,black,axis=(0,1,0),ridges=.055)
        cyl('fine focus',P(.128,y+sign*.022,.36),.026,.018,steel,axis=(0,1,0),ridges=.07)
        cyl('focus center',P(.128,y+sign*.033,.36),.014,.005,teal,axis=(0,1,0))
    for y in [-.13,.14]:
        cyl('base screw',P(.10,y,.084),.008,.004,steel)
        box('screw slot',P(.10,y,.087),(.011,.002,.001),black,bevel=0)
    box('power rocker',P(-.181,.105,.043),(.006,.039,.02),black,bevel=.002)
    box('power indicator',P(-.183,.065,.043),(.007,.008,.008),opal,bevel=.001)
    box('instrument badge',P(-.182,-.052,.047),(.004,.09,.018),teal,bevel=.002)
    # Fourteen individually labelled vessels retain the existing shelf sites.
    for i in range(14):
        row,slot=divmod(i,7); z0=[6.254,6.944][row]; yy=3.33+slot*.235
        # Upper shelf is an independent assortment, not a repeated silhouette row.
        col=slot if row==0 else [4,0,6,2,5,1,3][slot]
        h=[.215,.275,.31,.24,.285,.27,.22][col]*(1.0 if row==0 else [1.04,.91,1.12,.94,1.03,.90,1.15][slot])
        r=[.058,.060,.055,.062,.064,.052,.057][col]
        square=col in [2,6]; wide=col==4; neck=r*.74 if wide else r*.48
        body_h=h*.74
        profile=[(r*.88,.002),(r,.009),(r,.028),(r,body_h),
                 (r*.94,body_h+.012),(neck,h*.88),(neck,h-.009),(neck*1.05,h)]
        loc=(-1.30,yy,z0)
        lathe('vessel shell',loc,profile,amber if col in [1,4] else glass,'glass',48,square)
        # Separate internal liquid and meniscus remain readable through glass.
        level=body_h*[.65,.76,.53,.72,.58,.66,.42][col]
        liquid=fills[(col+row*2)%7]
        lathe('sample liquid',loc,[(r*.79,.010),(r*.89,.018),(r*.89,level-.003),(r*.86,level)],liquid,'bottles',48,square)
        lathe('meniscus rim',(-1.30,yy,z0+level),[(r*.86,-.002),(r*.89,0),(r*.87,.003),(r*.84,.001)],liquid,'bottles',48,square)
        cap_h=.026 if wide else .032
        capmat=teal if col in [0,3] else black
        cyl('neck tamper ring',(-1.30,yy,z0+h-.004),neck*1.11,.012,steel,'bottles')
        lathe('ribbed screw cap',(-1.30,yy,z0+h+cap_h*.42),[(neck*1.10,-cap_h/2),(neck*1.12,-cap_h*.35),(neck*1.12,cap_h*.35),(neck*1.07,cap_h/2)],capmat,'bottles',64,ridges=.045)
        if col==5:
            lathe('dropper bulb',(-1.30,yy,z0+h+.025),[(.017,0),(.018,.025),(.013,.046),(.003,.052)],rubber,'bottles',32)
        # Curved printed label wraps the front (-X) face without floating.
        lv=[]; lf=[]; lh=.083; center_z=z0+body_h*.48
        for zz in [-lh/2,lh/2]:
            for j in range(17):
                ang=math.pi+(-.76+1.52*j/16)
                dx,dy=math.cos(ang),math.sin(ang)
                if square: dx=math.copysign(abs(dx)**.52,dx);dy=math.copysign(abs(dy)**.52,dy)
                lv.append((-1.30+(r+.0009)*dx,yy+(r+.0009)*dy,center_z+zz))
        for j in range(16):lf.append((j,j+1,j+18,j+17))
        me=bpy.data.meshes.new('curved printed label');me.from_pydata(lv,[],lf);me.update()
        uv=me.uv_layers.new(name='Individual reagent label')
        for p in me.polygons:
            for li in p.loop_indices:
                v=me.loops[li].vertex_index
                # Seen from -X, increasing arc index runs left-to-right.
                u=(i%4 + (v%17)/16)/4
                vv=1-(i//4+1)/4+(v//17)/4
                uv.data[li].uv=(u,vv)
        obj('individual reagent label',me,label,'bottles')
        # Fired-on volume graduations on the shoulder side of the label.
        for tick in range(4):
            box('volume graduation',(-1.30-r*.70,yy+r*.72,z0+.045+tick*.025),(.003,.017 if tick%2==0 else .011,.0015),ivory,'bottles',bevel=0)
    # Three draw groups; retain manufacturing parts in the mesh material slots.
    for group,name in zip(['scope','bottles','glass'],NAMES):
        os=[o for o,g in parts if g==group]
        bpy.ops.object.select_all(action='DESELECT')
        for o in os:
            o.select_set(True);bpy.context.view_layer.objects.active=o
            for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        bpy.context.view_layer.objects.active=os[0];bpy.ops.object.join()
        o=bpy.context.object;o.name=name
        # World-space vertices and zero transforms make source installs exact.
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        o['lab_detail_version']=1
        o['description']='Connected compound microscope' if group=='scope' else 'Fourteen individual marine field lab reagents'
    for o in bpy.data.objects:
        if original(o):o.hide_render=True;o.hide_set(True);o['replaced_by_lab_detail']=True
    bpy.ops.object.select_all(action='DESELECT')
    for name in NAMES:bpy.data.objects[name].select_set(True)
    bpy.context.view_layer.objects.active=bpy.data.objects[NAMES[0]]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/lab_prop_detail.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    return report()


def install_saved():
    import bpy
    for name in NAMES:
        o=bpy.data.objects.get(name)
        if o:bpy.data.objects.remove(o,do_unlink=True)
    col=bpy.data.collections.get('Lab optical and reagent detail')
    if not col:
        col=bpy.data.collections.new('Lab optical and reagent detail');bpy.context.scene.collection.children.link(col)
    with bpy.data.libraries.load(str(ROOT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):
        dst.objects=list(NAMES)
    for o in dst.objects:col.objects.link(o)
    for o in bpy.data.objects:
        if original(o):o.hide_render=True;o.hide_set(True);o['replaced_by_lab_detail']=True
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    return report()


def report():
    import bpy
    rows=[]
    for name in NAMES:
        o=bpy.data.objects[name]
        digest=hashlib.sha256(b''.join(struct.pack('<3f',*v.co) for v in o.data.vertices)).hexdigest()
        rows.append({'name':name,'vertices':len(o.data.vertices),'materials':len(o.data.materials),'sha256':digest,'dimensions':list(o.dimensions)})
    return {'saved_file':bpy.data.filepath,'meshes':rows,'hidden_originals':sum(1 for o in bpy.data.objects if original(o) and o.hide_render)}


if __name__=='__main__':
    print(make_labels())
