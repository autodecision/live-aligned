"""Reopen each saved Blender source and verify the scoped south-island addition."""
import bpy
import hashlib
import json
import struct
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

PROJECT=Path(__file__).resolve().parent.parent
PREVIEW=Path('/home/allister/Projects/live-aligned-previews/south-koi-garden-2026-10-15')
BACKUP=Path(json.loads((PREVIEW/'backup.json').read_text())['backup'])

def fingerprint(obj):
    digest=hashlib.sha256()
    for vertex in obj.data.vertices:digest.update(struct.pack('fff',*vertex.co))
    for polygon in obj.data.polygons:digest.update(struct.pack('I'+'I'*len(polygon.vertices),len(polygon.vertices),*polygon.vertices))
    return digest.hexdigest()

def validate():
    source=Path(bpy.data.filepath)
    standalone=source.name=='south_garden.blend'
    optimized=source==PROJECT/'assets/mediterranean_temple.blend'
    name='SouthGarden_Distant_Islands' if standalone else ('Distant_Islands-col' if optimized else 'Distant_Islands')
    ground=bpy.data.objects[name]
    pond=bpy.data.objects['SouthGarden_Pond_Lining']
    fish=[obj for obj in bpy.data.collections['South Koi and Zen Garden'].objects if obj.name.startswith('South_Koi_')]
    assert len(fish)==14
    assert len({obj.data.as_pointer() for obj in fish})==3
    assert len(ground.data.vertices)==6735+14497
    report={'source':str(source),'terrain_sha256':fingerprint(ground),'terrain_vertices':len(ground.data.vertices),'static_koi':len(fish),'koi_meshes':3,'garden_objects':len(bpy.data.collections['South Koi and Zen Garden'].objects)}
    if not standalone:
        old_path=BACKUP/str(source).lstrip('/')
        with bpy.data.libraries.load(str(old_path),link=False) as (src,dst):dst.objects=[name]
        old=dst.objects[0]
        vertices=[old.matrix_world@v.co for v in old.data.vertices]
        used=sorted({i for p in old.data.polygons if not all(vertices[j].y<0 for j in p.vertices) for i in p.vertices})
        assert len(used)==6735
        assert all((ground.data.vertices[i].co-vertices[j]).length<.00001 for i,j in enumerate(used))
        report['unchanged_northern_vertices']=len(used)
        assert len([o for o in bpy.data.objects if o.name.startswith('Island_South_Olive_')])==11
        report['south_olives']=11
        bpy.data.objects.remove(old,do_unlink=True)
    terrain=BVHTree.FromPolygons([v.co for v in ground.data.vertices],[tuple(p.vertices) for p in ground.data.polygons])
    lining=BVHTree.FromPolygons([v.co for v in pond.data.vertices],[tuple(p.vertices) for p in pond.data.polygons])
    minimum=100.
    samples=0
    for x in range(182,203):
        for y in range(-75,-60):
            xx,yy=x*.5,y*.5
            if ((xx-96)/5.6)**2+((yy+34)/4)**2>.88**2:continue
            top=lining.ray_cast(Vector((xx,yy,10)),Vector((0,0,-1)))[0]
            soil=terrain.ray_cast(Vector((xx,yy,10)),Vector((0,0,-1)))[0]
            assert top is not None and soil is not None
            minimum=min(minimum,top.z-soil.z);samples+=1
    assert minimum>.035,minimum
    report['pond_soil_clearance_min_m']=minimum
    report['pond_soil_samples']=samples
    filename='source_'+('library' if standalone else ('optimized' if optimized else 'artistic'))+'.json'
    (PREVIEW/filename).write_text(json.dumps(report,indent=2))
    return report
