"""Guard the exposed far edge of the top landing, preserving both spiral flights.

Run build_and_export() in north_pagoda.blend, then install_saved() in both maps.
The middle landing shares this edge with the ascending second flight, so a
horizontal rail there would block the stairs. The top landing has no such flight.
"""
import json
import math
from pathlib import Path

import bpy

PROJECT=Path(__file__).resolve().parent.parent
OUT=Path('/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements')
PREFIX='North_Pagoda_Top_Landing_Guard_'
ANGLE=-math.pi/2+.58
YAW=-.88


def world(x,y,z):
    c,s=math.cos(YAW),math.sin(YAW)
    return (92+c*x-s*y,64+s*x+c*y,5.5+z)


def build_and_export():
    assert Path(bpy.data.filepath)==OUT/'north_pagoda.blend'
    collection=bpy.data.collections['North Pagoda']
    batches={'Cedar':([],[]),'Bronze':([],[])}
    cube=[(-1,-1,-1),(1,-1,-1),(1,1,-1),(-1,1,-1),
          (-1,-1,1),(1,-1,1),(1,1,1),(-1,1,1)]
    quads=[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]
    def box(material,r,z,length,width,height):
        vertices,faces=batches[material];offset=len(vertices)
        c,s=math.cos(ANGLE),math.sin(ANGLE)
        for x,y,h in cube:
            xx=r+x*length/2;yy=y*width/2
            vertices.append(world(c*xx-s*yy,s*xx+c*yy,z+h*height/2))
        faces.extend(tuple(offset+i for i in face) for face in quads)
    # Concealed overlaps join the central stair post and existing circular guard.
    lo,hi=.30,2.60
    box('Cedar',(lo+hi)/2,9.8+1.025,hi-lo,.105,.105)
    box('Cedar',(lo+hi)/2,9.8+.12,hi-lo,.075,.09)
    for r in [.36,2.53]:box('Cedar',r,9.8+.54,.085,.085,1.08)
    for i in range(1,15):box('Bronze',.36+(2.53-.36)*i/15,9.8+.565,.028,.028,.87)
    for suffix,(vertices,faces) in batches.items():
        name=PREFIX+suffix
        obj=bpy.data.objects.get(name)
        if not obj:
            obj=bpy.data.objects.new(name,bpy.data.meshes.new(name));collection.objects.link(obj)
        else:obj.data=bpy.data.meshes.new(name)
        obj.data.from_pydata(vertices,[],faces);obj.data.update()
        obj.data.materials.append(bpy.data.materials['Pagoda_Red_Cedar' if suffix=='Cedar' else 'Pagoda_Aged_Bronze'])
        obj['top_landing_guard']=True
    plan=json.loads((PROJECT/'assets/north_pagoda.json').read_text())
    row={'type':'box','center':list(world(math.cos(ANGLE)*(lo+hi)/2,math.sin(ANGLE)*(lo+hi)/2,9.8+.54)),
         'size':[hi-lo,.11,1.08],'yaw':YAW+ANGLE,'top_landing_guard':True}
    plan['colliders']=[r for r in plan['colliders'] if not r.get('top_landing_guard')]+[row]
    plan['top_landing_guard']={'angle':ANGLE,'radial_extent':[lo,hi],'height':1.08,
                               'floor':15.3,'preserves_stair_entry':True}
    for path in [PROJECT/'assets/north_pagoda.json',OUT/'north_pagoda.json']:
        path.write_text(json.dumps(plan,indent=2))
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in collection.all_objects:obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/north_pagoda.glb'),export_format='GLB',
                              use_selection=True,export_cameras=False,export_lights=False,export_animations=False)
    return {'saved':bpy.data.filepath,'guard':plan['top_landing_guard']}


def install_saved():
    assert Path(bpy.data.filepath) in [PROJECT/'assets/mediterranean_temple.blend',OUT/'mediterranean_temple_improved.blend']
    names=(PREFIX+'Cedar',PREFIX+'Bronze')
    with bpy.data.libraries.load(str(OUT/'north_pagoda.blend'),link=False) as (src,dst):dst.objects=list(names)
    for source in dst.objects:
        # Appending creates a .001 suffix when the guard is already installed.
        name=next(n for n in names if source.name.startswith(n))
        target=bpy.data.objects.get(name)
        if target and target!=source:
            target.data=source.data;bpy.data.objects.remove(source,do_unlink=True)
        else:target=source;bpy.data.collections['North Pagoda'].objects.link(target)
        target.data.materials[0]=bpy.data.materials['Pagoda_Red_Cedar' if name.endswith('Cedar') else 'Pagoda_Aged_Bronze']
        target['top_landing_guard']=True
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath,compress=True)
    return {'saved':bpy.data.filepath,'guard_objects':names}
