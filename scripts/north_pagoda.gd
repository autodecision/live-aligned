extends Node3D
## Independent, batched landmark and island addition; all collision stays simple.
const MODEL=preload("res://assets/north_pagoda.glb")
const PLAN="res://assets/north_pagoda.json"
var lights:Array[OmniLight3D]=[]
var glow:StandardMaterial3D
var plan:Dictionary
func vector(a:Array)->Vector3:return Vector3(a[0],a[2],-a[1])
func _ready()->void:
 plan=JSON.parse_string(FileAccess.get_file_as_string(PLAN))
 var model:Node3D=MODEL.instantiate();add_child(model)
 var ground:=ShaderMaterial.new();ground.shader=load("res://shaders/island_ground.gdshader");ground.set_shader_parameter("meadow_texture",load("res://assets/textures/rocky_terrain_02_Diffuse_2k.jpg"))
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if "Meadow_Ground" in String(mesh.name):
   mesh.material_override=ground
   var land_body:=StaticBody3D.new();land_body.name="NorthIslandGround";mesh.add_child(land_body)
   var collision:=CollisionShape3D.new();collision.shape=mesh.mesh.create_trimesh_shape();land_body.add_child(collision)
  else:
   for i in mesh.mesh.get_surface_count():
    var material=mesh.mesh.surface_get_material(i)
    if material is StandardMaterial3D:material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   if "Lantern_Glow" in String(mesh.name):
    glow=mesh.mesh.surface_get_material(0).duplicate();glow.emission_enabled=true;glow.emission=Color(1,.60,.23);mesh.material_override=glow
 var body:=StaticBody3D.new();body.name="PagodaStructure";add_child(body)
 for row in plan.colliders:
  var collision:=CollisionShape3D.new()
  if row.type=="box":
   var shape:=BoxShape3D.new();shape.size=Vector3(row.size[0],row.size[2],row.size[1]);collision.shape=shape;collision.position=vector(row.center);collision.rotation.y=row.yaw
  elif row.type=="cylinder":
   var shape:=CylinderShape3D.new();shape.radius=row.radius;shape.height=row.height;collision.shape=shape;collision.position=vector(row.center)
  elif row.type=="trimesh":
   var shape:=ConcavePolygonShape3D.new();var faces:=PackedVector3Array()
   # Blender uses counterclockwise faces; Godot physics uses clockwise.
   for i in range(0,row.faces.size(),3):
    faces.append(vector(row.faces[i+2]));faces.append(vector(row.faces[i+1]));faces.append(vector(row.faces[i]))
   shape.set_faces(faces);collision.shape=shape
  else:
   var shape:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
   for point in row.points:points.append(vector(point))
   shape.points=points;collision.shape=shape
  body.add_child(collision)
 for p in plan.lights:
  var light:=OmniLight3D.new();light.position=Vector3(p[0],p[1],p[2]);light.light_color=Color(1,.64,.30);light.omni_range=7.;light.shadow_enabled=false;light.distance_fade_enabled=true;light.distance_fade_begin=25.;light.distance_fade_length=12.;add_child(light);lights.append(light)
 set_night_strength(0.)
 # Keep a modest sea margin around the newly enlarged island. Only the sea's
 # horizontal transform changes; AnimatedWater still owns its existing shader.
 var sea:MeshInstance3D=get_parent().get_node("TempleMap/Mediterranean_Sea")
 var bounds:AABB=sea.global_transform*sea.get_aabb()
 var sx:float=(maxf(plan.sea_target_max_x,bounds.end.x)-bounds.position.x)/bounds.size.x
 var sz:float=(bounds.end.z-minf(-plan.sea_target_max_blender_y,bounds.position.z))/bounds.size.z
 var transform_world:=Transform3D(Basis.from_scale(Vector3(sx,1,sz)),Vector3(bounds.position.x*(1-sx),0,bounds.end.z*(1-sz)))
 sea.global_transform=transform_world*sea.global_transform
 print("NORTH_PAGODA 3 accessible floors; two spiral flights, cleared stone path, ",lights.size()," night lanterns")
func set_night_strength(value:float)->void:
 if glow:glow.emission_energy_multiplier=lerpf(.03,3.4,clampf(value,0,1))
 for light in lights:light.light_energy=1.5*value;light.visible=value>.001
