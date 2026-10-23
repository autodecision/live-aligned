extends Node3D
## Independent south-island addition. The base map and its shared assets stay intact.
const MODEL = preload("res://assets/south_garden.glb")
const TERRAIN = preload("res://assets/south_garden_terrain.glb")
const KOI = preload("res://assets/south_garden_koi.glb")
var plan:Dictionary
var fish:Array[Dictionary] = []
var lights:Array[OmniLight3D] = []
var glow:StandardMaterial3D
var water:ShaderMaterial
var koi_material:ShaderMaterial
var elapsed:float = 0.0

func _ready()->void:
 plan = JSON.parse_string(FileAccess.get_file_as_string("res://assets/south_garden.json"))
 _install_ground()
 _finish_prop_clearances()
 var model:Node3D = MODEL.instantiate()
 model.name = "Garden"
 add_child(model)
 water = ShaderMaterial.new()
 water.shader = preload("res://shaders/koi_pond.gdshader")
 var sand:=ShaderMaterial.new()
 sand.shader = preload("res://shaders/zen_sand.gdshader")
 var rock_mat:=StandardMaterial3D.new()
 rock_mat.albedo_texture = preload("res://assets/textures/coastal_rock_grey.jpg")
 rock_mat.normal_enabled = true
 rock_mat.normal_texture = preload("res://assets/textures/coastal_rock_normal.png")
 rock_mat.uv1_triplanar = true
 rock_mat.uv1_scale = Vector3(0.4,0.4,0.4)
 rock_mat.roughness = 0.88
 var surfaces:Dictionary = {}
 for key:String in ["Edge_Stone","Dark_Stone","Contemplation_Rock","Gravel","Pond_Lining","Wood","Moss"]:
  var surface:=ShaderMaterial.new()
  surface.shader = preload("res://shaders/garden_surface.gdshader")
  var palette:Dictionary = {"Edge_Stone":Vector3(.14,.15,.13),"Dark_Stone":Vector3(.065,.082,.078),"Contemplation_Rock":Vector3(.095,.11,.09),"Gravel":Vector3(.32,.29,.23),"Pond_Lining":Vector3(.17,.22,.18),"Wood":Vector3(.22,.105,.043),"Moss":Vector3(.10,.17,.045)}
  surface.set_shader_parameter("base_color",palette[key])
  surface.set_shader_parameter("wood",key=="Wood")
  surface.set_shader_parameter("weathered_stone",key=="Contemplation_Rock" or key=="Edge_Stone")
  surface.set_shader_parameter("pebbles",key=="Pond_Lining" or key=="Gravel")
  surfaces[key] = surface
 for mesh:MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
  if "Pond_Water" in String(mesh.name):
   mesh.material_override = water
   mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  elif String(mesh.name).ends_with("Gravel"):
   var paving:StandardMaterial3D = mesh.mesh.surface_get_material(0)
   paving.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   mesh.material_override = paving
   mesh.lod_bias = 10000.0
   mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  elif "Zen_Sand" in String(mesh.name):
   mesh.material_override = sand
  elif "Contemplation_Rock" in String(mesh.name):
   mesh.material_override = rock_mat
  elif "Lantern_Glow" in String(mesh.name):
   glow = mesh.mesh.surface_get_material(0).duplicate()
   glow.emission_enabled = true
   glow.emission = Color(1.0,.59,.24)
   mesh.material_override = glow
  elif "Reed" in String(mesh.name) or "Lily" in String(mesh.name) or "Blossom" in String(mesh.name):
   var material:StandardMaterial3D = mesh.mesh.surface_get_material(0).duplicate()
   material.cull_mode = BaseMaterial3D.CULL_DISABLED
   mesh.material_override = material
  else:
   for key:String in surfaces:
    if String(mesh.name).ends_with(key):mesh.material_override = surfaces[key]
 var body:=StaticBody3D.new()
 body.name = "GardenStructure"
 add_child(body)
 for row:Dictionary in plan.colliders:
  var collision:=CollisionShape3D.new()
  if row.type == "box":
   var shape:=BoxShape3D.new()
   shape.size = Vector3(row.size[0],row.size[2],row.size[1])
   collision.shape = shape
   collision.position = Vector3(row.center[0],row.center[2],-row.center[1])
   collision.rotation.y = row.yaw
  else:
   var lining:MeshInstance3D = model.find_child(row.name,true,false)
   assert(lining != null)
   collision.shape = lining.mesh.create_trimesh_shape()
  body.add_child(collision)
 for p:Array in plan.lights:
  var light:=OmniLight3D.new()
  light.position = Vector3(p[0],p[1],p[2])
  light.light_color = Color(1.0,.68,.36)
  light.omni_range = 8.0
  light.shadow_enabled = false
  light.distance_fade_enabled = true
  light.distance_fade_begin = 32.0
  light.distance_fade_length = 15.0
  add_child(light)
  lights.append(light)
 _make_fish()
 _extend_sea()
 set_night_strength(0.0)
 print("SOUTH_GARDEN expanded walkable island; pond with ",fish.size()," koi; raked sand garden; ",lights.size()," stone lanterns")

func _install_ground()->void:
 var source:Node3D = TERRAIN.instantiate()
 var meshes:=source.find_children("*","MeshInstance3D",true,false)
 assert(meshes.size() == 3)
 var ground:=ShaderMaterial.new()
 ground.shader = preload("res://shaders/island_ground.gdshader")
 ground.set_shader_parameter("meadow_texture",load("res://assets/textures/rocky_terrain_02_Diffuse_2k.jpg"))
 for mesh:MeshInstance3D in meshes:
  var target:MeshInstance3D
  var target_name:String = String(mesh.name).trim_prefix("SouthGarden_")
  if target_name == "Distant_Islands":target = get_parent().get_node("TempleMap/Distant_Islands")
  else:target = get_parent().get_node("IslandSiteRepairs").find_child(target_name,true,false)
  assert(target != null)
  target.mesh = mesh.mesh
  target.material_override = ground
  var shapes:=target.find_children("*","CollisionShape3D",true,false)
  assert(shapes.size() == 1)
  shapes[0].shape = target.mesh.create_trimesh_shape()
 source.free()
 get_parent().get_node("NorthPagoda").install_coastal_base()
 for row:Dictionary in plan.grounded_props:
  var prop:Node3D = get_parent().get_node("TempleMap/"+row.name)
  prop.position = Vector3(row.position[0],row.position[1],row.position[2])

func _extend_sea()->void:
 var sea:MeshInstance3D = get_parent().get_node("TempleMap/Mediterranean_Sea")
 var bounds:AABB = sea.global_transform*sea.get_aabb()
 var sx:float = (maxf(plan.sea_max_x,bounds.end.x)-bounds.position.x)/bounds.size.x
 var sz:float = (maxf(plan.sea_max_godot_z,bounds.end.z)-bounds.position.z)/bounds.size.z
 sea.global_transform = Transform3D(Basis.from_scale(Vector3(sx,1.0,sz)),Vector3(bounds.position.x*(1.0-sx),0,bounds.position.z*(1.0-sz)))*sea.global_transform

func _make_fish()->void:
 var library:Node3D = KOI.instantiate()
 var meshes:Array[Mesh] = []
 for variety:String in ["Koi_Kohaku","Koi_Sanke","Koi_Gold"]:
  var source:MeshInstance3D = library.find_child(variety,true,false)
  assert(source != null)
  meshes.append(source.mesh)
 koi_material = ShaderMaterial.new()
 koi_material.shader = preload("res://shaders/koi_swim.gdshader")
 for i:int in range(int(plan.pond.koi_count)):
  var instance:=MeshInstance3D.new()
  instance.name = "Koi_%02d"%(i+1)
  instance.mesh = meshes[i%3]
  instance.material_override = koi_material
  instance.scale = Vector3.ONE*(1.0+.08*(i%4))
  instance.extra_cull_margin = .16
  add_child(instance)
  var random:=RandomNumberGenerator.new()
  random.seed = 510150+i*7919
  var angle:float = TAU*i/float(plan.pond.koi_count)
  var radius:float = .25+.10*(i%4)
  var state:Dictionary = {"node":instance,"random":random,"phase":i*2.39996,"timer":0.0,"goal":Vector3.ZERO,"cruise":.3,"depth":.3+.04*(i%4),"target_depth":.35,"velocity":Vector3.ZERO,"turns":0,"pauses":0}
  instance.position = Vector3(96.0+5.6*radius*cos(angle),4.42-float(state.depth),34.0+4.0*radius*sin(angle))
  _choose_fish_goal(state)
  state.velocity = (state.goal-instance.position).normalized()*.23
  fish.append(state)
  instance.rotation.y = atan2(-state.velocity.z,state.velocity.x)
  instance.set_instance_shader_parameter("fish_phase",float(state.phase))
 library.free()

func _choose_fish_goal(state:Dictionary)->void:
 var random:RandomNumberGenerator = state.random
 var instance:MeshInstance3D = state.node
 var target:=instance.position
 for attempt:int in range(12):
  var angle:float = random.randf_range(0.0,TAU)
  var radius:float = sqrt(random.randf_range(.015,.40))
  target = Vector3(96.0+5.6*radius*cos(angle),4.02,34.0+4.0*radius*sin(angle))
  if Vector2(target.x-instance.position.x,target.z-instance.position.z).length()>1.6:break
 state.goal = target
 state.turns += 1
 state.target_depth = random.randf_range(.31,.50)
 # Independently alternate cruising, short glides and occasional near-still rests.
 if random.randf()<.23:
  state.cruise = random.randf_range(.045,.11)
  state.timer = random.randf_range(2.2,4.6)
  state.pauses += 1
 else:
  state.cruise = random.randf_range(.22,.54)
  state.timer = random.randf_range(6.0,13.0)

func _fish_point(state:Dictionary,ahead:float)->Vector3:
 # Used by diagnostics to compare the body heading with its actual travel.
 return state.node.position+state.velocity*ahead

func _step_fish(delta:float)->void:
 var velocities:Array[Vector3] = []
 for state:Dictionary in fish:
  var instance:MeshInstance3D = state.node
  var p:Vector3 = instance.position
  state.timer -= delta
  if state.timer<=0.0 or Vector2(state.goal.x-p.x,state.goal.z-p.z).length()<.35:_choose_fish_goal(state)
  var toward:Vector3 = state.goal-p
  toward.y = 0.0
  var cruise:float = float(state.cruise)*(1.0+.12*sin(elapsed*.57+float(state.phase)))
  var desired:Vector3 = toward.normalized()*cruise
  # Predictive steering avoidance and vertical layering prevent collision/penetration.
  for other:Dictionary in fish:
   if other.node==instance:continue
   var separation:Vector3 = p-other.node.position
   var dist_xz:float = Vector2(separation.x, separation.z).length()
   if dist_xz<1.15 and dist_xz>.001:
    var sep_norm:=Vector3(separation.x, 0.0, separation.z).normalized()
    var rel_v:Vector3 = (state.velocity as Vector3) - (other.velocity as Vector3)
    var side:=Vector3(-rel_v.z, 0.0, rel_v.x).normalized()
    if side.dot(sep_norm) < 0.0: side = -side
    var avoid_str:float = pow(1.0-dist_xz/1.15, 1.8)
    desired += (sep_norm*0.75 + side*0.45)*avoid_str
    if dist_xz < 0.90:
     if float(state.depth) >= float(other.depth):
      state.target_depth = clampf(float(state.target_depth) + 0.08*delta, 0.28, 0.52)
     else:
      state.target_depth = clampf(float(state.target_depth) - 0.08*delta, 0.28, 0.52)
  var offset:=Vector2((p.x-96.0)/5.6,(p.z-34.0)/4.0)
  var radius:float = offset.length()
  var wall:float = smoothstep(.51,.70,radius)
  var inward:=Vector3(-offset.x/5.6,0,-offset.y/4.0).normalized()
  desired = desired.lerp(inward*.46,wall)
  desired = desired.limit_length(.66)
  velocities.append((state.velocity as Vector3).move_toward(desired,delta*lerpf(.24,.85,wall)))
 for i:int in fish.size():
  var state:Dictionary = fish[i]
  var instance:MeshInstance3D = state.node
  state.velocity = velocities[i]
  instance.position += velocities[i]*delta
  state.depth = move_toward(float(state.depth),float(state.target_depth),delta*.022)
  instance.position.y = 4.42-float(state.depth)+.014*sin(elapsed*.53+float(state.phase))
  if velocities[i].length_squared()>1.0e-10:
   instance.rotation.y = atan2(-velocities[i].z,velocities[i].x)
  instance.rotation.z = .018*sin(elapsed*.7+float(state.phase))
  instance.set_instance_shader_parameter("fish_motion",clampf(velocities[i].length()/.35,.22,1.5))
 # Hard non-penetration relaxation: ensure fish bodies never intersect
 for iter:int in range(2):
  for i:int in range(fish.size()):
   for j:int in range(i+1, fish.size()):
    var node_a:MeshInstance3D = fish[i].node
    var node_b:MeshInstance3D = fish[j].node
    var diff:Vector3 = node_a.position - node_b.position
    var d_xz:float = Vector2(diff.x, diff.z).length()
    var d_y:float = absf(node_a.position.y - node_b.position.y)
    if d_xz < 0.50 and d_y < 0.12:
     var overlap:float = 0.50 - d_xz
     var push_dir:Vector3 = Vector3(diff.x, 0.0, diff.z).normalized() if d_xz > 0.001 else Vector3(1.0, 0.0, 0.0)
     var push:Vector3 = push_dir * (overlap * 0.5)
     var pa:Vector3 = node_a.position + push
     var pb:Vector3 = node_b.position - push
     if Vector2((pa.x-96.0)/5.6, (pa.z-34.0)/4.0).length() < 0.73:
      node_a.position = pa
     if Vector2((pb.x-96.0)/5.6, (pb.z-34.0)/4.0).length() < 0.73:
      node_b.position = pb
     if node_a.position.y >= node_b.position.y:
      node_a.position.y = minf(node_a.position.y + 0.004, 4.22)
      node_b.position.y = maxf(node_b.position.y - 0.004, 3.68)
     else:
      node_a.position.y = maxf(node_a.position.y - 0.004, 3.68)
      node_b.position.y = minf(node_b.position.y + 0.004, 4.22)

func advance(delta:float)->void:
 elapsed += delta
 water.set_shader_parameter("pond_time",elapsed)
 koi_material.set_shader_parameter("swim_time",elapsed)
 # Stable steering even during a slow frame; all fish see the same position snapshot.
 var steps:int = maxi(1,ceili(delta*30.0))
 for step:int in steps:_step_fish(delta/float(steps))

func _process(delta:float)->void:
 advance(delta)

func set_night_strength(value:float)->void:
 var amount:float = clampf(value,0.0,1.0)
 if glow:glow.emission_energy_multiplier = lerpf(.02,3.0,amount)
 for light:OmniLight3D in lights:
  light.light_energy = 1.3*amount
  light.visible = amount>.001

func _finish_prop_clearances()->void:
 var map:Node3D=get_parent().get_node("TempleMap")
 for prop_name:String in plan.get("composition",{}).get("removed_props",[]):
  var prop:Node3D=map.get_node(NodePath(prop_name))
  prop.visible=false
  for shape:CollisionShape3D in prop.find_children("*","CollisionShape3D",true,false):shape.disabled=true
 var placements:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/tree_clearance_repairs.json"))
 for row:Dictionary in placements.trees:
  var tree:Node3D=map.get_node(NodePath(row.name))
  tree.position=Vector3(row.position[0],row.position[1],row.position[2])
