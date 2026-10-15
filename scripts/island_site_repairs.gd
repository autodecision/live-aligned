extends Node3D
## Small terrain additions and imported-material corrections, kept separate from the map.
const BANKS=preload("res://assets/bridge_landing_banks.glb")
const MANIFEST="res://assets/island_site_repairs.json"
var moved_trees:Array=[]
var repaired_rocks:Array=[]
func _ready()->void:
 var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST));var map=get_parent().get_node("TempleMap")
 for row in data.trees:
  var tree=map.get_node_or_null(NodePath(row.name));assert(tree,"Missing relocated tree "+row.name)
  tree.position=Vector3(row.position[0],row.position[1],row.position[2]);moved_trees.append(tree)
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
