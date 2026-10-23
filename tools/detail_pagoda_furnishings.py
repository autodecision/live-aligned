"""Original bonsai and cabinet joinery, used by furnish_pagoda through Blender MCP."""
import math
import random


def make_wood_texture(path):
    from PIL import Image, ImageFilter
    rng = random.Random(771)
    noise = Image.new('L', (512, 512))
    noise.putdata([rng.randrange(256) for _ in range(512*512)])
    broad = list(noise.filter(ImageFilter.GaussianBlur(9)).getdata())
    fine = list(noise.filter(ImageFilter.GaussianBlur(1.2)).getdata())
    pixels = []
    for y in range(512):
        for x in range(512):
            bend = 5*math.sin(y*.013) + 2*math.sin(y*.039+x*.009)
            # Uneven fine fibers and quiet, wandering growth rings.
            phase = (x+bend)*.12 + .38*math.sin(x*.031+y*.008)
            ring = math.sin(phase) + .28*math.sin(phase*2.13+.6)
            fiber = math.sin(x*1.43 + .7*math.sin(y*.021))
            d = ring*3.8 + fiber*.7 + (broad[y*512+x]-128)*.55 + (fine[y*512+x]-128)*.12
            pixels.append(tuple(max(0,min(255,round(c+d*k))) for c,k in [(116,1),(74,.8),(43,.55)]))
    image = Image.new('RGB', (512, 512)); image.putdata(pixels); image.save(path)
    inset = Image.new('RGB', (512, 512))
    inset.putdata([tuple(round(c*.82) for c in rgb) for rgb in pixels])
    inset.save(path.with_name('pagoda_walnut_inset.png'))
    bark = Image.new('RGB', (256, 256)); pixels=[]
    for y in range(256):
        for x in range(256):
            ridge=math.sin(x*.42+math.sin(y*.031)*1.6)
            grain=math.sin(x*1.8+math.sin(y*.09))
            d=8*ridge+3*grain+rng.uniform(-4,4)
            pixels.append(tuple(round(c+d*k) for c,k in [(83,1),(60,.8),(36,.6)]))
    bark.putdata(pixels); bark.save(path.with_name('pagoda_bonsai_bark.png'))


def wood_uv(mesh, coordinates):
    """Align grain with each board, before the pagoda's world transform is baked."""
    from mathutils import Vector
    spans = [max(v[i] for v in coordinates)-min(v[i] for v in coordinates) for i in range(3)]
    uv = mesh.uv_layers.active
    for face in mesh.polygons:
        a,b,c = [Vector(coordinates[i]) for i in list(face.vertices)[:3]]
        normal = (b-a).cross(c-a)
        axis = max(range(3), key=lambda i:abs(normal[i]))
        across,along = sorted([i for i in range(3) if i!=axis], key=lambda i:spans[i])
        for li in face.loop_indices:
            v = coordinates[mesh.loops[li].vertex_index]
            uv.data[li].uv = (v[across]*1.4, v[along]*.65)


def cabinet(m,x,y,z,w,d,h,name,wood,dark,bronze,panel):
    sign = 1 if y>0 else -1
    front = y-sign*d/2
    # Short feet, stepped plinth, inset carcass, overhanging cap and shelf edging.
    for dx in [-w/2+.065,w/2-.065]:
        for dy in [-d/2+.065,d/2-.065]:
            m.box('cabinet shaped foot',(x+dx,y+dy,z+.065),(.105,.105,.13),wood,.018)
    m.box('cabinet bottom plinth',(x,y,z+.135),(w,d,.09),wood,.014)
    m.box('plinth shadow bead',(x,y,z+.19),(w-.035,d-.025,.022),dark,.004)
    m.box(name+' inset back',(x,y+sign*(d/2-.031),z+(h+.18)/2),(w-.10,.038,h-.22),panel,.004)
    for side in [-1,1]:
        xx=x+side*(w/2-.028)
        m.box('recessed side panel',(xx,y,z+(h+.18)/2),(.032,d-.09,h-.26),panel,.006)
        for dy in [-d/2+.038,d/2-.038]:
            m.box('side panel vertical stile',(xx,y+dy,z+(h+.18)/2),(.056,.065,h-.18),wood,.007)
        for dz in [.21,h-.08]:
            m.box('side panel cross rail',(xx,y,z+dz),(.056,d-.07,.075),wood,.008)
    for dz in [h*.5,h-.047]:
        m.box('cabinet shelf',(x,y,z+dz),(w-.035,d-.025,.065),wood,.007)
        m.box('shelf nosing',(x,front,z+dz-.006),(w-.04,.033,.047),wood,.007)
    m.box('cabinet crown cap',(x,y,z+h-.016),(w,d,.032),wood,.009)
    m.box('crown bead',(x,y,z+h-.067),(w-.015,d-.015,.018),bronze,.003)
    # Each lower door has a sunken field, four raised rails, and an inner bead.
    door_h = h*.5-.24
    door_w = (w-.185)/2
    center_z = z+.21+door_h/2
    door_y = front-sign*.005
    # A closed lower carcass and wooden meeting stile block views through the
    # door reveal. Stored paper must never become the visible cabinet seam.
    m.box('closed lower cabinet lining',(x,door_y+sign*.055,center_z),
          (w-.12,.045,door_h+.035),dark,.003)
    m.box('door meeting stile',(x,door_y+sign*.012,center_z),
          (.034,.035,door_h+.015),wood,.004)
    for dx in [-(door_w+.016)/2,(door_w+.016)/2]:
        cx = x+dx
        m.box('recessed door field',(cx,door_y+sign*.012,center_z),(door_w-.07,.026,door_h-.07),panel,.008)
        for sx in [-1,1]:
            m.box('door vertical stile',(cx+sx*(door_w/2-.025),door_y,center_z),(.05,.034,door_h),wood,.006)
        for sz in [-1,1]:
            m.box('door horizontal rail',(cx,door_y,center_z+sz*(door_h/2-.025)),(door_w-.08,.034,.05),wood,.006)
        for sx in [-1,1]:
            m.box('inner door bead',(cx+sx*(door_w/2-.058),door_y-sign*.003,center_z),(.012,.018,door_h-.10),wood,.003)
        # Real vertical ring pulls hang from small escutcheons.
        px = cx + (.13 if dx<0 else -.13)
        py = door_y-sign*.027
        pz = center_z+.035
        m.box('brass escutcheon',(px,py,pz),(.046,.012,.066),bronze,.011)
        ring = [(px+.025*math.cos(a),py-sign*.012,pz-.027+.029*math.sin(a)) for a in [math.tau*i/20 for i in range(20)]]
        m.tube('hanging brass ring',ring,.0045,bronze,6,True)
        for dz in [-door_h*.28,door_h*.28]:
            hx = cx+(-1 if dx<0 else 1)*(door_w/2-.025)
            m.box('aged brass hinge',(hx,py+sign*.009,center_z+dz),(.027,.012,.042),bronze,.003)
    # A narrow decorative lattice at the back is visible around the books.
    for dx in [-w*.31,0,w*.31]:
        m.box('open shelf back mullion',(x+dx,y+sign*(d/2-.052),z+h*.75),(.018,.025,h*.40),wood,.003)


def bonsai(m,x,y,z,variant,jade,dark,bark,leaf_mats,moss,stone):
    from mathutils import Vector
    rng = random.Random(937+variant*193)
    # Closed shallow glazed pot with a lip, foot ring, soil, moss and gravel.
    m.lathe('bonsai glazed planter',(x,y,z),[(.19,0),(.20,.025),(.255,.04),(.285,.15),(.30,.17),(.30,.19),(.267,.192),(.25,.16),(.23,.06)],jade,48)
    m.lathe('planter foot ring',(x,y,z),[(.16,0),(.17,.015),(.17,.028)],jade,40)
    m.lathe('textured soil',(x,y,z+.151),[(.252,0),(.248,.012)],dark,40)
    soil_vs=[];soil_fs=[]
    for _ in range(36):
        angle=rng.uniform(0,math.tau);r=.23*math.sqrt(rng.random())
        cx=x+r*math.cos(angle);cy=y+r*math.sin(angle);rr=rng.uniform(.006,.017)
        start=len(soil_vs)
        soil_vs += [(cx-rr,cy,z+.164),(cx,cy-rr,z+.165),(cx+rr,cy,z+.166),(cx,cy+rr,z+.164),(cx,cy,z+.176)]
        soil_fs += [(start+i,start+(i+1)%4,start+4) for i in range(4)]
    m.mesh('planter gravel',soil_vs,soil_fs,stone)
    for dx,dy,r in [(-.12,.08,.066),(.12,.04,.052),(-.035,-.13,.049)]:
        m.lathe('moss hummock',(x+dx,y+dy,z+.163),[(r,0),(r*.75,.018),(.004,.025)],moss,16)

    def smooth_path(points,radii):
        # Catmull-Rom interpolation keeps the trunk and branch bends organic.
        if len(points)>2:
            original=[Vector(p) for p in points]; dense=[]; sizes=[]
            for j in range(len(original)-1):
                p0=original[max(0,j-1)];p1=original[j];p2=original[j+1];p3=original[min(len(original)-1,j+2)]
                for k in range(4):
                    t=k/4
                    dense.append(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t))
                    sizes.append(radii[j]*(1-t)+radii[j+1]*t)
            points=dense+[original[-1]];radii=sizes+[radii[-1]]
        return [Vector(p) for p in points],radii

    def tapered(points,radii,name):
        points,radii=smooth_path(points,radii)
        vs=[];fs=[];n=10
        for j,p in enumerate(points):
            tangent=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
            a=tangent.cross(Vector((0,1,0))).normalized();b=tangent.cross(a).normalized()
            for k in range(n):
                angle=math.tau*k/n
                radius=radii[j]*(1+.09*math.sin(k*2.1+j*.5))
                vs.append(p+radius*(a*math.cos(angle)+b*math.sin(angle)))
        for j in range(len(points)-1):
            for k in range(n):
                a=j*n+k;bb=j*n+(k+1)%n;fs.append((a,bb,bb+n,a+n))
        fs += [tuple(reversed(range(n))),tuple((len(points)-1)*n+k for k in range(n))]
        obj=m.mesh(name,vs,fs,bark,True)
        uv=obj.data.uv_layers.active
        for face in obj.data.polygons:
            for li in face.loop_indices:
                vi=obj.data.loops[li].vertex_index
                uv.data[li].uv=((vi%n)/n*2,(vi//n)/(len(points)-1)*1.7)
        return points

    twist = variant*.57
    def point(dx,dy,dz):
        return (x+dx*math.cos(twist)-dy*math.sin(twist),y+dx*math.sin(twist)+dy*math.cos(twist),z+dz)
    trunk=[point(0,0,.16),point(-.045,-.008,.29),point(-.065,.008,.41),point(-.02,.025,.54),point(.065,.018,.69),point(.074,.03,.82),point(.02,.02,.99)]
    trunk_curve=tapered(trunk,[.052,.044,.037,.031,.025,.017,.005],'gnarled tapered trunk')
    def trunk_at(height):
        target=z+height
        for a,b in zip(trunk_curve,trunk_curve[1:]):
            if a.z<=target<=b.z:
                return a.lerp(b,(target-a.z)/(b.z-a.z))
        raise ValueError('Branch attachment outside trunk')
    for j in range(6):
        a=j*math.tau/6+.25
        tapered([point(.11*math.cos(a),.11*math.sin(a),.165),point(.055*math.cos(a),.055*math.sin(a),.18),trunk_at(.27)],[.009,.015,.023],'exposed buttress root')

    leaves=[([],[]) for _ in leaf_mats]
    def leaf(base,angle,tilt,length,mat_index):
        along=Vector((math.cos(angle)*math.cos(tilt),math.sin(angle)*math.cos(tilt),math.sin(tilt)))
        across=Vector((-math.sin(angle),math.cos(angle),0));up=along.cross(across).normalized()
        base=Vector(base);width=length*.35
        ring=[base,base+along*length*.37-across*width,base+along*length*.72-across*width*.66,base+along*length,base+along*length*.72+across*width*.66,base+along*length*.37+across*width]
        ridge=base+along*length*.5+up*length*.09
        underside=base+along*length*.5-up*.0015
        vs,fs=leaves[mat_index];start=len(vs);vs.extend(ring+[ridge,underside])
        for i in range(6):
            fs += [(start+i,start+(i+1)%6,start+6),(start+(i+1)%6,start+i,start+7)]

    # Six asymmetrical branch fans, each carrying four twig sprays of small leaves.
    for j in range(6):
        a=j*2.39+.4;dz=.46+j*.083;reach=.27 if j<4 else .18
        root=trunk_at(dz-.06)
        elbow=point(math.cos(a)*reach*.55,math.sin(a)*reach*.55,dz)
        end=point(math.cos(a)*reach,math.sin(a)*reach,dz+.045)
        tapered([root,elbow,end],[.020-j*.0018,.012,.004],'tapered primary branch')
        for k in range(4):
            b=a+(k-1.5)*.55
            tip=point(math.cos(a)*reach+math.cos(b)*.11,math.sin(a)*reach+math.sin(b)*.11,dz+.055+rng.uniform(0,.045))
            tapered([elbow,end,tip],[.007,.004,.0018],'fine twig spray')
            for n in range(44):
                phi=rng.uniform(0,math.tau);r=.094*math.sqrt(rng.random())
                base=Vector(tip)+Vector((r*math.cos(phi),r*math.sin(phi),rng.uniform(-.037,.047)))
                leaf(base,phi+rng.uniform(-.5,.5),rng.uniform(-.32,.62),rng.uniform(.036,.061),rng.choices(range(len(leaf_mats)),[4,3,2,1])[0])
    for index,(vs,fs) in enumerate(leaves):m.mesh('individual ridged bonsai leaves',vs,fs,leaf_mats[index],True)
