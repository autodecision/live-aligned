extends Node3D
## Shared lantern meshes, collision primitives, and shadow-free local lights.
const MODEL=preload("res://assets/coastal_lantern.glb")
const POSITIONS="res://assets/island_lantern_positions.json"
var lamps:Array[Node3D]=[]
var lights:Array[OmniLight3D]=[]
var bulb_material:StandardMaterial3D
var night_strength:float=0.0

func _ready()->void:
 var rows:Variant=JSON.parse_string(FileAccess.get_file_as_string(POSITIONS))
 assert(rows is Array,"Lantern placement data is required")
 for row in rows:
  var lamp:=Node3D.new();lamp.name=row.name
  lamp.position=Vector3(row.position[0],row.position[1],row.position[2]);lamp.rotation.y=-row.yaw
  add_child(lamp);lamps.append(lamp)
  var model:Node3D=MODEL.instantiate();lamp.add_child(model)
  for mesh in model.find_children("*","MeshInstance3D",true,false):
   if "Bulbs" in String(mesh.name):
    if not bulb_material:
     bulb_material=mesh.mesh.surface_get_material(0).duplicate()
     bulb_material.emission_enabled=true;bulb_material.emission=Color(1.0,.60,.21)
    mesh.material_override=bulb_material
   elif "Glass" in String(mesh.name):
    mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  # A compact solid pole collider, independent of the detailed visual mesh.
  var body:=StaticBody3D.new();body.name="PoleCollision";lamp.add_child(body)
  var collision:=CollisionShape3D.new();var shape:=CylinderShape3D.new();shape.radius=.17;shape.height=2.5
  collision.shape=shape;collision.position.y=1.25;body.add_child(collision)
  var light:=OmniLight3D.new();light.name="WarmLanternLight";light.position.y=2.77
  light.omni_range=4.2 if row.name=="Coastal_Lantern_Main_05" else (6.0 if row.name=="Coastal_Lantern_Main_06" else 8.0)
  light.omni_attenuation=1.4;light.omni_shadow_mode=OmniLight3D.SHADOW_CUBE
  light.shadow_enabled=false;light.light_size=.12
  # The lantern remains visible at all distances. Only its contribution to
  # nearby surfaces fades out, avoiding distant local-light rendering cost.
  light.distance_fade_enabled=true;light.distance_fade_begin=26.0;light.distance_fade_length=14.0
  lamp.add_child(light);lights.append(light)
 set_night_strength(night_strength)
 print("ISLAND_LANTERNS ",lamps.size()," shared lanterns; local lights have no shadow maps")

func set_night_strength(value:float)->void:
 night_strength=clampf(value,0.0,1.0)
 if bulb_material:bulb_material.emission_energy_multiplier=lerpf(.06,4.5,night_strength)
 for light in lights:
  light.light_energy=2.8*night_strength
  light.visible=night_strength>.0001
