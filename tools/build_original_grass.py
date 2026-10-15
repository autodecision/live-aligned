"""Original Live Aligned grass, authored from mathematical blade shapes in Blender.

Run through Blender MCP by importing this module and calling build_library(),
then install_into_loaded_source() for each authoritative scene. No input assets,
images, botanical scans, or third-party meshes are used by the generator.
"""
import bpy
import json
import math
import random
from pathlib import Path
from mathutils import Vector


ASSETS = ("LA_Grass_ShortSward", "LA_Grass_MeadowTuft", "LA_Grass_DrySeedHead")


def replacement(name):
    # Retain the old object/placement keys: geometry nodes and saved plans use them.
    if name.startswith("GScatter_ShortSward_"):
        return ASSETS[0], 1.0
    if name.startswith("GScatter_LoliumPerenne_"):
        return ASSETS[1], 0.40
    if name.startswith("GScatter_TrisetumFlavescens_"):
        return ASSETS[1], 1.0
    if name.startswith("GScatter_BromusSterilis_"):
        return ASSETS[2], 1.0
    raise ValueError(name)


class Plant:
    def __init__(self, seed):
        self.rng = random.Random(seed)
        self.vertices, self.faces, self.colors = [], [], []

    def vertex(self, point, color):
        self.vertices.append(tuple(point))
        self.colors.append((*color, 1.0))
        return len(self.vertices) - 1

    def blade(self, root, height, width, yaw, lean, dry=False):
        """A folded, tapered ribbon with a curved silhouette, never an alpha card."""
        forward = Vector((math.cos(yaw), math.sin(yaw), 0))
        side = Vector((-math.sin(yaw), math.cos(yaw), 0))
        root = Vector(root)
        tint = self.rng.uniform(.82, 1.16)
        base = Vector((.070, .120, .022) if not dry else (.135, .115, .040))
        tip = Vector((.265, .355, .105) if not dry else (.43, .335, .14))
        sections = []
        for t, taper in [(0., .64), (.52, .78)]:
            center = root + forward * (lean * t * t) + Vector((0, 0, height*t))
            color = base.lerp(tip, t) * tint
            w = width * taper * .5
            left = self.vertex(center-side*w, color*.92)
            ridge = self.vertex(center+forward*width*.18, color*1.08)
            right = self.vertex(center+side*w, color)
            sections.append((left, ridge, right))
        a, b = sections
        self.faces.extend([(a[0], a[1], b[1], b[0]), (a[1], a[2], b[2], b[1])])
        point = self.vertex(root+forward*lean+Vector((0, 0, height)), tip*tint)
        self.faces.extend([(b[0], b[1], point), (b[1], b[2], point)])

    def stem(self, start, end, radius):
        start, end = Vector(start), Vector(end)
        axis = (end-start).normalized()
        side = axis.cross(Vector((0, 1, 0))).normalized()
        other = axis.cross(side)
        color = Vector((.31, .265, .105))*self.rng.uniform(.85, 1.15)
        rings = []
        for center, r in [(start, radius), (end, radius*.68)]:
            rings.append([self.vertex(center+r*(math.cos(a)*side+math.sin(a)*other), color)
                          for a in (0, math.tau/3, math.tau*2/3)])
        for i in range(3):
            j = (i+1) % 3
            self.faces.append((rings[0][i], rings[0][j], rings[1][j], rings[1][i]))

    def seed(self, center, yaw, length, width):
        # Solid pointed spikelet; colors and all silhouette details are geometry.
        c = Vector(center)
        up = Vector((math.cos(yaw)*.45, math.sin(yaw)*.45, 1)).normalized()
        side = Vector((-math.sin(yaw), math.cos(yaw), 0))
        depth = up.cross(side)
        color = Vector((.48, .365, .15))*self.rng.uniform(.8, 1.16)
        ids = [self.vertex(c-up*length*.5, color*.8), self.vertex(c+up*length*.5, color*1.12)]
        ids += [self.vertex(c+v*width, color) for v in [side, depth*.55, -side, -depth*.55]]
        for i in range(4):
            a, b = ids[2+i], ids[2+(i+1)%4]
            self.faces.extend([(ids[0], b, a), (ids[1], a, b)])

    def object(self, name, material):
        mesh = bpy.data.meshes.new(name+"_Mesh")
        mesh.from_pydata(self.vertices, [], self.faces)
        mesh.update()
        colors = mesh.color_attributes.new(name="GrassColor", type="FLOAT_COLOR", domain="POINT")
        for item, color in zip(colors.data, self.colors):
            item.color = color
        mesh.color_attributes.active_color = colors
        mesh.materials.append(material)
        obj = bpy.data.objects.new(name, mesh)
        bpy.context.scene.collection.objects.link(obj)
        obj["provenance"] = "Original procedural Live Aligned geometry; no source assets or textures"
        return obj


def build_library(blend_path, glb_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    material = bpy.data.materials.new("Live Aligned Original Grass")
    material.use_nodes = True
    material.diffuse_color = (1, 1, 1, 1)
    material.use_backface_culling = False
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs['Roughness'].default_value = .91
    bsdf.inputs['Specular IOR Level'].default_value = .18
    color_node = material.node_tree.nodes.new('ShaderNodeVertexColor')
    color_node.layer_name = 'GrassColor'
    material.node_tree.links.new(color_node.outputs['Color'], bsdf.inputs['Base Color'])
    objects = []
    for kind, name in enumerate(ASSETS):
        plant = Plant(83017+kind)
        count = [20, 18, 9][kind]
        for i in range(count):
            yaw = i*2.399963+plant.rng.uniform(-.3, .3)
            r = math.sqrt(plant.rng.random()) * [.225, .065, .025][kind]
            root = (r*math.cos(yaw), r*math.sin(yaw), 0)
            h = plant.rng.uniform(*[(.075, .19), (.15, .32), (.12, .26)][kind])
            plant.blade(root, h, plant.rng.uniform(.009, .018) if kind == 0 else plant.rng.uniform(.009, .021),
                        yaw+plant.rng.uniform(-.6, .6), h*plant.rng.uniform(.18, .45), dry=(kind==2 and i%3==0))
        if kind == 2:
            for i in range(5):
                yaw = i*2.399963
                height = plant.rng.uniform(.40, .59)
                bend = Vector((math.cos(yaw)*.047, math.sin(yaw)*.047, height))
                mid = bend*.54
                mid.z = height*.57
                plant.stem((0, 0, 0), mid, .002)
                plant.stem(mid, bend, .0017)
                for j in range(6):
                    t = .70+j*.047
                    center = bend*t
                    center += Vector((math.cos(yaw+j*2.4)*.010, math.sin(yaw+j*2.4)*.010, 0))
                    plant.seed(center, yaw+j*2.4, .024, .0055)
        objects.append(plant.object(name, material))
    # Export only the three plants; the studio never enters the runtime asset.
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.export_scene.gltf(filepath=str(glb_path), export_format='GLB', use_selection=True,
                             export_materials='EXPORT', export_vertex_color='ACTIVE', export_yup=True)
    for obj, x in zip(objects, [-.65, 0, .65]):
        obj.location.x = x
    bpy.context.scene.unit_settings.system = 'METRIC'
    # A separate presentation scene keeps the editable library free of studio props.
    library = bpy.context.scene
    library.name = 'Original Grass Library'
    studio = bpy.data.scenes.new('Grass Preview')
    for obj in objects:
        studio.collection.objects.link(obj)
    camera_data = bpy.data.cameras.new('Grass Preview Camera')
    camera = bpy.data.objects.new('Grass Preview Camera', camera_data)
    studio.collection.objects.link(camera)
    camera.location = (1.15, -2.4, 1.4)
    camera.rotation_euler = (Vector((0, 0, .24))-camera.location).to_track_quat('-Z', 'Y').to_euler()
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 2.1
    studio.camera = camera
    world = bpy.data.worlds.new('Grass Studio World')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs[0].default_value = (.15, .17, .13, 1)
    world.node_tree.nodes['Background'].inputs[1].default_value = .5
    studio.world = world
    light_data = bpy.data.lights.new('Grass Studio Softbox', 'AREA')
    light_data.energy = 160
    light_data.shape = 'DISK'
    light_data.size = 3
    light = bpy.data.objects.new('Grass Studio Softbox', light_data)
    studio.collection.objects.link(light)
    light.location = (0, -1, 2)
    light.rotation_euler = (Vector((0, 0, 0))-light.location).to_track_quat('-Z', 'Y').to_euler()
    studio.render.engine = 'CYCLES'
    studio.cycles.samples = 32
    studio.render.resolution_x = 1600
    studio.render.resolution_y = 900
    studio.render.resolution_percentage = 100
    studio.view_settings.view_transform = 'AgX'
    bpy.context.window.scene = studio
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    report = {'provenance': 'Original mathematical geometry and vertex colors; no external inputs',
              'generator': 'tools/build_original_grass.py', 'textures': 0, 'materials': 1,
              'meshes': {o.name: {'vertices': len(o.data.vertices),
                                 'triangles': sum(len(p.vertices)-2 for p in o.data.polygons)} for o in objects}}
    Path(glb_path).with_name('original_grass_manifest.json').write_text(json.dumps(report, indent=2)+'\n')
    return report


def install_into_loaded_source(library_path):
    targets = [o for o in bpy.data.objects if o.name.startswith('GScatter_') and o.type == 'MESH' and not o.modifiers]
    assert len(targets) == 10, [o.name for o in targets]
    with bpy.data.libraries.load(str(library_path), link=False) as (available, loaded):
        loaded.meshes = [name+'_Mesh' for name in ASSETS]
    meshes = dict(zip(ASSETS, loaded.meshes))
    scaled_tuft = meshes[ASSETS[1]].copy()
    scaled_tuft.name = 'LA_Grass_MeadowTuft_Compact_Mesh'
    for vertex in scaled_tuft.vertices:
        vertex.co *= .40
    old_meshes = set(o.data for o in targets)
    old_materials = set(m for mesh in old_meshes for m in mesh.materials if m)
    old_images = set(n.image for mat in old_materials if mat.use_nodes for n in mat.node_tree.nodes
                     if n.type == 'TEX_IMAGE' and n.image)
    for obj in targets:
        name, scale = replacement(obj.name)
        obj.data = scaled_tuft if scale == .40 else meshes[name]
        obj['original_grass_asset'] = name
        obj['provenance'] = 'Original Live Aligned procedural grass'
    # Remove only the replaced, now-unused vegetation data, including packed scans.
    for mesh in old_meshes:
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for mat in old_materials:
        if mat.users == 0:
            bpy.data.materials.remove(mat)
    for image in old_images:
        if image.users == 0:
            bpy.data.images.remove(image)
    bpy.context.scene['grass_provenance'] = 'Original Live Aligned grass generated via Blender MCP'
    bpy.context.view_layer.update()
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=bpy.data.filepath)
    return {'saved': bpy.data.filepath, 'replaced_sources': len(targets),
            'shared_original_meshes': len(set(o.data.name for o in targets)),
            'retained_meadow_distributions': len([o for o in bpy.data.objects if o.name.endswith('_Meadow')])}
