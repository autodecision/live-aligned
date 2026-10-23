"""Round the south bridge's coastal grade and fill dry coastal meadow gaps via Blender MCP."""
import bpy,json,math,random,runpy
from pathlib import Path
from mathutils import Vector,Matrix
ROOT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
H=runpy.run_path(str(ROOT/'tools/finish_shore_planting.py'))

def reshape():
    o=H['obj']('Cliff_Terrain-col');o.data=o.data.copy();count=0
    for v in o.data.vertices:
        x,y,z=v.co
        if not (-23<x<14 and -49<y<-25.4):continue
        # A broad convex shoulder joins the south beach to the bridge approach.
        # The bridge landing and its original upper grade remain untouched.
        weight=H['smooth'](-23,-17,x)*(1-H['smooth'](7,14,x))*H['smooth'](-25.4,-27.2,y)*(1-H['smooth'](-40,-44.5,y))
        run=max(-y-25,0)
        crest=3.1-.016*min(x+9,0)**2-.10*max(x+9,0)-.018*max(x+1,0)**2
        target=crest-.46*run+.08*math.sin(.38*x+.19*y)*H['smooth'](0,4,run)
        target=z+(target-z)*weight
        if abs(target-z)>1e-5:v.co.z=target;count+=1
    o.data.update();return count

def plant():
    height=H['sampler']();rng=random.Random(181046)
    files=['gscatter_ground_cover_instances.json','north_pagoda_cover.json']
    batches=[json.loads((ROOT/'assets'/f).read_text()) for f in files]
    assert not any('coastal_meadow' in r for b in batches for r in b),'Already planted'
    buckets={};cell=.5
    def bucket(r):
        x,y=r['origin'][0],-r['origin'][2];buckets.setdefault((math.floor(x/cell),math.floor(y/cell)),[]).append((x,y))
    reseated=0
    C=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
    for batch in batches:
        for r in batch:
            x,y=r['origin'][0],-r['origin'][2]
            if -23<x<14 and -49<y<-25.4:
                hit=height(x,y)
                if hit and abs(hit[0].z-.028-r['origin'][1])>.01:
                    r['origin'][1]=hit[0].z-.028
                    old=C.inverted()@Matrix(r['basis']).transposed()@C
                    scale=old.to_scale();yaw=old.to_euler().z
                    rot=Vector((0,0,1)).rotation_difference(hit[1]).to_matrix()@Matrix.Rotation(yaw,3,'Z')
                    bg=C@rot@Matrix.Diagonal(scale)@C.inverted();r['basis']=[list(bg.col[i]) for i in range(3)];r['blender_rotation']=list(rot.to_euler());r['blender_scale']=list(scale);reseated+=1
            bucket(r)
    obstacles=[]
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render or o.name in H['SURFACES']:continue
        if any(s in o.name for s in ['Meadow','GScatter','Water','water','Sea','Cloud','Koi','leaves','foliage']):continue
        pts=[o.matrix_world@Vector(c) for c in o.bound_box]
        if max(p.z for p in pts)<-2.3:continue
        obstacles.append((o,(min(p.x for p in pts),max(p.x for p in pts),min(p.y for p in pts),max(p.y for p in pts))))
    cached={};garden=runpy.run_path(str(ROOT/'tools/build_south_garden.py'))['garden_clear'];counts={}
    for island,box,ceiling in [('Main',(-55,53,-50,55),3.5),('North',(34,141,18,99),6.0),('South',(70,153,-77,-20),5.0)]:
        counts[island]=0;x0,x1,y0,y1=box;step=.28
        for ix in range(math.ceil((x1-x0)/step)):
            for iy in range(math.ceil((y1-y0)/step)):
                x=x0+(ix+rng.uniform(.10,.90))*step;y=y0+(iy+rng.uniform(.10,.90))*step
                hit=height(x,y)
                if not hit:continue
                p,normal,_,_=hit;h=p.z
                if not (-2.2<h<ceiling) or normal.z<.79:continue
                if island=='Main' and x>35 and y>25:continue
                if island=='South' and garden(x,y,.45):continue
                # Density tapers through the dry upper beach, with no submerged grass.
                patch=.85+.13*math.sin(x*.46)*math.sin(y*.34)
                if rng.random()>patch*H['smooth'](-2.2,.0,h):continue
                bx,by=math.floor(x/cell),math.floor(y/cell)
                if any((x-px)**2+(y-py)**2<.215**2 for a in range(bx-1,bx+2) for b in range(by-1,by+2) for px,py in buckets.get((a,b),[])):continue
                blocked=False
                for o,(a,b,c,d) in obstacles:
                    if not(a-.3<x<b+.3 and c-.3<y<d+.3):continue
                    if o.name not in cached:cached[o.name]=H['bvh'](o)
                    for dx,dy in [(0,0),(.26,0),(-.26,0),(0,.26),(0,-.26)]:
                        if cached[o.name].ray_cast(Vector((x+dx,y+dy,h+1.25)),Vector((0,0,-1)),1.5)[0] is not None:blocked=True;break
                    if blocked:break
                if blocked:continue
                angle=rng.random()*math.tau;s=rng.uniform(.85,1.15)
                rot=Vector((0,0,1)).rotation_difference(normal).to_matrix()@Matrix.Rotation(angle,3,'Z')
                asset='GScatter_ShortSward_'+str(rng.randrange(3))
                # Subtle taller accents; keep north's point library on its short keys.
                north=island=='North'
                if not north and h>.7 and rng.random()<.08:asset='GScatter_TrisetumFlavescens_'+str(rng.randrange(2));s*=.8
                bg=C@(rot*s)@C.inverted()
                r={'asset':asset,'origin':[x,h-.028,-y],'basis':[list(bg.col[i]) for i in range(3)],'blender_rotation':list(rot.to_euler()),'blender_scale':[s]*3,'coastal_meadow':island}
                batches[1 if north else 0].append(r);bucket(r);counts[island]+=1
    for f,rows in zip(files,batches):
        for path in [ROOT/'assets'/f,OUT/f]:path.write_text(json.dumps(rows,separators=(',',':')))
    return {'added':counts,'added_total':sum(counts.values()),'reseated':reseated,'runtime_total':sum(map(len,batches))}

def export():
    o=H['obj']('Cliff_Terrain-col');original=o.name;o.name='Cliff_Terrain'
    bpy.ops.object.select_all(action='DESELECT');o.hide_set(False);o.select_set(True);bpy.context.view_layer.objects.active=o
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/bridge_approach_terrain.glb'),export_format='GLB',use_selection=True,export_animations=False,export_lights=False,export_cameras=False)
    bpy.data.libraries.write(str(OUT/'bridge_approach_terrain.blend'),{o},fake_user=True,compress=True);o.name=original

def build():
    assert Path(bpy.data.filepath)==ROOT/'assets/mediterranean_temple.blend'
    changed=reshape();grass=plant();H['sync_meadow']();export()
    report={'terrain_vertices':changed,'grass':grass,'terrain_sha':H['digest'](H['obj']('Cliff_Terrain-col'))}
    (ROOT/'assets/coastal_meadow.json').write_text(json.dumps(report,indent=2))
    plan=json.loads((ROOT/'assets/south_garden.json').read_text());plan['grass']['runtime_total']=grass['runtime_total'];plan['coastal_meadow']=report
    for p in [ROOT/'assets/south_garden.json',OUT/'south_garden.json']:p.write_text(json.dumps(plan,indent=2))
    H['save']();return report

def install():
    target=H['obj']('Cliff_Terrain-col')
    with bpy.data.libraries.load(str(OUT/'bridge_approach_terrain.blend'),link=False) as (src,dst):dst.objects=['Cliff_Terrain']
    source=dst.objects[0];target.data=source.data;bpy.data.objects.remove(source,do_unlink=True)
    H['sync_meadow']();H['save']();return {'saved':bpy.data.filepath,'terrain_sha':H['digest'](target)}


def finalize_grade():
    """Reapply the final convex grade from the scoped pre-pass mesh, then seat roots."""
    backup=Path('/tmp/coastal-meadow-backup.txt').read_text().strip()
    path=Path(backup)/str(ROOT/'assets/mediterranean_temple.blend').lstrip('/')
    with bpy.data.libraries.load(str(path),link=False) as (src,dst):dst.objects=['Cliff_Terrain-col']
    source=dst.objects[0];H['obj']('Cliff_Terrain-col').data=source.data;bpy.data.objects.remove(source,do_unlink=True)
    changed=reshape();height=H['sampler']();C=Matrix(((1,0,0),(0,0,1),(0,-1,0)));reseated=0;removed=0
    for file in ['gscatter_ground_cover_instances.json','north_pagoda_cover.json']:
        rows=json.loads((ROOT/'assets'/file).read_text());final=[]
        for r in rows:
            x,y=r['origin'][0],-r['origin'][2]
            if -23<x<14 and -49<y<-25.4:
                hit=height(x,y)
                if hit[0].z<(-1.65 if r.get('shore_planting') else -2.2):removed+=1;continue
                r['origin'][1]=hit[0].z-.028
                old=C.inverted()@Matrix(r['basis']).transposed()@C;scale=old.to_scale();yaw=old.to_euler().z
                rot=Vector((0,0,1)).rotation_difference(hit[1]).to_matrix()@Matrix.Rotation(yaw,3,'Z')
                bg=C@rot@Matrix.Diagonal(scale)@C.inverted()
                r['basis']=[list(bg.col[i]) for i in range(3)];r['blender_rotation']=list(rot.to_euler());r['blender_scale']=list(scale);reseated+=1
            final.append(r)
        for p in [ROOT/'assets'/file,OUT/file]:p.write_text(json.dumps(final,separators=(',',':')))
    report=json.loads((ROOT/'assets/coastal_meadow.json').read_text());report['terrain_vertices']=changed;report['terrain_sha']=H['digest'](H['obj']('Cliff_Terrain-col'))
    allrows=json.loads((ROOT/'assets/gscatter_ground_cover_instances.json').read_text())+json.loads((ROOT/'assets/north_pagoda_cover.json').read_text())
    counts={island:sum(r.get('coastal_meadow')==island for r in allrows) for island in ['Main','North','South']}
    report['grass']['added']=counts;report['grass']['added_total']=sum(counts.values());report['grass']['runtime_total']=len(allrows);report['final_grade_reseated']=reseated;report['lower_beach_roots_removed']=removed
    (ROOT/'assets/coastal_meadow.json').write_text(json.dumps(report,indent=2))
    plan=json.loads((ROOT/'assets/south_garden.json').read_text());plan['grass']['runtime_total']=report['grass']['runtime_total'];plan['coastal_meadow']=report
    for p in [ROOT/'assets/south_garden.json',OUT/'south_garden.json']:p.write_text(json.dumps(plan,indent=2))
    H['sync_meadow']();export();H['save']();return report
