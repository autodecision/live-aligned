extends Node3D
## Batched visual meshes plus simple continuous deck / guard-rail collision.
const MODEL=preload("res://assets/island_bridges.glb")
const PLAN="res://assets/island_bridges.json"
var bridges:Array=[]
func _ready()->void:
 var model:Node3D=MODEL.instantiate();add_child(model)
 for mesh in model.find_children("*","MeshInstance3D",true,false):
  for i in mesh.mesh.get_surface_count():
   var material=mesh.mesh.surface_get_material(i)
   if material is StandardMaterial3D:material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
 var plan:Variant=JSON.parse_string(FileAccess.get_file_as_string(PLAN));bridges=plan.bridges
 for bridge in bridges:
  var body:=StaticBody3D.new();body.name=bridge.name+"_Walkway";add_child(body)
  var faces:=PackedVector3Array();var side:=Vector3(bridge.side[0],0,-bridge.side[1]);var half_width:float=bridge.width*.5
  for i in range(bridge.sections.size()-1):
   var ar:Array=bridge.sections[i].position;var br:Array=bridge.sections[i+1].position
   var a:=Vector3(ar[0],ar[1],ar[2]);var b:=Vector3(br[0],br[1],br[2])
   var al:=a+side*half_width;var bl:=b+side*half_width;var right_a:=a-side*half_width;var right_b:=b-side*half_width
   _quad(faces,al,bl,right_b,right_a)
   # Solid invisible panels line up with the visible rails. The ends stay open.
   if bridge.sections[i].s>.5 and bridge.sections[i+1].s<bridge.length-.5:
    for sign_side in [-1.0,1.0]:
     var p:Vector3=a+side*(sign_side*1.94);var q:Vector3=b+side*(sign_side*1.94)
     _quad(faces,p,q,q+Vector3.UP*1.16,p+Vector3.UP*1.16)
  var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(faces)
  var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
  for lamp in plan.bridge_lamps:
   if lamp.support_bridge!=bridge.name:continue
   var pad:=CollisionShape3D.new();var pad_shape:=BoxShape3D.new();pad_shape.size=Vector3(.95,.18,.95);pad.shape=pad_shape
   pad.position=Vector3(lamp.position[0],lamp.position[1]-.09,lamp.position[2]);pad.rotation.y=-lamp.yaw
   body.add_child(pad)
 print("ISLAND_BRIDGES ",bridges.size()," lit footbridges with continuous collision and rail barriers")
func _quad(faces:PackedVector3Array,a:Vector3,b:Vector3,c:Vector3,d:Vector3)->void:
 faces.append_array(PackedVector3Array([a,b,c,a,c,d]))
