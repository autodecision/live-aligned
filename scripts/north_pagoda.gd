extends Node3D
## Independent, batched landmark and island addition; all collision stays simple.
const MODEL=preload("res://assets/north_pagoda.glb")
const INTERIOR=preload("res://assets/pagoda_interior.glb")
const INTERIOR_PLAN="res://assets/pagoda_interior.json"
const PLAN="res://assets/north_pagoda.json"
const SIDEWALK_GROUND=preload("res://assets/pagoda_sidewalk_terrain.glb")
const SHORE=preload("res://assets/pagoda_shore.glb")
var lights:Array[OmniLight3D]=[]
var glow:StandardMaterial3D
var plan:Dictionary
func vector(a:Array)->Vector3:return Vector3(a[0],a[2],-a[1])
func _ready()->void:
 plan=JSON.parse_string(FileAccess.get_file_as_string(PLAN))
 _install_sidewalk_ground()
 var model:Node3D=MODEL.instantiate();add_child(model)
 _install_interior()
 var ground:=ShaderMaterial.new();ground.shader=load("res://shaders/island_ground.gdshader");ground.set_shader_parameter("meadow_texture",load("res://assets/textures/rocky_terrain_02_Diffuse_2k.jpg"))
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  if "Meadow_Ground" in String(mesh.name):
   # One continuous surface replaces the old intersecting meadow/cliff shells.
   # Visible ground and player collision use the same repaired mesh.
   var shore:Node3D=SHORE.instantiate()
   var source:MeshInstance3D=shore.find_child("North_Pagoda_Pagoda_Meadow_Ground",true,false)
   assert(source!=null,"Missing repaired pagoda shoreline")
   mesh.mesh=source.mesh
   shore.free()
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
 _install_window_barriers()
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
func _install_window_barriers()->void:
 # The two enclosed rooms have lattice openings from floor + .94 to + 3.02.
 # One continuous slab per wall closes all gaps inside that visible frame and
 # overlaps its sill/lintel. The open ground-floor veranda has no windows.
 var body:=StaticBody3D.new()
 body.name="PagodaWindows"
 add_child(body)
 var yaw:float=plan.yaw
 var center:Vector3=vector(plan.center_blender)
 for level:int in range(1,plan.floor_heights.size()):
  var half:float=plan.room_halves[level]
  for side:int in range(4):
   var angle:float=-side*PI/2.0
   var x:float=-sin(angle)*half
   var y:float=cos(angle)*half
   var collider:=CollisionShape3D.new()
   collider.name="Floor%dWall%d"%[level+1,side]
   var shape:=BoxShape3D.new()
   shape.size=Vector3(half*2.0+.04,2.28,.20)
   collider.shape=shape
   collider.position=Vector3(center.x+cos(yaw)*x-sin(yaw)*y,
    plan.floor_heights[level]+1.98,center.z-sin(yaw)*x-cos(yaw)*y)
   collider.rotation.y=yaw+angle
   body.add_child(collider)
func _install_sidewalk_ground()->void:
 var source:Node3D=SIDEWALK_GROUND.instantiate()
 for mesh in source.find_children("*","MeshInstance3D",true,false):
  var target:MeshInstance3D
  if String(mesh.name).begins_with("Sidewalk_Distant_Islands"):
   target=get_parent().get_node("TempleMap/Distant_Islands")
  elif String(mesh.name).begins_with("Sidewalk_Landing_Bank_Main_North"):
   for candidate in get_parent().get_node("IslandSiteRepairs").find_children("Landing_Bank_Main_North","MeshInstance3D",true,false):target=candidate
  assert(target!=null,"Missing sidewalk ground target "+mesh.name)
  target.mesh=mesh.mesh
  var shapes:=target.find_children("*","CollisionShape3D",true,false)
  assert(shapes.size()==1,"Expected the existing sidewalk ground collider")
  shapes[0].shape=target.mesh.create_trimesh_shape()
 source.free()
 var repair:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/pagoda_sidewalk_repairs.json"))
 for row in repair.grounded_props:
  var prop:Node3D=get_parent().get_node("TempleMap/"+row.name)
  prop.position=Vector3(row.position[0],row.position[1],row.position[2])
func install_coastal_base()->void:
 # SouthGarden first installs its preserved south terrain. Finish that shared
 # node with the scoped mesh that removes only the obsolete northern shell.
 var source:Node3D=SHORE.instantiate()
 var base:MeshInstance3D=source.find_child("Pagoda_Coastal_Distant_Islands",true,false)
 assert(base!=null,"Missing pagoda coastal base")
 var target:MeshInstance3D=get_parent().get_node("TempleMap/Distant_Islands")
 target.mesh=base.mesh
 var shapes:=target.find_children("*","CollisionShape3D",true,false)
 assert(shapes.size()==1,"Expected the shared island ground collider")
 shapes[0].shape=target.mesh.create_trimesh_shape()
 source.free()
 # This landing's surface is included in the continuous north ground now.
 var bank:MeshInstance3D=get_parent().get_node("IslandSiteRepairs").find_child("Landing_Bank_Main_North",true,false)
 assert(bank!=null)
 bank.visible=false
 for shape:CollisionShape3D in bank.find_children("*","CollisionShape3D",true,false):shape.disabled=true
func set_night_strength(value:float)->void:
 if glow:glow.emission_energy_multiplier=lerpf(.03,3.4,clampf(value,0,1))
 for light in lights:light.light_energy=1.5*value;light.visible=value>.001

func _install_interior()->void:
 var furniture:Node3D=INTERIOR.instantiate()
 furniture.name="InteriorFurnishings"
 add_child(furniture)
 for mesh:MeshInstance3D in furniture.find_children("*","MeshInstance3D",true,false):
  for i:int in mesh.mesh.get_surface_count():
   var material:StandardMaterial3D=mesh.mesh.surface_get_material(i)
   material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(INTERIOR_PLAN))
 var body:=StaticBody3D.new()
 body.name="FurnitureCollision"
 furniture.add_child(body)
 for row:Dictionary in data.colliders:
  var collider:=CollisionShape3D.new()
  var shape:=BoxShape3D.new()
  shape.size=Vector3(row.size[0],row.size[2],row.size[1])
  collider.shape=shape
  collider.position=vector(row.center)
  collider.rotation.y=row.yaw
  body.add_child(collider)
