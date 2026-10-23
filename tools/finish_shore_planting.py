"""Support the squared garden edge, plant new dry coastal land, reseat offshore rocks.
Run build() in the optimized source through Blender MCP, then install() in maps/libraries.
"""
import bpy, json, math, random, runpy, hashlib, struct
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
SURFACES=['Cliff_Terrain-col','Distant_Islands-col','North_Pagoda_Pagoda_Meadow_Ground','Landing_Bank_Main_North','Landing_Bank_Main_South','Landing_Bank_North_South']
SEA=['East_Headland_Stack','East_Reef','North_Reef','North_Satellite','South_Cove_Rock','South_Reef','South_Satellite','Southwest_Skerry','West_Sea_Stack']

def obj(n):
    o=bpy.data.objects.get(n) or bpy.data.objects.get(n.removesuffix('-col')) or bpy.data.objects.get(n+'-col')
    assert o is not None,n
    return o

def bvh(o):
    o.data.calc_loop_triangles()
    return BVHTree.FromPolygons([o.matrix_world@v.co for v in o.data.vertices],[tuple(t.vertices) for t in o.data.loop_triangles],all_triangles=True)

def sampler():
    trees=[bvh(obj(n)) for n in SURFACES]
    def sample(x,y):
        hits=[t.ray_cast(Vector((x,y,50)),Vector((0,0,-1))) for t in trees]
        return max((h for h in hits if h[0] is not None),key=lambda h:h[0].z,default=None)
    return sample

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)

def support_corner():
    o=obj('Distant_Islands-col');o.data=o.data.copy();count=0
    for v in o.data.vertices:
        x,y,z=v.co
        if x<115 or y> -24.5 or y>=0:continue
        # Extend the entire east/south terrace by 0.9 m, then feather over 4.5 m.
        d=math.hypot(max(x-119.5,0),max(-42.5-y,0))
        influence=(1-smooth(.9,5.4,d))*smooth(115,117,x)*smooth(-24.5,-25.5,y)
        target=z+(max(z,4.65)-z)*influence
        if target-z>1e-6:v.co.z=target;count+=1
    o.data.update()
    return count

def move_rocks(height):
    report={}
    # Radial directions deliberately lead away from the expanded island lobes.
    centers={'East_Headland_Stack':(0,3.5),'East_Reef':(92,64),'North_Reef':(58,54),
             'North_Satellite':(58,54),'South_Cove_Rock':(0,3.5),'South_Satellite':(103.5,-34)}
    placed=[]
    for n in SEA:
        o=obj(n);pts=[o.matrix_world@v.co for v in o.data.vertices]
        exposed=[p for p in pts if p.z> -5.2]
        samples=exposed[::max(1,len(exposed)//250)]
        def ground(delta):
            return max((h[0].z if (h:=height(p.x+delta.x,p.y+delta.y)) else -20) for p in samples)
        old=ground(Vector())
        if old<=-5.0:continue
        cx=(min(p.x for p in pts)+max(p.x for p in pts))/2
        cy=(min(p.y for p in pts)+max(p.y for p in pts))/2
        center=centers[n];direction=Vector((cx-center[0],cy-center[1],0)).normalized()
        if n=='East_Reef':direction=Vector((.35,-1,0)).normalized()
        if n=='South_Satellite':direction=Vector((.8,-1,0)).normalized()
        radius=max(math.hypot(p.x-cx,p.y-cy) for p in exposed)
        for step in range(1,100):
            delta=direction*step
            if ground(delta)>-5.65:continue
            # Keep neighboring formations distinct rather than stacking them.
            if any(math.hypot(cx+delta.x-px,cy+delta.y-py)<radius+pr+2 for px,py,pr in placed):continue
            # Preserve the submerged root where the expanded terrain ends.
            o.location+=delta;bpy.context.view_layer.update()
            report[n]={'delta_blender':list(delta),'position':[o.location.x,o.location.z,-o.location.y],
                       'max_ground_before':old,'max_ground_after':ground(delta),'shore_clearance_m':.65}
            placed.append((cx+delta.x,cy+delta.y,radius));break
        else:raise AssertionError('No offshore site for '+n)
    plan=json.loads((ROOT/'assets/temple_clearance.json').read_text())
    for n,r in report.items():plan['positions'][n]=r['position']
    plan['offshore_relocation']=report
    (ROOT/'assets/temple_clearance.json').write_text(json.dumps(plan,indent=2))
    return report

def plant(height):
    rng=random.Random(181026)
    a=ROOT/'assets/gscatter_ground_cover_instances.json';b=ROOT/'assets/north_pagoda_cover.json'
    rows=json.loads(a.read_text());north=json.loads(b.read_text())
    # Coarse buckets avoid piling new tufts onto the preserved meadow.
    buckets={}
    def add_bucket(r):
        x,y=r['origin'][0],-r['origin'][2];buckets.setdefault((math.floor(x),math.floor(y)),[]).append((x,y))
    for r in rows+north:add_bucket(r)
    builder=runpy.run_path(str(ROOT/'tools/build_south_garden.py'))
    # Actual solid silhouettes provide the exclusions, including bridge decks,
    # pagoda paths, temple architecture, garden props and tree trunks.
    obstacles=[]
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render or o.name in SURFACES or o.name.removesuffix('-col') in SEA:continue
        if any(s in o.name for s in ['Meadow','GScatter','Water','water','Sea','Cloud','Koi','leaves','foliage']):continue
        points=[o.matrix_world@Vector(c) for c in o.bound_box]
        if max(p.z for p in points)<-1.8:continue
        bounds=(min(p.x for p in points),max(p.x for p in points),min(p.y for p in points),max(p.y for p in points))
        obstacles.append((o,bounds,None))
    cached={};counts={'Main':0,'North':0,'South':0};reseated=0
    # Existing grass retains its density and silhouette; only changed shoulder roots move.
    for r in rows:
        x,y=r['origin'][0],-r['origin'][2]
        if x>115 and -48<y<-24.5:
            hit=height(x,y)
            if hit and hit[0].z-r['origin'][1]>.1:r['origin'][1]=hit[0].z-.025;reseated+=1
    C=Matrix(((1,0,0),(0,0,1),(0,-1,0)))
    regions=[('Main',(-55,55,-51,53),3.4),('North',(34,141,18,99),3.9),('South',(70,153,-77,-20),4.62)]
    # A jittered lattice follows the slopes; density fades into the bare lower beach.
    for island,(xmin,xmax,ymin,ymax),ceiling in regions:
        for ix in range(math.ceil((xmax-xmin)/.72)):
            for iy in range(math.ceil((ymax-ymin)/.72)):
                x=xmin+(ix+rng.uniform(.12,.88))*.72;y=ymin+(iy+rng.uniform(.12,.88))*.72
                hit=height(x,y)
                if not hit:continue
                p,normal,_,_=hit;h=p.z
                if h< -1.65 or h>ceiling or normal.z<.84:continue
                if rng.random()>.78*smooth(-1.65,.65,h):continue
                # Restrict to each island, avoiding overlapping region bounds.
                if island=='Main' and x>35 and y>25:continue
                if island=='North' and y<20:continue
                if island=='South' and builder['garden_clear'](x,y,.8):continue
                if any((x-px)**2+(y-py)**2<.55**2 for i in range(math.floor(x)-1,math.floor(x)+2) for j in range(math.floor(y)-1,math.floor(y)+2) for px,py in buckets.get((i,j),[])):continue
                blocked=False
                for o,(x0,x1,y0,y1),_ in obstacles:
                    if not (x0-.5<x<x1+.5 and y0-.5<y<y1+.5):continue
                    # Check the whole tuft footprint against nearby surfaces.
                    if o.name not in cached:cached[o.name]=bvh(o)
                    t=cached[o.name]
                    for dx,dy in [(0,0),(.33,0),(-.33,0),(0,.33),(0,-.33)]:
                        q=t.ray_cast(Vector((x+dx,y+dy,h+1.4)),Vector((0,0,-1)),1.65)[0]
                        if q is not None:blocked=True;break
                    if blocked:break
                if blocked:continue
                angle=rng.random()*math.tau;s=rng.uniform(.75,1.06)
                rotation=Vector((0,0,1)).rotation_difference(normal).to_matrix()@Matrix.Rotation(angle,3,'Z')
                bg=C@(rotation*s)@C.inverted()
                asset='GScatter_ShortSward_'+str(rng.randrange(3))
                # Taller accents are sparse on the upper slope only.
                if island!='North' and h>.5 and rng.random()<.12:asset='GScatter_TrisetumFlavescens_'+str(rng.randrange(2));s*=.72;bg*=.72
                row={'asset':asset,'origin':[x,h-.028,-y],'basis':[list(bg.col[i]) for i in range(3)],
                     'blender_rotation':list(rotation.to_euler()),'blender_scale':[s]*3,'shore_planting':island}
                if island=='North':north.append(row)
                else:rows.append(row)
                add_bucket(row);counts[island]+=1
    a.write_text(json.dumps(rows,separators=(',',':')));b.write_text(json.dumps(north,separators=(',',':')))
    return {'added':counts,'total_added':sum(counts.values()),'reseated':reseated,'runtime_total':len(rows)+len(north)}

def sync_meadow():
    rows=json.loads((ROOT/'assets/gscatter_ground_cover_instances.json').read_text());north=json.loads((ROOT/'assets/north_pagoda_cover.json').read_text())
    runpy.run_path(str(ROOT/'tools/build_south_garden.py'))['install_meadow'](rows)
    for i in range(3):
        o=bpy.data.objects.get('North_Pagoda_Meadow_'+str(i))
        if o is None:continue
        batch=[r for r in north if r['asset']=='GScatter_ShortSward_'+str(i)]
        me=bpy.data.meshes.new(o.name+' coastal points');inv=o.matrix_world.inverted()
        me.from_pydata([inv@Vector((r['origin'][0],-r['origin'][2],r['origin'][1])) for r in batch],[],[])
        for key,field in [('rotation','blender_rotation'),('scale','blender_scale')]:
            at=me.attributes.new(key,'FLOAT_VECTOR','POINT')
            for d,r in zip(at.data,batch):d.vector=r[field]
        o.data=me
    # North's taller accents use their existing map meadow keys as well.
    accents=[r for r in north if 'ShortSward' not in r['asset']]
    if accents:
        # Keep them in global placements, whose full range of source keys is installed.
        raise AssertionError('North accents must be routed to global meadow')

def export_ground():
    export=runpy.run_path(str(ROOT/'tools/polish_garden_site.py'))['export']
    for filename,entries in [('south_garden_terrain.glb',[('Distant_Islands-col','SouthGarden_Distant_Islands'),('Landing_Bank_Main_South','SouthGarden_Landing_Bank_Main_South'),('Landing_Bank_North_South','SouthGarden_Landing_Bank_North_South')]),('pagoda_sidewalk_terrain.glb',[('Distant_Islands-col','Sidewalk_Distant_Islands'),('Landing_Bank_Main_North','Sidewalk_Landing_Bank_Main_North')])]:
        clones=[]
        for n,label in entries:
            o=obj(n).copy();o.data=obj(n).data;o.name=label;bpy.context.scene.collection.objects.link(o);clones.append(o)
        export(ROOT/'assets'/filename,clones)
        if filename.startswith('pagoda'):bpy.data.libraries.write(str(OUT/'pagoda_sidewalk_terrain.blend'),set(clones),fake_user=True,compress=True)
        for o in clones:bpy.data.objects.remove(o,do_unlink=True)

def save():
    bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)

def build():
    assert Path(bpy.data.filepath)==ROOT/'assets/mediterranean_temple.blend'
    assert 'shore_planting' not in json.loads((ROOT/'assets/south_garden.json').read_text()),'Already installed; restore scoped backup before rebuilding'
    support=support_corner();height=sampler();rocks=move_rocks(height);grass=plant(height);sync_meadow();export_ground()
    # Spectrum transforms and vertex colors both travel in the scoped export.
    os=[obj(n) for n in SEA];bpy.ops.object.select_all(action='DESELECT')
    for o in os:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=os[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/offshore_spectrum.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='Reference spectrum')
    plan=json.loads((ROOT/'assets/south_garden.json').read_text());plan['grass']['runtime_total']=grass['runtime_total'];plan['shore_planting']={'support_vertices':support,'grass':grass}
    for p in [ROOT/'assets/south_garden.json',OUT/'south_garden.json']:p.write_text(json.dumps(plan,indent=2))
    report={'support_vertices':support,'rocks':rocks,'grass':grass}
    (ROOT/'assets/shore_planting.json').write_text(json.dumps(report,indent=2));save();return report

def install():
    path=Path(bpy.data.filepath)
    assert path.name!='north_pagoda.blend','The pagoda structural library keeps meadow placement in its separate JSON'
    target=bpy.data.objects.get('Distant_Islands-col') or bpy.data.objects.get('Distant_Islands') or bpy.data.objects.get('SouthGarden_Distant_Islands')
    assert target is not None
    with bpy.data.libraries.load(str(ROOT/'assets/mediterranean_temple.blend'),link=False) as (src,dst):dst.objects=['Distant_Islands-col']
    o=dst.objects[0];target.data=o.data;bpy.data.objects.remove(o,do_unlink=True)
    if path.name!='south_garden.blend':
        plan=json.loads((ROOT/'assets/temple_clearance.json').read_text())
        for n,r in plan['offshore_relocation'].items():
            p=r['position'];obj(n).location=(p[0],-p[2],p[1])
        sync_meadow()
    save();return {'saved':str(path),'terrain':digest(target)}

def digest(o):
    h=hashlib.sha256()
    for v in o.data.vertices:h.update(struct.pack('fff',*v.co))
    return h.hexdigest()

def audit():
    target=bpy.data.objects.get('Distant_Islands-col') or bpy.data.objects.get('Distant_Islands') or bpy.data.objects.get('SouthGarden_Distant_Islands')
    result={'saved':bpy.data.filepath,'terrain_sha':digest(target) if target else None}
    if target:
        ground=bvh(target);paving=obj('SouthGarden_Gravel');checked=0;maxgap=-1;mingap=100
        for v in paving.data.vertices:
            p=paving.matrix_world@v.co
            if not (p.x>116.8 and -42.51<=p.y<=-25.5):continue
            hit=ground.ray_cast(Vector((p.x,p.y,40)),Vector((0,0,-1)))[0]
            assert hit is not None
            if p.z>4.70:
                gap=p.z-hit.z;maxgap=max(maxgap,gap);mingap=min(mingap,gap);checked+=1
        assert maxgap<.13 and mingap>.015,(maxgap,mingap)
        result.update({'supported_edge_vertices':checked,'max_paving_soil_gap':maxgap,'min_paving_soil_gap':mingap})
    return result

def finalize_roots_and_sites():
    """Use Blender's exported triangle tessellation for roots and offshore samples."""
    height=sampler();C=Matrix(((1,0,0),(0,0,1),(0,-1,0)));root_count=0
    for name in ['gscatter_ground_cover_instances.json','north_pagoda_cover.json']:
        path=ROOT/'assets'/name;rows=json.loads(path.read_text())
        for r in rows:
            if 'shore_planting' not in r:continue
            x,y=r['origin'][0],-r['origin'][2];hit=height(x,y);assert hit
            r['origin'][1]=hit[0].z-.028
            rotation=Vector((0,0,1)).rotation_difference(hit[1]).to_matrix()@Matrix.Rotation(r['blender_rotation'][2],3,'Z')
            bg=C@(rotation*r['blender_scale'][0])@C.inverted()
            r['basis']=[list(bg.col[i]) for i in range(3)];r['blender_rotation']=list(rotation.to_euler());root_count+=1
        path.write_text(json.dumps(rows,separators=(',',':')))
    # Keep the south beach's established descent/ascent corridor open.
    rock=obj('South_Satellite');base=rock.location.copy()
    exposed=[rock.matrix_world@v.co for v in rock.data.vertices if (rock.matrix_world@v.co).z> -5.2]
    blocks_corridor=min(p.x for p in exposed)<118 and max(p.x for p in exposed)>111
    for dx in (range(16,45) if blocks_corridor else [0]):
        delta=Vector((dx,0,0));maximum=-20
        for v in rock.data.vertices:
            p=rock.matrix_world@v.co+delta
            if p.z< -5.2:continue
            hit=height(p.x,p.y)
            if hit:maximum=max(maximum,hit[0].z)
        if maximum< -5.65:
            rock.location=base+delta;break
    else:raise AssertionError('South satellite site still dry')
    plan=json.loads((ROOT/'assets/temple_clearance.json').read_text())
    plan['positions']['South_Satellite']=[rock.location.x,rock.location.z,-rock.location.y]
    record=plan['offshore_relocation']['South_Satellite'];record['position']=plan['positions']['South_Satellite'];record['delta_blender']=list(rock.location);record['max_ground_after']=maximum
    # Audit all exposed stone vertices, rather than relying on a few centers.
    counts={}
    for n in plan['offshore_relocation']:
        o=obj(n);maximum=-20;count=0
        for v in o.data.vertices:
            p=o.matrix_world@v.co
            if p.z< -5.0:continue
            h=height(p.x,p.y)
            if h:maximum=max(maximum,h[0].z)
            count+=1
        assert maximum< -5.3,(n,maximum)
        counts[n]={'vertices':count,'max_terrain':maximum}
    (ROOT/'assets/temple_clearance.json').write_text(json.dumps(plan,indent=2))
    export_spectrum();sync_meadow();save()
    return {'roots_reseated':root_count,'offshore_audit':counts}

def export_spectrum():
    os=[obj(n) for n in SEA];bpy.ops.object.select_all(action='DESELECT')
    for o in os:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=os[0]
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/offshore_spectrum.glb'),export_format='GLB',use_selection=True,export_animations=False,export_cameras=False,export_lights=False,export_vertex_color='NAME',export_vertex_color_name='Reference spectrum')
