"""Original hand-sized survey reader, authored beside the character lineup.

Screen faces Blender -Y / Godot +Z, long edge points up in Godot. Its runtime
attachment follows the scientist's hand bone during the draw/read/stow task.
"""
from pathlib import Path
import bpy

PROJECT=Path(__file__).resolve().parent.parent
PACK=Path('/home/allister/Projects/mcp-for-blender/output/ps3_character_pack')


def build_and_export():
    # A separate library cannot alter any character mesh or presentation scene.
    for obj in list(bpy.data.objects):bpy.data.objects.remove(obj,do_unlink=True)
    def material(name,color,metal=0.,rough=.5,emit=0.):
        mat=bpy.data.materials.new(name);mat.use_nodes=True
        p=mat.node_tree.nodes.get('Principled BSDF')
        p.inputs['Base Color'].default_value=(*color,1.)
        p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
        if emit:
            p.inputs['Emission Color'].default_value=(*color,1.)
            p.inputs['Emission Strength'].default_value=emit
        return mat
    shell=material('Survey reader | charcoal rubber',(.022,.038,.047),.15,.65)
    rim=material('Survey reader | brushed bronze',(.20,.25,.24),.65,.38)
    screen=material('Survey reader | dark teal display',(.012,.075,.09),.1,.25,.4)
    cyan=material('Survey reader | cyan readings',(.13,.72,.74),.05,.45,.7)
    white=material('Survey reader | display labels',(.62,.85,.77),0.,.5,.35)
    def box(name,center,size,mat,bevel=.001):
        bpy.ops.mesh.primitive_cube_add(size=1,location=center)
        o=bpy.context.object;o.name=name;o.scale=size
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        o.data.materials.append(mat)
        if bevel:
            mod=o.modifiers.new('Rounded casing','BEVEL');mod.width=bevel;mod.segments=3
            bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
        return o
    # (x, y depth, z height); converted to +Z-front portable asset on export.
    box('PalmPad_Case',(0,0,0),(.132,.016,.188),shell,.007)
    box('PalmPad_Rim',(0,-.008,0),(.121,.004,.176),rim,.005)
    box('PalmPad_Screen',(0,-.011,.005),(.103,.002,.145),screen,.004)
    box('PalmPad_Header',(-.009,-.0125,.066),(.068,.001,.004),white,.0005)
    for j,length in enumerate([.040,.026,.035]):
        box('PalmPad_Reading_%d'%j,(-.026+length/2,-.0125,.049-j*.010),(length,.001,.003),cyan,.0005)
    # A small water-quality graph and three bottom keys make the prop legible.
    for j,height in enumerate([.012,.021,.017,.035,.028,.044,.039]):
        box('PalmPad_Graph_%d'%j,(-.035+j*.011,-.0125,-.040+height/2),(.006,.001,height),cyan,.0005)
    for j in range(3):box('PalmPad_Key_%d'%j,((j-1)*.025,-.011,-.078),(.015,.002,.006),white,.001)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(PROJECT/'assets/characters/palm_pad.glb'),
        export_format='GLB',use_selection=True,export_animations=False)
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(PACK/'scientist_palm_pad.blend'),compress=True)
    return {'saved':bpy.data.filepath,'meshes':len(bpy.data.objects),'size_m':[.132,.188,.016]}
