"""Original south-island koi pond and karesansui garden, with scoped terrain export.

Run build_and_export() in the optimized editable map, then install_saved() in the
artistic map. Neither the base map GLB nor the northern island is rebuilt.
"""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
from mathutils import noise

PROJECT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
COLLECTION='South Koi and Zen Garden'
POND=(96.,-34.,5.6,4.)
LEVEL=4.65
WATER=4.42
ZEN=(111.47,-34.0,9.6,10.4)
ROCKS=[(109.47,-31.6,.77),(113.47,-36.3,1.05),(110.67,-37.0,.55)]
ROUTES=[
 [(79.25,-21.50,5.55),(80.60,-21.50,5.55),(84.20,-22.65,5.25),(88.00,-24.50,4.78),(88.00,-26.50,4.72)],
 [(87.00,-18.75,4.10),(87.30,-19.80,4.18),(87.90,-22.50,4.55),(88.00,-26.50,4.72)],
 [(88.,-26.5,4.72),(104.375,-26.5,4.72),(118.5,-26.5,4.72),(118.5,-41.5,4.72),(104.375,-41.5,4.72),(88.,-41.5,4.72),(88.,-34.,4.72),(88.,-26.5,4.72)],
 [(104.375,-26.5,4.72),(104.375,-41.5,4.72)],
]
PLAN={}
COL=None
M={}
BATCH={}
COLLIDERS=[]


def smooth(a,b,x):
    t=max(0.,min(1.,(x-a)/(b-a)));return t*t*(3-2*t)


def rect_distance(x,y,b):
    return math.hypot(max(b[0]-x,0.,x-b[1]),max(b[2]-y,0.,y-b[3]))


def nearest(x,y,route):
    best=(1e6,0.,0.)
    for a,b in zip(route,route[1:]):
        dx,dy=b[0]-a[0],b[1]-a[1];den=dx*dx+dy*dy
        t=max(0.,min(1.,((x-a[0])*dx+(y-a[1])*dy)/max(den,1e-6)))
        d=math.hypot(x-a[0]-t*dx,y-a[1]-t*dy)
        if d<best[0]:best=(d,a[2]+t*(b[2]-a[2]),t)
    return best


def pond_radius(x,y):
    return math.hypot((x-POND[0])/POND[2],(y-POND[1])/POND[3])


def pond_edge(a):
    return 1.+.035*math.sin(3*a+.5)+.022*math.sin(5*a-1.)


def garden_clear(x,y,margin=.7):
    if pond_radius(x,y)<1.14+margin/4.:return True
    if rect_distance(x,y,(106.35,116.55,-39.5,-28.5))<margin:return True
    if any(nearest(x,y,r)[0]<.9+margin for r in ROUTES):return True
    if rect_distance(x,y,(89.1,92.5,-35.1,-31.9))<margin:return True
    if rect_distance(x,y,(119.1,120.5,-35.5,-32.5))<margin:return True
    if rect_distance(x,y,(92.6,95.4,-44.,-43.2))<margin:return True
    if any(math.hypot(x-a,y-b)<.65+margin for a,b in [(90.2,-30.1),(116.0,-25.2),(116.0,-42.8),(104.41,-42.8),(89.8,-43.5)]):return True
    return False


def material(name,color,rough=.8,metal=0.):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    M[name]=m;return m


def addmesh(name,verts,faces,mat,color=None,collection=None):
    me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update()
    obj=bpy.data.objects.new(name,me);(collection or COL).objects.link(obj)
    me.materials.append(M[mat] if isinstance(mat,str) else mat)
    uv=me.uv_layers.new(name='UVMap')
    for polygon in me.polygons:
        for li in polygon.loop_indices:
            p=me.vertices[me.loops[li].vertex_index].co;uv.data[li].uv=(p.x*.2,p.y*.2)
    if color:
        attr=me.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
        for data,c in zip(attr.data,color):data.color=(*c,1)
    return obj


def batch(mat,verts,faces):
    v,f=BATCH.setdefault(mat,([],[]));offset=len(v);v.extend(tuple(p) for p in verts)
    f.extend(tuple(offset+i for i in face) for face in faces)


def box(mat,center,size,yaw=0.,collision=False):
    cx,cy,cz=center;sx,sy,sz=[q/2 for q in size];c,s=math.cos(yaw),math.sin(yaw)
    verts=[(cx+c*sx*x-s*sy*y,cy+s*sx*x+c*sy*y,cz+sz*z) for x,y,z in
           [(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),(-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]]
    batch(mat,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)])
    if collision:COLLIDERS.append({'type':'box','center':list(center),'size':list(size),'yaw':yaw})


def ellipsoid(mat,center,size,seed=0,segments=12,rings=7,irregular=.12):
    rng=random.Random(seed);cx,cy,cz=center;sx,sy,sz=size;verts=[]
    factors=[1+rng.uniform(-irregular,irregular) for j in range(segments)]
    for i in range(rings+1):
        phi=math.pi*i/rings
        for j in range(segments):
            a=j*math.tau/segments;f=factors[j]*(1+.04*math.sin(i*2.1+j))
            verts.append((cx+sx*math.sin(phi)*math.cos(a)*f,cy+sy*math.sin(phi)*math.sin(a)*f,cz+sz*math.cos(phi)*(1+.025*math.sin(j*2))))
    faces=[]
    for i in range(rings):
        for j in range(segments):
            a=i*segments+j;b=i*segments+(j+1)%segments;faces.append((a,a+segments,b+segments,b))
    batch(mat,verts,faces)


def strip(mat,points,width,thickness=.06):
    for a,b in zip(points,points[1:]):
        a,b=Vector(a),Vector(b);d=b-a;mid=(a+b)/2
        box(mat,mid,(d.xy.length+.04,width,thickness),math.atan2(d.y,d.x))


def cylinder(mat,a,b,radius,sides=10):
    a,b=Vector(a),Vector(b);direction=(b-a).normalized();u=direction.cross(Vector((0,0,1)))
    if u.length<.01:u=Vector((1,0,0))
    u.normalize();v=direction.cross(u);verts=[]
    for p in [a,b]:
        for j in range(sides):
            angle=j*math.tau/sides;verts.append(p+radius*(u*math.cos(angle)+v*math.sin(angle)))
    faces=[tuple(reversed(range(sides))),tuple(range(sides,sides*2))]
    faces.extend((j,(j+1)%sides,(j+1)%sides+sides,j+sides) for j in range(sides));batch(mat,verts,faces)


def height_bvh(obj):
    return BVHTree.FromPolygons([obj.matrix_world@v.co for v in obj.data.vertices],[tuple(p.vertices) for p in obj.data.polygons])


def restore_banks():
    banks_blend = OUT / 'bridge_landing_banks.blend'
    if banks_blend.exists():
        wanted_names = ['Landing_Bank_Main_South', 'Landing_Bank_North_South']
        with bpy.data.libraries.load(str(banks_blend), link=False) as (src, dst):
            dst.objects = list(wanted_names)
        for target_name, src_obj in zip(wanted_names, dst.objects):
            if src_obj and target_name in bpy.data.objects:
                target = bpy.data.objects[target_name]
                target.data = src_obj.data.copy()
                bpy.data.objects.remove(src_obj, do_unlink=True)


def create_terrain(ground):
    terrains = [height_bvh(bpy.data.objects[n]) for n in ['Distant_Islands-col', 'Landing_Bank_Main_South', 'Landing_Bank_North_South'] if n in bpy.data.objects]
    bank_bvhs = [height_bvh(bpy.data.objects[n]) for n in ['Landing_Bank_Main_South', 'Landing_Bank_North_South'] if n in bpy.data.objects]
    def original(x,y):
        hits = [t.ray_cast(Vector((x,y,40)),Vector((0,0,-1)))[0] for t in terrains]
        heights = [p.z for p in hits if p is not None]
        return max(heights) if heights else -11.
    def height(x,y):
        cx, cy = 103.5, -34.0
        rx, ry = 29.0, 21.0
        a = math.atan2((y - cy) / ry, (x - cx) / rx)
        mod = 1.0 + 0.05 * math.sin(3 * a + 0.4) + 0.035 * math.sin(5 * a - 0.8) + 0.02 * math.cos(7 * a)
        r = math.hypot((x - cx) / rx, (y - cy) / ry) / mod
        SEA_LEVEL = -5.0
        if r <= 0.60:
            h = LEVEL
        elif r <= 1.00:
            t = (r - 0.60) / 0.40
            h = LEVEL - (LEVEL - SEA_LEVEL) * smooth(0.0, 1.0, t)
        else:
            h = SEA_LEVEL - 6.0 * smooth(1.00, 1.20, r)
        h = max(original(x, y), h)
        # Each bridge retains its own threshold height and a continuous grade.
        route_hits=[(*nearest(x,y,r)[:2],1-smooth(1.20,3.55,nearest(x,y,r)[0])) for r in ROUTES]
        active=[hit for hit in route_hits if hit[2]>0]
        if active:
            total_w=sum(hit[2]**2 for hit in active)
            blended_z=sum((hit[2]**2)*hit[1] for hit in active)/total_w
            max_inf=max(hit[2] for hit in active)
            h=h*(1-max_inf)+(blended_z-.07)*max_inf
        # The bowl is genuinely excavated into the terrain, with a shallow exit.
        pr=pond_radius(x,y)/pond_edge(math.atan2((y-POND[1])/POND[3],(x-POND[0])/POND[2]))
        if pr<1.04:
            bowl=3.00+(LEVEL-.10-3.00)*smooth(.77,1.04,pr)
            h=min(h,bowl)
        if y > -20.5 and x > 84.0 and x < 92.0:
            bank_hits = [b.ray_cast(Vector((x,y,40)),Vector((0,0,-1)))[0] for b in bank_bvhs]
            bank_z = [p.z for p in bank_hits if p is not None]
            if bank_z:
                h = min(h, min(bank_z) - 0.18)
        return h
    # Preserve every northern vertex and face; replace the disconnected south mesh.
    oldverts=[ground.matrix_world@v.co for v in ground.data.vertices]
    keep=[tuple(p.vertices) for p in ground.data.polygons if not all(oldverts[i].y<0. for i in p.vertices)]
    used=sorted({i for f in keep for i in f});remap={i:j for j,i in enumerate(used)}
    verts=[oldverts[i] for i in used];faces=[tuple(remap[i] for i in f) for f in keep]
    north_count=len(verts)
    step=.5;nx,ny=132,108;offset=len(verts)
    for j in range(ny+1):
        y=-61+j*step
        for i in range(nx+1):
            x=70+i*step;verts.append((x,y,height(x,y)))
    for j in range(ny):
        for i in range(nx):
            a=offset+j*(nx+1)+i;faces.extend([(a,a+1,a+nx+2),(a,a+nx+2,a+nx+1)])
    oldmat=list(ground.data.materials)
    fitted=bpy.data.meshes.new('Distant islands with expanded south garden');fitted.from_pydata(verts,[],faces);fitted.update()
    for mat in oldmat:fitted.materials.append(mat)
    for p in fitted.polygons:p.use_smooth=True
    ground.data=fitted
    return height,{'preserved_northern_vertices':north_count,'south_grid_vertices':(nx+1)*(ny+1),'south_grid_step_m':step}


def arrival_path_field(x,y):
    # Tightened two-branch arrival joining the square 2m sidewalk at (87..89, -25.5) with straight outer edges.
    polygon=[(79.25,-19.40),(85.507,-20.934),(84.981,-19.328),(89.019,-18.172),
             (89.00,-25.50),(89.00,-27.50),(87.00,-27.50),(87.00,-25.50),
             (79.25,-23.60)]
    inside=False
    for a,b in zip(polygon,polygon[1:]+polygon[:1]):
        if (a[1]>y)!=(b[1]>y) and x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0]:inside=not inside
    edge=min(nearest(x,y,[(*a,0),(*b,0)])[0] for a,b in zip(polygon,polygon[1:]+polygon[:1]))
    val=edge if inside else -edge
    if x<79.25:val=min(val,x-79.25)
    if x>84.5:
        ns_dot=(x-87.0)*0.275+(y-(-18.75))*(-0.96)
        if ns_dot<0:val=min(val,ns_dot)
    return val


def path_field(x,y):
    # Axis-aligned union with grid-aligned corners: no rounded route end caps.
    rectangles=[(87.,89.,-42.5,-25.5),(117.5,119.5,-42.5,-25.5),
                (87.,119.5,-27.5,-25.5),(87.,119.5,-42.5,-40.5),
                (103.375,105.375,-42.5,-25.5)]
    field=max(min(x-a,b-x,y-c,d-y) for a,b,c,d in rectangles)
    # Preserve the two fitted bridge thresholds and their established grades.
    return max(field,arrival_path_field(x,y))


def build_paths(height):
    # A grid aligned to the terrain's own triangulation never bridges a soil ridge.
    # Clip triangles to the union boundary; shared vertices remove overlap seams.
    step=.125;verts=[];faces=[];lookup={};grid={}
    def sample(i,j):
        if (i,j) not in grid:
            x,y=i*step,j*step;grid[i,j]=(x,y,path_field(x,y))
        return grid[i,j]
    def vertex(p):
        key=(round(p[0],7),round(p[1],7))
        if key not in lookup:
            lookup[key]=len(verts);verts.append((p[0],p[1],height(*p[:2])+.085))
        return lookup[key]
    for j in range(-356,-140):
        for i in range(624,972):
            a,b,c,d=sample(i,j),sample(i+1,j),sample(i+1,j+1),sample(i,j+1)
            if c[1]<=-25.5:
                # Whole grid cells preserve exact right angles at concave joins.
                if path_field((a[0]+c[0])*.5,(a[1]+c[1])*.5)>0:
                    ids=[vertex(p) for p in [a,b,c,d]]
                    faces.extend([(ids[0],ids[1],ids[2]),(ids[0],ids[2],ids[3])])
                continue
            for tri in [(a,b,c),(a,c,d)]:
                if max(p[2] for p in tri)<0:continue
                poly=[]
                for p,q in zip(tri,tri[1:]+tri[:1]):
                    if p[2]>=0:poly.append(p)
                    if (p[2]>=0)!=(q[2]>=0):
                        t=p[2]/(p[2]-q[2]);poly.append((p[0]+t*(q[0]-p[0]),p[1]+t*(q[1]-p[1]),0))
                ids=[vertex(p) for p in poly]
                for k in range(1,len(ids)-1):
                    f=(ids[0],ids[k],ids[k+1])
                    if len(set(f))==3:faces.append(f)
    # Fill the small valleys caused by competing bridge grades, while staying
    # above every terrain/bank sample. This produces a smooth continuous ramp.
    adjacency=[set() for v in verts];edge_count={}
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            adjacency[a].add(b);adjacency[b].add(a)
            key=tuple(sorted((a,b)))
            edge_count[key]=edge_count.get(key,0)+1
    original=[p[2] for p in verts];zs=original[:]
    for iteration in range(400):
        next_z=[]
        for i,neighbors in enumerate(adjacency):
            average=sum(zs[j] for j in neighbors)/len(neighbors) if neighbors else zs[i]
            next_z.append(max(original[i],min(original[i]+.45,zs[i]*.35+average*.65)))
        zs=next_z
    for i, p in enumerate(verts):
        x, y = p[0], p[1]
        if x > 84.5:
            ns_dot = (x - 87.0)*0.275 + (y - (-18.75))*(-0.96)
            if ns_dot < 0.40:
                t_ns = max(0.0, min(1.0, ns_dot / 0.40))
                zs[i] = 4.10 * (1 - t_ns) + zs[i] * t_ns
        if x < 79.65:
            t_ms = max(0.0, min(1.0, (x - 79.25) / 0.40))
            zs[i] = 5.55 * (1 - t_ms) + zs[i] * t_ms
    verts=[(p[0],p[1],zs[i]) for i,p in enumerate(verts)]
    # Finish the paving edge down into the soil instead of leaving a floating sheet.
    top_faces=list(faces)
    for face in top_faces:
        for a,b in zip(face,face[1:]+face[:1]):
            if edge_count[tuple(sorted((a,b)))]!=1:continue
            xa, ya, _ = verts[a]; xb, yb, _ = verts[b]
            if max(xa, xb) <= 79.26: continue
            if max(xa, xb) > 84.5:
                ns_a = (xa - 87.0)*0.275 + (ya - (-18.75))*(-0.96)
                ns_b = (xb - 87.0)*0.275 + (yb - (-18.75))*(-0.96)
                if max(ns_a, ns_b) <= 0.02: continue
            bottom=[]
            for index in [a,b]:
                x,y,z=verts[index];bottom.append(len(verts));verts.append((x,y,height(x,y)-.025))
            faces.append((a,b,bottom[1],bottom[0]))
    batch('Garden_Gravel',verts,faces)
    COLLIDERS.append({'type':'mesh','name':'SouthGarden_Gravel'})


def build_coping(height):
    cx,cy,rx,ry=POND;rng=random.Random(51015);count=52
    for i in range(count):
        mid=(i+.5)*math.tau/count
        a0=i*math.tau/count+.0025;a1=(i+1)*math.tau/count-.0025
        # Trim the rim to the deck opening, including a little air around its edges.
        x,y=cx+rx*1.055*pond_edge(mid)*math.cos(mid),cy+ry*1.055*pond_edge(mid)*math.sin(mid)
        if x<92.5 and -34.49<y<-31.85:continue
        exit_distance=min(abs((mid-a+math.pi)%math.tau-math.pi) for a in [0.,math.pi/2,2.4,math.pi*1.5])
        low=exit_distance<.18
        top=LEVEL+(.04 if low else rng.uniform(.16,.23))
        verts=[]
        # Beveled irregular wedge follows the shoreline; no overlapping ellipsoids.
        outline=[(a0,1.006),(a0+.012,.985),(a1-.012,.985),(a1,1.006),(a1,1.11),(a1-.012,1.128),(a0+.012,1.128),(a0,1.11)]
        xy=[(cx+rx*r*pond_edge(a)*math.cos(a),cy+ry*r*pond_edge(a)*math.sin(a)) for a,r in outline]
        if min(p[0] for p in xy)<92.40 and max(p[0] for p in xy)>89.1 and min(p[1] for p in xy)<-31.86 and max(p[1] for p in xy)>-34.50:continue
        for ring in range(3):
            for a,r in outline:
                r=r*pond_edge(a)
                px,py=cx+rx*r*math.cos(a),cy+ry*r*math.sin(a)
                if ring==2:
                    px=x+(px-x)*.93;py=y+(py-y)*.93
                z=LEVEL-.075 if ring==0 else (top-.05 if ring==1 else top+.012*math.sin(a*57+i))
                verts.append((px,py,z))
        faces=[tuple(reversed(range(8))),tuple(range(16,24))]
        faces.extend((k*8+j,k*8+(j+1)%8,(k+1)*8+(j+1)%8,(k+1)*8+j) for k in range(2) for j in range(8))
        batch('Garden_Edge_Stone',verts,[tuple(reversed(f)) for f in faces])
        if not low:
            tangent=math.atan2(ry*math.cos(mid),-rx*math.sin(mid))
            length=math.hypot(rx*math.sin(mid),ry*math.cos(mid))*(a1-a0)
            COLLIDERS.append({'type':'box','center':[x,y,(top+LEVEL-.05)/2],'size':[length*.95,.48,top-LEVEL+.05],'yaw':tangent})


def build_rock(x,y,size,index):
    # Detailed faceted planar cleavage plus multi-octave surface displacements.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=4,radius=1)
    temp=bpy.context.object;verts=[]
    forms=[(.92,.74,1.15),(.82,.66,1.24),(1.06,.72,.82)]
    sx,sy,sz=forms[index]
    for vertex in temp.data.vertices:
        q=vertex.co.copy();p=q+Vector((index*7.1,2.3,4.7))
        n1=noise.noise_vector(p*2.4).x*.14
        n2=noise.noise_vector(p*7.8).y*.045
        n3=noise.noise_vector(p*21.5).z*.018
        q*=1.0+n1+n2+n3
        q.x=min(q.x,.76+.22*q.z);q.y=max(q.y,-.78+.18*q.x)
        q.z=min(q.z,.82+.28*q.x-.14*q.y)
        if q.x>.45 and q.z>.25:q.x-=.12*(q.z-.25)
        if q.y<-.35 and q.z>.1:q.y+=.10*(q.z-.1)
        if q.z>.65:q.z=.65+(q.z-.65)*.45
        q.x+=.12*q.z
        verts.append((x+q.x*sx*size,y+q.y*sy*size,LEVEL+size*.39+q.z*sz*size))
    faces=[tuple(p.vertices) for p in temp.data.polygons]
    batch('Garden_Contemplation_Rock',verts,faces)
    bpy.data.objects.remove(temp,do_unlink=True)


def build_moss(x,y,size,index):
    # A thin ragged ground mat with a soft mound, mostly tucked beneath the rock.
    verts=[(x,y,LEVEL+.078)];n=56
    for j in range(n):
        a=j*math.tau/n;r=1+.07*math.sin(7*a+index)+.04*math.sin(13*a)
        verts.append((x+math.cos(a)*size*1.05*r,y+math.sin(a)*size*.87*r,LEVEL+.071+.006*math.sin(3*a)**2))
    batch('Garden_Moss',verts,[(0,j+1,(j+1)%n+1) for j in range(n)])


def build_static(height):
    # Contained water, gently sloped lined bowl, and a grounded irregular coping.
    cx,cy,rx,ry=POND;segments=128
    verts=[(cx,cy,WATER)]
    for i in range(segments):
        a=i*math.tau/segments;r=pond_edge(a)*.958
        verts.append((cx+rx*r*math.cos(a),cy+ry*r*math.sin(a),WATER))
    addmesh('SouthGarden_Pond_Water',verts,[(0,i+1,(i+1)%segments+1) for i in range(segments)],'Garden_Water')
    rings=[(.001,3.30),(.55,3.31),(.77,3.34),(.96,4.30),(1.045,LEVEL+.035)]
    verts=[]
    for radius,z in rings:
        for i in range(segments):
            a=i*math.tau/segments;r=radius*pond_edge(a)
            x,y=cx+rx*r*math.cos(a),cy+ry*r*math.sin(a)
            z1=max(z,height(x,y)+.10)
            verts.append((x,y,z1))
    faces=[]
    for j in range(len(rings)-1):
        for i in range(segments):
            a=j*segments+i;b=j*segments+(i+1)%segments;faces.append((a,a+segments,b+segments,b))
    center=len(verts);verts.append((cx,cy,3.30))
    faces.extend((center,i,(i+1)%segments) for i in range(segments))
    lining=addmesh('SouthGarden_Pond_Lining',verts,faces,'Garden_Basin')
    COLLIDERS.append({'type':'mesh','name':lining.name})
    build_coping(height)
    build_paths(height)
    # Formal sand bed and an understated stone curb.
    zx,zy,zw,zh=ZEN
    sand=addmesh('SouthGarden_Zen_Sand',[(zx-zw/2,zy-zh/2,LEVEL+.065),(zx+zw/2,zy-zh/2,LEVEL+.065),(zx+zw/2,zy+zh/2,LEVEL+.065),(zx-zw/2,zy+zh/2,LEVEL+.065)],[(0,1,2,3)],'Garden_Sand')
    COLLIDERS.append({'type':'box','center':[zx,zy,LEVEL+.025],'size':[zw,zh,.08],'yaw':0.})
    for x in [zx-zw/2-.08,zx+zw/2+.08]:box('Garden_Dark_Stone',(x,zy,LEVEL+.11),(.16,zh+.32,.22),collision=True)
    for y in [zy-zh/2-.08,zy+zh/2+.08]:box('Garden_Dark_Stone',(zx,y,LEVEL+.11),(zw,.16,.22),collision=True)
    for i,(x,y,size) in enumerate(ROCKS):
        build_rock(x,y,size,i)
        COLLIDERS.append({'type':'box','center':[x,y,LEVEL+size*.45],'size':[size*1.35,size*1.15,size*1.8],'yaw':.2*i})
        build_moss(x,y,size,i)
    # Timber viewing deck and seating, with real supporting beams.
    for j in range(20):box('Garden_Wood',(90.8,-34.3+j*.118,LEVEL+.11),(3.0,.11,.12),collision=True)
    box('Garden_Dark_Stone',(89.8,-33.15,4.45),(.18,2.5,.6))
    box('Garden_Dark_Stone',(91.8,-33.15,3.95),(.18,2.5,1.60))
    for center,yaw in [((119.8,-34.0),math.pi/2),((94.,-43.6),0.)]:
        x,y=center;c,s=math.cos(yaw),math.sin(yaw)
        for off in [-.16,0.,.16]:
            box('Garden_Wood',(x-s*off,y+c*off,LEVEL+.48),(2.25,.145,.10),yaw,True)
        for off in [-.78,.78]:box('Garden_Dark_Stone',(x+c*off,y+s*off,LEVEL+.22),(.24,.40,.44),yaw,True)
    # Original stone lanterns echo the nearby pagoda, with warm contained light.
    lamps=[]
    for x,y in [(90.2,-30.1),(116.0,-25.2),(116.0,-42.8),(104.41,-42.8),(89.8,-43.5)]:
        base=height(x,y);box('Garden_Dark_Stone',(x,y,base),(.58,.58,.48),collision=True)
        box('Garden_Edge_Stone',(x,y,base+.54),(.22,.22,.68),collision=True)
        box('Garden_Dark_Stone',(x,y,base+.91),(.62,.62,.13))
        box('Garden_Lantern_Glow',(x,y,base+1.12),(.34,.34,.32))
        for dx in [-.24,.24]:
            for dy in [-.24,.24]:box('Garden_Dark_Stone',(x+dx,y+dy,base+1.14),(.08,.08,.42))
        box('Garden_Dark_Stone',(x,y,base+1.37),(.76,.76,.14))
        ellipsoid('Garden_Dark_Stone',(x,y,base+1.50),(.16,.16,.14),segments=8,rings=4,irregular=0.)
        lamps.append([x,base+1.16,-y])
    # Reeds and low planting soften the pond edge without concealing the fish.
    rng=random.Random(181)
    for k,(x,y) in enumerate([(91.8,-35.0),(96.0,-37.8),(100.5,-32.8),(94.5,-29.8)]):
        z=4.17
        # Plant roots in the wet shelf, inside the coping rather than through it.
        x=cx+(x-cx)*.86;y=cy+(y-cy)*.86
        for j in range(19):
            angle=rng.random()*math.tau;radius=rng.random()*.28
            a=Vector((x+math.cos(angle)*radius,y+math.sin(angle)*radius,z));h=rng.uniform(.35,.8)
            d=Vector((math.cos(angle),math.sin(angle),0))
            points=[a,a+d*.06+Vector((0,0,h*.55)),a+d*.18+Vector((0,0,h))]
            width=rng.uniform(.018,.035);verts=[]
            for p in points:verts.extend([p+Vector((-d.y,d.x,0))*width/2,p-Vector((-d.y,d.x,0))*width/2])
            batch('Garden_Reed',verts,[(0,1,3,2),(2,3,5,4)])
    for i,(x,y,r) in enumerate([(93.1,-32.,.30),(93.6,-32.2,.24),(93.4,-31.6,.20),(99.2,-35.6,.34),(99.65,-35.75,.24),(98.9,-36.,.22)]):
        verts=[(x,y,WATER+.014)]+[(x+r*math.cos(.15+j*(math.tau-.3)/20),y+r*.82*math.sin(.15+j*(math.tau-.3)/20),WATER+.016+.012*math.sin(j*.5)) for j in range(21)]
        batch('Garden_Lily',verts,[(0,j+1,j+2) for j in range(20)])
        if i in [0,3]:
            for j in range(8):
                a=j*math.tau/8;ellipsoid('Garden_Blossom',(x+math.cos(a)*.065,y+math.sin(a)*.065,WATER+.08),(.075,.04,.035),j,segments=8,rings=4,irregular=0.)
            ellipsoid('Garden_Blossom_Center',(x,y,WATER+.095),(.04,.04,.025),segments=8,rings=4,irregular=0.)
    for mat,(verts,faces) in BATCH.items():
        obj=addmesh('SouthGarden_'+mat.replace('Garden_',''),verts,faces,mat)
        for polygon in obj.data.polygons:polygon.use_smooth=mat not in ['Garden_Wood','Garden_Dark_Stone','Garden_Edge_Stone']
    return lamps


def fish_model(name,variant,collection):
    verts=[];faces=[];colors=[]
    def piece(v,f,color):
        off=len(verts);verts.extend(v);faces.extend(tuple(off+i for i in face) for face in f)
        colors.extend([color]*len(v) if isinstance(color,tuple) else color)
    n=80;sides=28;body=[];bodycolors=[]
    profile=[(-.32,.012,.018),(-.25,.032,.035),(-.15,.062,.054),(0.,.084,.066),(.12,.075,.061),(.23,.054,.049),(.30,.034,.032),(.335,.008,.012)]
    for i in range(n+1):
        x=-.32+.655*i/n
        row=profile[-1]
        for a,b in zip(profile,profile[1:]):
            if a[0]<=x<=b[0]:
                t=(x-a[0])/(b[0]-a[0]);row=(x,a[1]+t*(b[1]-a[1]),a[2]+t*(b[2]-a[2]));break
        for j in range(sides):
            angle=j*math.tau/sides;y=row[1]*math.sin(angle);z=row[2]*math.cos(angle)
            body.append((x,y,z))
            patch=math.sin(x*27+math.sin(angle*2)*1.5)+.55*math.cos(angle*3-x*9)
            base=(.86,.84,.73)
            if variant==2:base=(.92,.59,.14) if patch>-.7 else (.70,.32,.055)
            elif patch>.28 and z>-.02:base=(.85,.15,.025)
            if variant==1 and math.sin(x*42+angle*2)>.7 and math.cos(angle-x*12)>.1:base=(.025,.035,.035)
            # Fine alternating scale rows follow the body's longitudinal topology.
            shade=1.-.055*(.5+.5*math.sin(i*2.7+j*1.9))
            bodycolors.append(tuple(c*shade for c in base))
    f=[]
    for i in range(n):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;f.append((a,a+sides,b+sides,b))
    f.extend([tuple(reversed(range(sides))),tuple(n*sides+j for j in range(sides))]);piece(body,f,bodycolors)
    fin=(.91,.79,.59) if variant!=2 else (.96,.64,.20)
    for side in [-1,1]:
        piece([(.15,side*.055,-.018),(.075,side*.17,-.032),(-.04,side*.14,-.041),(.01,side*.064,-.028)],[(0,1,2),(0,2,3)],fin)
        piece([(-.13,side*.044,-.027),(-.23,side*.105,-.04),(-.265,side*.055,-.044)],[(0,1,2)],fin)
    piece([(-.31,0,-.018),(-.31,0,.018),(-.44,0,.105),(-.41,0,.018),(-.45,0,-.098),(-.375,0,-.035)],[(0,1,2,3),(0,3,4,5)],fin)
    piece([(-.19,0,.045),(-.14,0,.11),(.06,0,.115),(.145,0,.058)],[(0,1,2,3)],fin)
    # Small eyes and gill plates remain legible through clear shallow water.
    for side in [-1,1]:
        center=Vector((.266,side*.035,.029));v=[]
        for i in range(5):
            phi=math.pi*i/4
            for j in range(8):
                a=j*math.tau/8;v.append(center+Vector((.009*math.sin(phi)*math.cos(a),.006*math.sin(phi)*math.sin(a),.009*math.cos(phi))))
        f=[]
        for i in range(4):
            for j in range(8):
                a=i*8+j;b=i*8+(j+1)%8;f.append((a,a+8,b+8,b))
        piece(v,f,(.012,.019,.018))
    obj=addmesh(name,verts,faces,'Garden_Koi',colors,collection)
    for p in obj.data.polygons:p.use_smooth=True
    return obj


def reseat_props(height):
    targets=[(85.6,-34.5),(93.6,-46.5),(82,-25.2),(83.5,-31.),(106.5,-45.5),(122.0,-29.),(80.2,-25.5),(98,-45.5),(110,-45.2),(103,-23.7),(110.5,-23.)]
    rocks=[(85.,-29.5),(83.,-37.5),(103.,-46.5)]
    props=[]
    for obj in list(bpy.context.scene.objects):
        if obj.type!='MESH':continue
        name=obj.name.replace('-convcol','')
        if name.startswith('Island_South_Olive_'):
            index=int(name.rsplit('_',1)[1])-1;obj.location.x,obj.location.y=targets[index]
            bpy.context.view_layer.update()
            points=[obj.matrix_world@v.co for v in obj.data.vertices];bottom=min(p.z for p in points)
            feet=[p for p in points if p.z<bottom+.16];feet=feet[::max(1,len(feet)//96)]
            offset=min(height(p.x,p.y)-p.z for p in feet)-.055;obj.location.z+=offset
        elif name.startswith('Large_Rock_South_'):
            index=int(name.rsplit('_',1)[1])-1;obj.location.x,obj.location.y=rocks[index];bpy.context.view_layer.update()
            points=[obj.matrix_world@v.co for v in obj.data.vertices]
            low=min(p.z for p in points);high=max(p.z for p in points)
            # Bury the broad lower body rather than balancing one low vertex.
            obj.location.z+=height(obj.location.x,obj.location.y)-(low+(high-low)*.43)
        else:continue
        props.append({'name':name,'blender_position':list(obj.location),'position':[obj.location.x,obj.location.z,-obj.location.y]})
    return props


def update_meadow(height):
    path=PROJECT/'assets/gscatter_ground_cover_instances.json';rows=json.loads(path.read_text())
    kept=[];removed=0;reseated=0
    for row in rows:
        x,z,y=row['origin'][0],row['origin'][1],-row['origin'][2]
        if x>69 and y<0:
            if garden_clear(x,y,.8):removed+=1;continue
            row['origin'][1]=height(x,y)-.018;reseated+=1
        kept.append(row)
    rng=random.Random(9015);added=[]
    # Ground the new outer meadow; the conservative mask includes blade footprints.
    for j in range(2600):
        x,y=rng.uniform(82.,126.),rng.uniform(-52.,-22.)
        if garden_clear(x,y,1.0):continue
        h=height(x,y)
        if h<.5 or max(abs(height(x+.35,y)-height(x-.35,y)),abs(height(x,y+.35)-height(x,y-.35)))>.28:continue
        # Avoid trunks, seating and the shoreline rock groups.
        if any(math.hypot(x-p['blender_position'][0],y-p['blender_position'][1])<.75 for p in PLAN['grounded_props']):continue
        a=rng.random()*math.tau;s=rng.uniform(.78,1.08);c,sn=math.cos(a)*s,math.sin(a)*s
        row={'asset':'GScatter_ShortSward_'+str(rng.randrange(3)),'origin':[x,h-.018,-y],
             'basis':[[c,0,sn],[0,s,0],[-sn,0,c]],'blender_rotation':[0,0,a],'blender_scale':[s]*3,'south_garden':True}
        added.append(row)
    kept.extend(added);path.write_text(json.dumps(kept,separators=(',',':')))
    PLAN['grass']={'removed':removed,'reseated':reseated,'added':len(added),'runtime_total':len(kept)}
    return kept


def install_meadow(rows):
    grouped={}
    for row in rows:grouped.setdefault(row['asset']+'_Meadow',[]).append(row)
    changed=0
    for name,batch_rows in grouped.items():
        obj=bpy.data.objects.get(name)
        if obj is None:continue
        world_points=[(r['origin'][0],-r['origin'][2],r['origin'][1]) for r in batch_rows]
        inverse=obj.matrix_world.inverted();points=[inverse@Vector(p) for p in world_points]
        old_lookup={(round((obj.matrix_world@v.co).x,4),round((obj.matrix_world@v.co).y,4)):v.index for v in obj.data.vertices}
        extra=[a for a in obj.data.attributes if a.domain=='POINT' and a.data_type=='FLOAT']
        mesh=bpy.data.meshes.new(name+' updated garden mask');mesh.from_pydata(points,[],[])
        for key,size in [('rotation',3),('scale',3)]:
            attr=mesh.attributes.new(key,'FLOAT_VECTOR','POINT')
            for data,row in zip(attr.data,batch_rows):
                data.vector=row.get('blender_rotation' if 'rotation' in key else 'blender_scale',[0,0,0] if 'rotation' in key else [1,1,1])
        for old in extra:
            attr=mesh.attributes.new(old.name,'FLOAT','POINT')
            for data,point in zip(attr.data,world_points):
                index=old_lookup.get((round(point[0],4),round(point[1],4)))
                data.value=old.data[index].value if index is not None else point[0]
        obj.data=mesh;changed+=1
    return changed


def setup_materials():
    for name,color,rough,metal in [
        ('Garden_Edge_Stone',(.32,.34,.32),.94,0),('Garden_Dark_Stone',(.095,.12,.115),.9,0),
        ('Garden_Basin',(.28,.34,.28),.98,0),('Garden_Sand',(.73,.68,.56),.96,0),
        ('Garden_Gravel',(.41,.40,.34),.96,0),('Garden_Wood',(.24,.13,.065),.8,0),
        ('Garden_Contemplation_Rock',(.19,.23,.23),.95,0),('Garden_Moss',(.18,.26,.10),1.,0),
        ('Garden_Reed',(.14,.29,.10),.85,0),('Garden_Lily',(.11,.28,.13),.68,0),
        ('Garden_Blossom',(.88,.57,.60),.7,0),('Garden_Blossom_Center',(.94,.66,.16),.65,0),
        ('Garden_Lantern_Glow',(.93,.64,.30),.5,0),('Garden_Water',(.12,.30,.28),.13,.1),
        ('Garden_Koi',(1.,1.,1.),.43,0),('Garden_Ground',(.23,.29,.13),.98,0)]:material(name,color,rough,metal)
    p=M['Garden_Lantern_Glow'].node_tree.nodes.get('Principled BSDF');p.inputs['Emission Color'].default_value=(1.,.57,.20,1);p.inputs['Emission Strength'].default_value=.4
    m=M['Garden_Koi'];node=m.node_tree.nodes.new('ShaderNodeVertexColor');node.layer_name='Color';m.node_tree.links.new(node.outputs['Color'],m.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    m=M['Garden_Water'];p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Transmission Weight'].default_value=.45;p.inputs['Alpha'].default_value=.35
    m.surface_render_method='DITHERED'


def build_and_export():
    global COL,PLAN,BATCH,COLLIDERS
    assert Path(bpy.data.filepath)==PROJECT/'assets/mediterranean_temple.blend'
    for cname in [COLLECTION, 'South Garden Koi Library']:
        c = bpy.data.collections.get(cname)
        if c:
            for obj in list(c.objects):bpy.data.objects.remove(obj,do_unlink=True)
            bpy.data.collections.remove(c)
    restore_banks()
    backup_blend = Path('/home/allister/Backups/live-aligned/south-koi-garden-20261015-225134/home/allister/Projects/live-aligned/assets/mediterranean_temple.blend')
    if backup_blend.exists():
        with bpy.data.libraries.load(str(backup_blend), link=False) as (src, dst):
            dst.objects = ['Distant_Islands-col']
        if dst.objects and dst.objects[0]:
            bpy.data.objects['Distant_Islands-col'].data = dst.objects[0].data.copy()
            bpy.data.objects.remove(dst.objects[0], do_unlink=True)
    ground=bpy.data.objects['Distant_Islands-col'];height,terrain_report=create_terrain(ground)
    COL=bpy.data.collections.new(COLLECTION);bpy.context.scene.collection.children.link(COL)
    BATCH={};COLLIDERS=[];setup_materials()
    lights=build_static(height)
    PLAN={'pond':{'center':[POND[0],WATER,-POND[1]],'radii':[POND[2],POND[3]],'water_height':WATER,'bed_height':3.30,'koi_count':14},
          'zen':{'center':[ZEN[0],LEVEL+.065,-ZEN[1]],'size':[ZEN[2],ZEN[3]],'rocks':[[x,-y,size] for x,y,size in ROCKS]},
          'terrain':terrain_report,'routes':[[[x,z,-y] for x,y,z in r] for r in ROUTES],
          'colliders':COLLIDERS,'lights':lights,'sea_max_x':160.,'sea_max_godot_z':80.,
          'grounded_props':reseat_props(height),'original_geometry':True}
    fish_collection=bpy.data.collections.new('South Garden Koi Library');bpy.context.scene.collection.children.link(fish_collection)
    prototypes=[fish_model(name,index,fish_collection) for index,name in enumerate(['Koi_Kohaku','Koi_Sanke','Koi_Gold'])]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in prototypes:obj.select_set(True)
    bpy.context.view_layer.objects.active=prototypes[0]
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/south_garden_koi.glb'),export_format='GLB',use_selection=True,export_animations=False)
    fish_collection.hide_render=True
    for i in range(14):
        obj=prototypes[i%3].copy();obj.data=prototypes[i%3].data;obj.name='South_Koi_%02d'%(i+1);COL.objects.link(obj)
        a=i*math.tau/14;r=.4+.2*(i%3)/2
        obj.location=(POND[0]+POND[2]*r*math.cos(a),POND[1]+POND[3]*r*math.sin(a),WATER-.32-.045*(i%4))
        obj.rotation_euler.z=a+math.pi/2;obj.scale=(1.+.08*(i%4),)*3
    # Portable static props; fish and terrain are separate, shared runtime libraries.
    bpy.ops.object.select_all(action='DESELECT')
    for obj in COL.objects:
        if not obj.name.startswith('South_Koi_'):obj.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in COL.objects if not o.name.startswith('South_Koi_'))
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/south_garden.glb'),export_format='GLB',use_selection=True,export_animations=False)
    # Lower the two existing landing banks into the new continuous grades too.
    # They are separate runtime instances and must not cover the graded paths.
    grounds=[ground]
    for name in ['Landing_Bank_Main_South','Landing_Bank_North_South']:
        bank=bpy.data.objects[name];bank.data=bank.data.copy();inverse=bank.matrix_world.inverted()
        for vertex in bank.data.vertices:
            p=bank.matrix_world@vertex.co
            if name=='Landing_Bank_Main_South' and p.x<=80.25:continue
            if name=='Landing_Bank_North_South':
                ns_dot=(p.x-87.0)*0.275+(p.y-(-18.75))*(-0.96)
                if ns_dot<=3.8:continue
            p.z=height(p.x,p.y)
            vertex.co=inverse@p
        bank.data.update();grounds.append(bank)
    clones=[]
    for obj in grounds:
        clone=obj.copy();clone.data=obj.data.copy();clone.name='SouthGarden_'+obj.name.replace('-col','');bpy.context.scene.collection.objects.link(clone)
        clone.data.materials.clear();clone.data.materials.append(M['Garden_Ground']);clones.append(clone)
    bpy.ops.object.select_all(action='DESELECT')
    for clone in clones:clone.select_set(True)
    bpy.context.view_layer.objects.active=clones[0]
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/south_garden_terrain.glb'),export_format='GLB',use_selection=True,export_animations=False,export_normals=True,export_tangents=False)
    # Extend only the sea's footprint; existing wave height/materials remain.
    sea=bpy.data.objects['Mediterranean_Sea'];bounds=[sea.matrix_world@Vector(v) for v in sea.bound_box]
    lo,hi=min(v.x for v in bounds),max(v.x for v in bounds);bottom,top=min(v.y for v in bounds),max(v.y for v in bounds)
    sea.data=sea.data.copy();inverse=sea.matrix_world.inverted()
    for vertex in sea.data.vertices:
        p=sea.matrix_world@vertex.co;p.x=lo+(p.x-lo)*(160-lo)/(hi-lo);p.y=top+(p.y-top)*(-80-top)/(bottom-top);vertex.co=inverse@p
    sea.data.update()
    # Existing south lamps follow the newly graded soil, outside the garden beds.
    ground_tree = height_bvh(ground)
    path=PROJECT/'assets/island_lantern_positions.json';lamps=json.loads(path.read_text());n=0
    for row in lamps:
        if row.get('island')!='South':continue
        x,y,z=row['blender_position']
        if row['name']=='Coastal_Lantern_South_04' or garden_clear(x,y,.4):
            x,y=(86.5,-37.0) if row['name']=='Coastal_Lantern_South_04' else [(86.,-27.),(86.5,-37.0),(104.,-24.0),(87.,-44.5)][n%4]
            n+=1
        hs=[]
        for i in range(32):
            px=x+.245*math.cos(i*math.tau/32)
            py=y+.245*math.sin(i*math.tau/32)
            hit=ground_tree.ray_cast(Vector((px,py,40)),Vector((0,0,-1)))[0]
            hs.append(hit.z if hit else height(px,py))
        z=min(hs)-.025
        row['blender_position']=[x,y,z];row['position']=[x,z,-y]
        row['footprint_height_range']=max(hs)-min(hs);row['maximum_base_gap']=-0.025
        obj=bpy.data.objects.get(row['name'])
        if obj:obj.location=(x,y,z)
    for p in [path,OUT/'island_lantern_positions.json']:p.write_text(json.dumps(lamps,indent=2))
    PLAN['relocated_south_lanterns']=n
    rows=update_meadow(height);PLAN['source_meadow_objects_updated']=install_meadow(rows)
    for p in [PROJECT/'assets/south_garden.json',OUT/'south_garden.json']:p.write_text(json.dumps(PLAN,indent=2))
    # The standalone is saved in a fresh background pass, after this source.
    # Blender 5.2 cannot safely write a newly linked Scene with libraries.write.
    for clone in clones:bpy.data.objects.remove(clone,do_unlink=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,'standalone':str(OUT/'south_garden.blend'),'plan':{k:PLAN[k] for k in ['pond','zen','terrain','grass']}}


def install_saved():
    assert Path(bpy.data.filepath)==OUT/'mediterranean_temple_improved.blend'
    for cname in [COLLECTION, 'South Garden Koi Library']:
        c = bpy.data.collections.get(cname)
        if c:
            for obj in list(c.objects):bpy.data.objects.remove(obj,do_unlink=True)
            bpy.data.collections.remove(c)
    with bpy.data.libraries.load(str(OUT/'south_garden.blend'),link=False) as (src,dst):
        dst.collections=[COLLECTION,'South Garden Koi Library'];dst.objects=['SouthGarden_Distant_Islands','SouthGarden_Landing_Bank_Main_South','SouthGarden_Landing_Bank_North_South']
    for col in dst.collections:bpy.context.scene.collection.children.link(col)
    for source in dst.objects:
        target=bpy.data.objects[source.name.replace('SouthGarden_','')];old_materials=list(target.data.materials);target.data=source.data
        target.data.materials.clear()
        for mat in old_materials:target.data.materials.append(mat)
        bpy.data.objects.remove(source,do_unlink=True)
    plan=json.loads((PROJECT/'assets/south_garden.json').read_text())
    for row in plan['grounded_props']:
        obj=bpy.data.objects.get(row['name']);assert obj is not None,row['name'];obj.location=row['blender_position']
    for row in json.loads((PROJECT/'assets/island_lantern_positions.json').read_text()):
        if row.get('island')=='South' and bpy.data.objects.get(row['name']):bpy.data.objects[row['name']].location=row['blender_position']
    install_meadow(json.loads((PROJECT/'assets/gscatter_ground_cover_instances.json').read_text()))
    sea=bpy.data.objects['Mediterranean_Sea'];bounds=[sea.matrix_world@Vector(v) for v in sea.bound_box]
    lo,hi=min(v.x for v in bounds),max(v.x for v in bounds);bottom,top=min(v.y for v in bounds),max(v.y for v in bounds)
    sea.data=sea.data.copy();inverse=sea.matrix_world.inverted()
    for vertex in sea.data.vertices:
        p=sea.matrix_world@vertex.co;p.x=lo+(p.x-lo)*(160-lo)/(hi-lo);p.y=top+(p.y-top)*(-80-top)/(bottom-top);vertex.co=inverse@p
    sea.data.update();bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,'garden_meshes':len(bpy.data.collections[COLLECTION].objects),'koi':14}


def save_standalone():
    """Create a clean editable library from a fresh read of the saved map."""
    assert Path(bpy.data.filepath)==PROJECT/'assets/mediterranean_temple.blend'
    if bpy.data.materials.get('Garden_Ground') is None:material('Garden_Ground',(.23,.29,.13),.98)
    keep={o.name for o in bpy.data.collections[COLLECTION].all_objects}
    keep.update(o.name for o in bpy.data.collections['South Garden Koi Library'].all_objects)
    keep.add('Distant_Islands-col')
    keep.update(['Landing_Bank_Main_South','Landing_Bank_North_South'])
    for obj in list(bpy.data.objects):
        if obj.name not in keep:bpy.data.objects.remove(obj,do_unlink=True)
    for name in ['Distant_Islands-col','Landing_Bank_Main_South','Landing_Bank_North_South']:
        ground=bpy.data.objects[name];ground.name='SouthGarden_'+name.replace('-col','')
        bpy.context.scene.collection.objects.link(ground)
        ground.data.materials.clear();ground.data.materials.append(bpy.data.materials['Garden_Ground'])
    for col in list(bpy.data.collections):
        if col.name not in [COLLECTION,'South Garden Koi Library']:bpy.data.collections.remove(col)
    bpy.context.scene.world=None
    bpy.ops.outliner.orphans_purge(do_recursive=True)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'south_garden.blend'),compress=True)
    return {'saved':bpy.data.filepath,'objects':len(bpy.data.objects)}
