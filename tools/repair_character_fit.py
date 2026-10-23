"""Rebuild the three fitted characters from their existing local authoring recipe.

Run refresh() through Blender MCP in ps3_character_lineup.blend. Materials,
lighting, presentation and the established twenty-bone rigs are preserved.
The authoring recipe contains the fitted V opening, thigh-weighted coat skirt
and forearm inset in its armour's local coordinate frame.
"""
import ast
import json
import math
import random
from pathlib import Path

import bpy
import numpy as np
from mathutils import Vector

PROJECT = Path(__file__).resolve().parent.parent
PACK = Path('/home/allister/Projects/mcp-for-blender/output/ps3_character_pack')


def refresh(assets=("alien_suit", "female_scientist", "robot")):
    assert Path(bpy.data.filepath) == PACK/'ps3_character_lineup.blend'
    namespace = dict(bpy=bpy, math=math, json=json, random=random, np=np,
                     Path=Path, Vector=Vector, OUT=PACK, scene=bpy.context.scene,
                     M={m.name:m for m in bpy.data.materials}, COL=None, PARTS=[])
    source = ast.parse((PACK/'build_characters.py').read_text())
    definitions = ast.Module(body=[n for n in source.body if isinstance(n, ast.FunctionDef)], type_ignores=[])
    exec(compile(definitions, str(PACK/'build_characters.py'), 'exec'), namespace)
    report=[]
    for slug, prefix, function, x in [
        ('alien_suit','01 •','alien_character',-1.48),
        ('female_scientist','02 •','scientist_character',0),
        ('robot','03 •','robot_character',1.48),
    ]:
        if slug not in assets:
            continue
        collection=next(c for c in bpy.data.collections if c.name.startswith(prefix))
        for obj in list(collection.objects):bpy.data.objects.remove(obj,do_unlink=True)
        bpy.data.collections.remove(collection)
        random.seed(17)
        collection,rig,obj=namespace[function]()
        collection.hide_render=False
        namespace['active'](obj);rig.select_set(True)
        for destination in [PACK/(slug+'.glb'), PROJECT/'assets/characters'/(slug+'.glb')]:
            bpy.ops.export_scene.gltf(filepath=str(destination),export_format='GLB',
                                      use_selection=True,export_animations=False,
                                      export_skins=True,export_yup=True,
                                      export_apply=False,export_extras=True)
        rig.location.x=x
        obj['fit_revision']='2026-10-14 clothing and forearm fit'
        obj.data.calc_loop_triangles()
        report.append(dict(asset=slug,vertices=len(obj.data.vertices),
                           triangles=len(obj.data.loop_triangles),materials=len(obj.data.materials)))
    manifest=json.loads((PACK/'manifest.json').read_text())
    for row in manifest['characters']:
        entry=next((r for r in report if r['asset']==row['asset']), None)
        if entry:
            row.update(entry)
    (PACK/'manifest.json').write_text(json.dumps(manifest,indent=2))
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(PACK/'ps3_character_lineup.blend'),compress=True)
    return {'saved':bpy.data.filepath,'characters':report}
