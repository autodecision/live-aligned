"""Scoped, repeatable temple colonnade and podium detailing, run through Blender MCP.

Build in the optimized companion, then install_saved in the artistic source.
The original map GLB and its simple walking/collision geometry stay intact.
"""
import hashlib
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector

PROJECT = Path(__file__).resolve().parent.parent
ART = Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/mediterranean_temple_improved.blend')
OPT = PROJECT / 'assets/mediterranean_temple.blend'
PREVIEW = Path('/home/allister/Projects/live-aligned-previews/temple-detail-2026-10-18')
NAMES = ('Temple_Colonnade-col', 'Temple_Stylobate-col', 'Temple_Bedrock_Foundation-col')


class StoneMesh:
    def __init__(self):
        self.vertices, self.faces, self.materials, self.uvs, self.smooth = [], [], [], [], []

    def face(self, indices, material=0, uv=None, smooth=False):
        self.faces.append(indices)
        self.materials.append(material)
        self.uvs.append(uv)
        self.smooth.append(smooth)

    def box(self, lo, hi, material=0):
        offset = len(self.vertices)
        self.vertices.extend([(x,y,z) for z in (lo[2],hi[2]) for y in (lo[1],hi[1]) for x in (lo[0],hi[0])])
        for face in [(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]:
            self.face(tuple(offset+i for i in face), material)

    def lathe(self, cx, cy, profile, segments=64, fluted=False, material=0):
        offset = len(self.vertices)
        for z, radius in profile:
            for i in range(segments):
                theta = 2*math.pi*i/segments
                r = radius
                if fluted:
                    # Twenty stopped flutes with rounded terminations; the lands
                    # retain the original column envelope and keep a clear arris.
                    fade = min(1., max(0.,(z-4.925)/.10), max(0.,(10.325-z)/.10))
                    r -= .030 * fade * (1.-math.cos(20*theta))*.5
                self.vertices.append((cx+r*math.cos(theta),cy+r*math.sin(theta),z))
        for j in range(len(profile)-1):
            for i in range(segments):
                nxt = (i+1)%segments
                a, b = offset+j*segments+i, offset+j*segments+nxt
                c, d = b+segments, a+segments
                # Real-world texel scale, continuous across each cylindrical band.
                u0,u1 = i/segments*2*math.pi*.42*.65,(i+1)/segments*2*math.pi*.42*.65
                v0,v1 = profile[j][0]*.65,profile[j+1][0]*.65
                self.face((a,b,c,d),material,[(u0,v0),(u1,v0),(u1,v1),(u0,v1)],True)
        self.face(tuple(offset+i for i in reversed(range(segments))),material)
        start=offset+(len(profile)-1)*segments
        self.face(tuple(start+i for i in range(segments)),material)

    def replace(self, name, materials, bevel=0.):
        obj = bpy.data.objects[name]
        inverse = obj.matrix_world.inverted()
        mesh = bpy.data.meshes.new(name+' | carved stone')
        mesh.from_pydata([inverse@Vector(p) for p in self.vertices],[],self.faces)
        mesh.update()
        for mat in materials:mesh.materials.append(mat)
        uv = mesh.uv_layers.new(name='Stone scale UV')
        for index, face in enumerate(mesh.polygons):
            face.material_index=self.materials[index]
            face.use_smooth=self.smooth[index]
            axis=max(range(3),key=lambda k:abs(face.normal[k]))
            axes=[k for k in range(3) if k!=axis]
            for corner, li in enumerate(face.loop_indices):
                if self.uvs[index] is not None:
                    uv.data[li].uv=self.uvs[index][corner]
                else:
                    point=self.vertices[mesh.loops[li].vertex_index]
                    uv.data[li].uv=(point[axes[0]]*.65,point[axes[1]]*.65)
        obj.data=mesh
        obj.modifiers.clear()
        if bevel:
            # Easing the square blocks is enough. Beveling every flute edge
            # multiplies geometry and blunts the actual carving.
            edge_faces={tuple(sorted(e.vertices)):[] for e in mesh.edges}
            for face in mesh.polygons:
                for a,b in zip(face.vertices,list(face.vertices[1:])+[face.vertices[0]]):
                    edge_faces[tuple(sorted((a,b)))].append(face.use_smooth)
            weights=mesh.attributes.new('bevel_weight_edge','FLOAT','EDGE')
            for edge in mesh.edges:
                faces=edge_faces[tuple(sorted(edge.vertices))]
                weights.data[edge.index].value=1. if len(faces)==2 and not any(faces) else 0.
            bpy.context.view_layer.objects.active=obj
            mod=obj.modifiers.new('Hand eased stone edges','BEVEL')
            mod.width=bevel;mod.segments=2;mod.affect='EDGES'
            mod.limit_method='WEIGHT'
            bpy.ops.object.modifier_apply(modifier=mod.name)
        obj['live_aligned_detail']='2026-10-18: fluted order and coursed podium'
        return obj


def stone_materials():
    result=[]
    for label,tint in [('warm limestone',(1.,.97,.90,1)),('pale limestone',(.94,.94,.91,1)),('aged limestone',(.87,.87,.82,1))]:
        name='Temple detail | '+label
        mat=bpy.data.materials.get(name) or bpy.data.materials.new(name)
        mat.use_nodes=True
        nodes=mat.node_tree.nodes;nodes.clear();links=mat.node_tree.links
        out=nodes.new('ShaderNodeOutputMaterial');bsdf=nodes.new('ShaderNodeBsdfPrincipled')
        bsdf.inputs['Roughness'].default_value=.83
        bsdf.inputs['Specular IOR Level'].default_value=.25
        links.new(bsdf.outputs['BSDF'],out.inputs['Surface'])
        for suffix,socket in [('Diffuse','Base Color'),('Rough','Roughness'),('nor_gl','Normal')]:
            tex=nodes.new('ShaderNodeTexImage')
            tex.image=bpy.data.images.load(str(PROJECT/f'assets/textures/marble_01_{suffix}_2k.jpg'),check_existing=True)
            tex.image.pack()
            if suffix!='Diffuse':tex.image.colorspace_settings.name='Non-Color'
            if suffix=='Diffuse':
                # glTF exports this constant multiplication as its base-color factor.
                mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY'
                mix.inputs[0].default_value=1.;mix.inputs[2].default_value=tint
                links.new(tex.outputs['Color'],mix.inputs[1]);links.new(mix.outputs[0],bsdf.inputs[socket])
            elif suffix=='nor_gl':
                normal=nodes.new('ShaderNodeNormalMap');normal.inputs['Strength'].default_value=.48
                links.new(tex.outputs['Color'],normal.inputs['Color']);links.new(normal.outputs[0],bsdf.inputs[socket])
            else:links.new(tex.outputs['Color'],bsdf.inputs[socket])
        result.append(mat)
    return result


def pillar_centers():
    obj=bpy.data.objects[NAMES[0]]
    if 'pillar_centers' in obj:return json.loads(obj['pillar_centers'])
    # Recover the twenty-four square footings from the original batched mesh.
    mesh=obj.data;adj=[set() for _ in mesh.vertices]
    for edge in mesh.edges:
        a,b=edge.vertices;adj[a].add(b);adj[b].add(a)
    seen=set();centers=[]
    for i in range(len(adj)):
        if i in seen:continue
        todo=[i];seen.add(i);component=[]
        while todo:
            a=todo.pop();component.append(a)
            for b in adj[a]:
                if b not in seen:seen.add(b);todo.append(b)
        pts=[obj.matrix_world@mesh.vertices[j].co for j in component]
        low=min(p.z for p in pts)
        if len(pts)==8 and abs(low-4.525)<.001:
            centers.append([round(sum(p.x for p in pts)/8,4),round(sum(p.y for p in pts)/8,4)])
    assert len(centers)==24,centers
    obj['pillar_centers']=json.dumps(centers)
    return centers


def columns(materials):
    centers=pillar_centers();builder=StoneMesh()
    for index,(x,y) in enumerate(centers):
        material=index%2
        builder.box((x-.46,y-.46,4.525),(x+.46,y+.46,4.675),material)
        builder.lathe(x,y,[(4.675,.43),(4.69,.463),(4.715,.478),(4.745,.48),
            (4.775,.468),(4.80,.433),(4.815,.417),(4.84,.412),(4.86,.426),
            (4.88,.442),(4.90,.439),(4.918,.422),(4.925,.417)],48,material=material)
        heights=[4.925,4.965,5.025,5.35,6.005,6.015,6.025,7.085,7.095,7.105,
                 8.165,8.175,8.185,9.245,9.255,9.265,9.8,10.225,10.285,10.325]
        profile=[]
        for z in heights:
            t=(z-4.925)/5.4
            r=.4168*(1.-.12*t)+.008*math.sin(math.pi*t)
            if any(abs(z-j)<.001 for j in [6.015,7.095,8.175,9.255]):r-=.003
            profile.append((z,r))
        builder.lathe(x,y,profile,80,True,material)
        builder.lathe(x,y,[(10.325,.367),(10.34,.389),(10.365,.394),(10.385,.382),
            (10.405,.39),(10.435,.412),(10.47,.448),(10.505,.475),(10.53,.48),
            (10.545,.48)],48,material=material)
        builder.box((x-.49,y-.49,10.545),(x+.49,y+.49,10.745),material)
    return builder.replace(NAMES[0],materials,.009)


def perimeter(builder,lo,hi,z0,z1,pitch,row,depth=.25):
    # Stagger the joints; turn the corner with full-size end stones.
    xmin,ymin=lo;xmax,ymax=hi
    for axis,start,end,fixeds in [(0,xmin,xmax,(ymin,ymax)),(1,ymin+depth,ymax-depth,(xmin,xmax))]:
        offset=pitch*.5 if row%2 else 0.
        cuts=[start]+[start+offset+pitch*i for i in range(1+math.ceil((end-start)/pitch)) if start+.15<start+offset+pitch*i<end-.15]+[end]
        for side,fixed in enumerate(fixeds):
            for index,(a,b) in enumerate(zip(cuts,cuts[1:])):
                material=(row+index+side)%3
                if axis==0:
                    l=(a+.006,fixed if side==0 else fixed-depth,z0+.007)
                    h=(b-.006,fixed+depth if side==0 else fixed,z1-.007)
                else:
                    l=(fixed if side==0 else fixed-depth,a+.006,z0+.007)
                    h=(fixed+depth if side==0 else fixed,b-.006,z1-.007)
                builder.box(l,h,material)


def foundation(materials):
    mesh=StoneMesh()
    mesh.box((-9.75,-2.45,-.1),(2.75,15.45,3.7),2)
    for row in range(6):
        z0=-.1+3.8*row/6;z1=-.1+3.8*(row+1)/6
        perimeter(mesh,(-9.8,-2.5),(2.8,15.5),z0,z1,1.65,row)
    # A recessed socle and a shallow projecting string course articulate the base.
    for z0,z1,depth in [(.12,.22,.16),(3.27,3.34,.18)]:
        perimeter(mesh,(-9.815,-2.515),(2.815,15.515),z0,z1,2.4,0,depth)
    return mesh.replace(NAMES[2],materials,.012)


def stylobate(materials):
    mesh=StoneMesh()
    for level,(xmin,ymin,xmax,ymax,z0,z1) in enumerate([
            (-9.6,-2.3,2.6,15.3,3.475,3.825),
            (-9.2,-1.9,2.2,14.9,3.825,4.175),
            (-8.8,-1.5,1.8,14.5,4.175,4.525)]):
        # Core keeps the original uninterrupted horizontal walking surface.
        mesh.box((xmin+.035,ymin+.035,z0),(xmax-.035,ymax-.035,z1),0)
        perimeter(mesh,(xmin,ymin),(xmax,ymax),z0,z1,1.5,level)
        # Fine shadow reveal under the rounded upper edge of each step.
        perimeter(mesh,(xmin-.008,ymin-.008),(xmax+.008,ymax+.008),z1-.065,z1,1.5,level,.12)
    return mesh.replace(NAMES[1],materials,.009)


def fingerprint(obj):
    digest=hashlib.sha256()
    for v in obj.data.vertices:digest.update(struct.pack('<3f',*(obj.matrix_world@v.co)))
    for face in obj.data.polygons:digest.update(struct.pack('<'+'I'*len(face.vertices),*face.vertices))
    return digest.hexdigest()


def report():
    result={}
    for name in NAMES:
        obj=bpy.data.objects.get(name) or bpy.data.objects[name.removesuffix('-col')]
        mesh=obj.data;mesh.calc_loop_triangles()
        result[name]={'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),
            'uv_loops':len(mesh.uv_layers.active.data),'sha256':fingerprint(obj)}
    return result


def build_and_export():
    materials=stone_materials()
    objects=[columns(materials),stylobate(materials),foundation(materials)]
    bpy.ops.object.select_all(action='DESELECT')
    for obj in objects:obj.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/temple_architecture_detail.glb'),
        export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False)
    bpy.ops.wm.save_as_mainfile(filepath=str(OPT))
    PREVIEW.mkdir(parents=True,exist_ok=True)
    data=report();(PREVIEW/'build.json').write_text(json.dumps(data,indent=2))
    return data


def install_saved():
    # Append only the affected meshes. All other source geometry and placements
    # remain exactly as they were in this separately edited artistic document.
    targets={name:bpy.data.objects.get(name) or bpy.data.objects[name.removesuffix('-col')] for name in NAMES}
    with bpy.data.libraries.load(str(OPT),link=False) as (src,dst):dst.objects=list(NAMES)
    for imported,name in zip(dst.objects,NAMES):
        target=targets[name]
        target.data=imported.data
        target['live_aligned_detail']=imported['live_aligned_detail']
        if 'pillar_centers' in imported:target['pillar_centers']=imported['pillar_centers']
        bpy.data.objects.remove(imported,do_unlink=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(ART))
    return report()
