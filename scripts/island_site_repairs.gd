extends Node3D
## Small terrain additions and imported-material corrections, kept separate from the map.
const BANKS=preload("res://assets/bridge_landing_banks.glb")
const MANIFEST="res://assets/island_site_repairs.json"
const APPROACH_TERRAIN=preload("res://assets/bridge_approach_terrain.glb")
const APPROACH_REPAIRS="res://assets/bridge_approach_repairs.json"
const FORECOURT_ROCK=preload("res://assets/forecourt_rock_grounded.glb")
const STAIR_POT_LEAVES=preload("res://assets/stair_pot_leaves.glb")
const POOL_FINISH=preload("res://assets/temple_pool_finish.glb")
const COAST_OUTFLOW=preload("res://assets/coast_outflow_detail.glb")
const TEMPLE_CROWN=preload("res://assets/temple_crown_detail.glb")
const TEMPLE_DETAIL=preload("res://assets/temple_architecture_detail.glb")
const COUCH_PILLOWS=preload("res://assets/couch_pillows.glb")
const BOWL_OUTLET=preload("res://assets/bowl_outlet_detail.glb")
const LAB_DETAIL=preload("res://assets/lab_prop_detail.glb")
const TERRACE_GUARD=preload("res://assets/temple_terrace_guard.glb")
const OFFSHORE_SPECTRUM=preload("res://assets/offshore_spectrum.glb")
const CLEARANCE_PLAN="res://assets/temple_clearance.json"
var moved_trees:Array=[]
var repaired_rocks:Array=[]
func _ready()->void:
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST));var map=get_parent().get_node("TempleMap")
 _install_bridge_approaches(map)
 _install_grounded_rock(map)
 _install_repaired_leaves(map)
 _install_pool_finish(map)
 _install_temple_detail(map)
 _install_temple_crown(map)
 _install_coast_outflow(map)
 _install_lab_detail(map)
 _install_interior_repairs(map)
 _install_terrace_guard()
 _install_temple_clearance(map)
 for row in data.trees:
  var tree=map.get_node_or_null(NodePath(row.name));assert(tree,"Missing relocated tree "+row.name)
  tree.position=Vector3(row.position[0],row.position[1],row.position[2]);moved_trees.append(tree)
 for name:String in data.get("removed_trees",[]):
  var tree:Node3D=map.get_node_or_null(NodePath(name))
  if tree:
   tree.visible=false
   tree.position=Vector3(0,-1000,0)
   for col in tree.find_children("*","CollisionShape3D",true,false):col.disabled=true
 var materials:Dictionary={}
 for row in data.rocks:
  var rock:MeshInstance3D=map.get_node_or_null(NodePath(row.name));assert(rock,"Missing weathered rock "+row.name)
  if row.has("position"):
   rock.position=Vector3(row.position[0],row.position[1],row.position[2]);rock.scale=Vector3(row.scale[0],row.scale[1],row.scale[2])
  if not materials.has(row.variant):
   var material:=StandardMaterial3D.new();material.resource_name="Portable_Coastal_Rock_"+row.variant
   material.albedo_texture=load("res://assets/textures/coastal_rock_"+row.variant+".jpg")
   material.roughness=.92;material.metallic_specular=.2;material.uv1_triplanar=true;material.uv1_world_triplanar=true;material.uv1_scale=Vector3.ONE*.48
   material.normal_enabled=true;material.normal_texture=load("res://assets/textures/coastal_rock_normal.png");material.normal_scale=.4
   material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
   materials[row.variant]=material
  rock.material_override=materials[row.variant];repaired_rocks.append(rock)
 var banks:Node3D=BANKS.instantiate();add_child(banks)
 var ground:=ShaderMaterial.new();ground.shader=load("res://shaders/island_ground.gdshader");ground.set_shader_parameter("meadow_texture",load("res://assets/textures/rocky_terrain_02_Diffuse_2k.jpg"))
 for mesh in banks.find_children("*","MeshInstance3D",true,false):
  mesh.material_override=ground
  var body:=StaticBody3D.new();body.name="BankCollision";mesh.add_child(body)
  var collider:=CollisionShape3D.new();collider.shape=mesh.mesh.create_trimesh_shape();body.add_child(collider)
 print("ISLAND_SITE_REPAIRS ",moved_trees.size()," approach trees, ",repaired_rocks.size()," weathered rocks, 3 full-width landing banks")

func _install_bridge_approaches(map:Node3D)->void:
 # Reuse the original node, shader hooks and collision hierarchy. Only this
 # terrain mesh is exported from Blender; the optimized base map is preserved.
 var source:Node3D=APPROACH_TERRAIN.instantiate()
 var meshes:=source.find_children("*","MeshInstance3D",true,false)
 assert(meshes.size()==1,"Expected one scoped bridge approach terrain mesh")
 var terrain:MeshInstance3D=map.get_node("Cliff_Terrain")
 terrain.mesh=meshes[0].mesh
 var shapes:=terrain.find_children("*","CollisionShape3D",true,false)
 assert(shapes.size()==1,"Expected the existing terrain collider")
 shapes[0].shape=terrain.mesh.create_trimesh_shape()
 source.free()
 var repair:Variant=JSON.parse_string(FileAccess.get_file_as_string(APPROACH_REPAIRS))
 for row in repair.grounded_props:
  var prop:Node3D=map.get_node(NodePath(row.name))
  prop.position=Vector3(row.position[0],row.position[1],row.position[2])

func _install_pool_finish(map:Node3D)->void:
 var source:Node3D=POOL_FINISH.instantiate()
 for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
  var target:MeshInstance3D=map.get_node(String(mesh.name).trim_suffix("-col"))
  target.mesh=mesh.mesh
  # The fragmented column keeps its existing collider hierarchy. Water stays
  # non-solid and receives the normal animated-water hook after installation.
  for collision:CollisionShape3D in target.find_children("*","CollisionShape3D",true,false):
   collision.shape=target.mesh.create_trimesh_shape()
 source.free()

func _install_temple_detail(map:Node3D)->void:
 # Carved stone is visual detail over the existing solid architectural shapes.
 # Keep the cheap column proxies and continuous stair/podium walking collision.
 var source:Node3D=TEMPLE_DETAIL.instantiate()
 for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
  var target:MeshInstance3D=map.get_node(String(mesh.name).trim_suffix("-col"))
  target.mesh=mesh.mesh
  for surface:int in target.mesh.get_surface_count():
   var material:StandardMaterial3D=target.mesh.surface_get_material(surface)
   # Match the constant stone tint used by the Blender material multiply node.
   if material.resource_name.ends_with("warm limestone"):material.albedo_color=Color(1.,.97,.90)
   elif material.resource_name.ends_with("pale limestone"):material.albedo_color=Color(.94,.94,.91)
   elif material.resource_name.ends_with("aged limestone"):material.albedo_color=Color(.87,.87,.82)
   material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 source.free()

func _install_temple_crown(map:Node3D)->void:
 var source:Node3D=TEMPLE_CROWN.instantiate()
 var meshes:=source.find_children("*","MeshInstance3D",true,false)
 assert(meshes.size()==1)
 var target:MeshInstance3D=map.get_node("Temple_Entablature")
 target.mesh=meshes[0].mesh
 for i:int in target.mesh.get_surface_count():
  var material:StandardMaterial3D=target.mesh.surface_get_material(i)
  material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 source.free()

func _install_grounded_rock(map:Node3D)->void:
 # This scoped export keeps the original map, material and node references.
 var source:Node3D=FORECOURT_ROCK.instantiate();add_child(source)
 var meshes:=source.find_children("*","MeshInstance3D",true,false)
 assert(meshes.size()==1,"Expected one fitted forecourt boulder")
 var rock:MeshInstance3D=map.get_node("Large_Rock_Main_02")
 rock.mesh=meshes[0].mesh;rock.global_transform=meshes[0].global_transform
 var shapes:=rock.find_children("*","CollisionShape3D",true,false)
 assert(shapes.size()==1,"Expected the existing rock collider")
 shapes[0].shape=rock.mesh.create_convex_shape(true,true)
 source.free()

func _install_repaired_leaves(map:Node3D)->void:
 var source:Node3D=STAIR_POT_LEAVES.instantiate()
 var meshes:=source.find_children("*","MeshInstance3D",true,false)
 assert(meshes.size()==1,"Expected one repaired pot leaves mesh")
 var repaired_mesh:Mesh=meshes[0].mesh
 for name in ["Pot_Stairs_Bot_R_leaves","Pot_Stairs_Bot_L_leaves","Pot_Pool_2_leaves"]:
  var node:MeshInstance3D=map.get_node_or_null(NodePath(name))
  if node:
   var orig_mat:Material=node.mesh.surface_get_material(0)
   node.mesh=repaired_mesh
   if orig_mat:
    node.mesh.surface_set_material(0,orig_mat)
 source.free()

func _install_coast_outflow(map:Node3D)->void:
 var source:Node3D=COAST_OUTFLOW.instantiate()
 for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
  var target_name:String="Lab_Centrifuge_RPM" if mesh.name=="Idle_Centrifuge_Digits" else String(mesh.name)
  var target:MeshInstance3D=map.get_node(target_name)
  target.mesh=mesh.mesh
 source.free()

func _install_lab_detail(map:Node3D)->void:
 # The original base keeps its small collision proxy. Replace only the visible
 # optical instrument and shelf vessels, leaving benches and the room intact.
 for mesh:MeshInstance3D in map.find_children("*","MeshInstance3D",true,false):
  var label:=String(mesh.name)
  if label.begins_with("Lab_Microscope_") or label.begins_with("Lab_Reagent_Bottle") or label.begins_with("Lab_Bottle_Cap") or label.begins_with("Lab_Bottle_Label") or label=="Lab_Glass_Slide":
   mesh.visible=false
 var source:Node3D=LAB_DETAIL.instantiate()
 source.name="LabPropDetail"
 map.add_child(source)

func _install_interior_repairs(map:Node3D)->void:
 for asset:PackedScene in [COUCH_PILLOWS,BOWL_OUTLET]:
  var source:Node3D=asset.instantiate()
  for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
   var target:MeshInstance3D=map.get_node(String(mesh.name).trim_suffix("-col"))
   target.mesh=mesh.mesh
   target.transform=mesh.transform
   for shape:CollisionShape3D in target.find_children("*","CollisionShape3D",true,false):
    if String(target.name).contains("Pillow"):
     # Soft cushions use the existing solid couch seat/back, avoiding tiny snags.
     shape.disabled=true
    else:
     shape.shape=target.mesh.create_trimesh_shape()
   for i:int in target.mesh.get_surface_count():
    var material:Material=target.mesh.surface_get_material(i)
    if material is StandardMaterial3D:
     material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  source.free()

func _install_terrace_guard()->void:
 var source:Node3D=TERRACE_GUARD.instantiate()
 source.name="TempleTerraceGuard"
 add_child(source)
 # The old concave beam caught the capsule against its underside after a
 # landing. Continuous solid boxes have one upward-facing top and no pockets.
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CLEARANCE_PLAN))
 var body:=StaticBody3D.new()
 body.name="ContinuousRailCollision"
 source.add_child(body)
 for row:Dictionary in plan.guard_boxes:
  var collision:=CollisionShape3D.new()
  var shape:=BoxShape3D.new()
  shape.size=Vector3(row.size[0],row.size[1],row.size[2])
  collision.shape=shape
  collision.position=Vector3(row.center[0],row.center[1],row.center[2])
  body.add_child(collision)

func _install_temple_clearance(map:Node3D)->void:
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(CLEARANCE_PLAN))
 for label:String in plan.removed_props:
  var plant:Node3D=map.get_node(NodePath(label))
  plant.hide()
  for shape:CollisionShape3D in plant.find_children("*","CollisionShape3D",true,false):shape.disabled=true
 for label:String in plan.positions:
  var p:Array=plan.positions[label]
  map.get_node(NodePath(label)).position=Vector3(p[0],p[1],p[2])
 var source:Node3D=OFFSHORE_SPECTRUM.instantiate()
 for mesh:MeshInstance3D in source.find_children("*","MeshInstance3D",true,false):
  var target:MeshInstance3D=map.get_node(String(mesh.name).trim_suffix("-col"))
  target.mesh=mesh.mesh
  target.transform=mesh.transform
  # Scoped eroded stone keeps its original broad, cheap offshore collision.
  target.material_override=null
  for surface:int in target.mesh.get_surface_count():
   var material:StandardMaterial3D=target.mesh.surface_get_material(surface)
   material.vertex_color_use_as_albedo=true
   material.albedo_texture=load("res://assets/textures/coastal_rock_grey.jpg")
   material.albedo_color=Color.WHITE
   material.roughness=.90
   material.metallic=.02
   material.metallic_specular=.2
   material.normal_enabled=true
   material.normal_texture=load("res://assets/textures/coastal_rock_normal.png")
   material.normal_scale=.8
   material.uv1_triplanar=true
   material.uv1_world_triplanar=true
   material.uv1_scale=Vector3.ONE*.45
   material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 source.free()
