extends Node3D
## Rolling seabed, fitted pier sleeves and a distant ocean horizon.
const MODEL=preload("res://assets/ocean_ground.glb")
const DEEP_FLOOR=preload("res://assets/ocean_seabed_deep_compact.res")
const FLOOR_SHOALS=preload("res://assets/ocean_seabed_shoals_compact.res")
var submerged_visuals:Array[MeshInstance3D]=[]
var submerged_visible:bool=true
func _ready()->void:
 process_priority=1 # Follow AnimatedWater so both surfaces use the same frame.
 var model:Node3D=MODEL.instantiate();add_child(model)
 var sediment:=ShaderMaterial.new()
 sediment.shader=preload("res://shaders/ocean_sediment.gdshader")
 var rock_sediment:ShaderMaterial=sediment.duplicate()
 rock_sediment.set_shader_parameter("rock_base",true)
 for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
  if String(mesh.name).begins_with("Ocean_Horizon_Water"):
   horizon_material=ShaderMaterial.new()
   horizon_material.shader=preload("res://shaders/ocean_horizon.gdshader")
   horizon_material.set_shader_parameter("contact_field",load("res://assets/ocean_contact_field.exr"))
   mesh.material_override=horizon_material
   mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   mesh.extra_cull_margin=.6
   continue
  if String(mesh.name).begins_with("Ocean_Seabed") or String(mesh.name).begins_with("Ocean_Toe_") or String(mesh.name).begins_with("Ocean_Rock_Base_"):
   mesh.material_override=sediment
   if String(mesh.name).begins_with("Ocean_Rock_Base_"):mesh.material_override=rock_sediment
  else:
   for i:int in mesh.mesh.get_surface_count():
    var mat:Material=mesh.mesh.surface_get_material(i)
    if mat is StandardMaterial3D:mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  var body:=StaticBody3D.new();body.name="GroundCollision";mesh.add_child(body)
  var shape:=CollisionShape3D.new();shape.shape=mesh.mesh.create_trimesh_shape()
  shape.shape.backface_collision=true
  body.add_child(shape)
  if String(mesh.name)=="Ocean_Seabed":
   # Same triangles and normals, partitioned into two render buffers. Keep
   # possible shoals visible even at the deepest wave trough. The collider
   # above retains the complete original seabed independently of visibility.
   mesh.mesh=DEEP_FLOOR
   var shoals:=MeshInstance3D.new();shoals.name="Ocean_Seabed_Shoals"
   shoals.mesh=FLOOR_SHOALS;shoals.transform=mesh.transform;shoals.material_override=sediment
   mesh.get_parent().add_child(shoals)
  # Original wave -.16 plus swells -.38 cannot uncover geometry below -5.56.
  if (mesh.global_transform*mesh.get_aabb()).end.y< -5.56:submerged_visuals.append(mesh)
 _make_atmosphere()

var atmosphere:MeshInstance3D
var atmosphere_material:ShaderMaterial
var horizon_material:ShaderMaterial
func _make_atmosphere()->void:
 atmosphere=MeshInstance3D.new();atmosphere.name="UnderwaterAtmosphere"
 var quad:=QuadMesh.new();quad.size=Vector2(2,2);atmosphere.mesh=quad
 atmosphere_material=ShaderMaterial.new()
 atmosphere_material.shader=preload("res://shaders/ocean_atmosphere.gdshader")
 atmosphere_material.render_priority=100
 atmosphere.material_override=atmosphere_material
 atmosphere.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 atmosphere.ignore_occlusion_culling=true
 atmosphere.custom_aabb=AABB(Vector3(-10000,-10000,-10000),Vector3(20000,20000,20000))
 add_child(atmosphere)
func _process(_delta:float)->void:
 var camera:=get_viewport().get_camera_3d()
 if is_instance_valid(camera):
  atmosphere.visible=camera.global_position.y< -4.74
  # Restore before reaching the highest possible crest. Physics stays active.
  var show_submerged:bool=camera.global_position.y< -4.4
  if show_submerged!=submerged_visible:
   submerged_visible=show_submerged
   for mesh:MeshInstance3D in submerged_visuals:mesh.visible=show_submerged
 var clock:=get_parent().get_node_or_null("DayNightCycle")
 if clock:atmosphere_material.set_shader_parameter("daylight",clock.daylight)
 var water:=get_parent().get_node_or_null("AnimatedWater")
 if water:horizon_material.set_shader_parameter("water_time",water.elapsed)
