extends "res://scripts/check_south_garden.gd"
## Verify detailed stone, original cheap collision and the actual player capsule.

func run()->void:
 Engine.physics_ticks_per_second=240
 Engine.time_scale=4.
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 player=main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.capture_mouse(true)
 for npc in main.get_node("IslandCharacters").get_children():
  npc.set_physics_process(false)
  npc.position=Vector3(0,-100,0)
 await physics_frame
 var map:Node3D=main.get_node("TempleMap")
 var original:Node3D=load("res://assets/mediterranean_temple.glb").instantiate()
 var collision_shapes:int=0
 var detailed_surfaces:int=0
 for name:String in ["Temple_Colonnade","Temple_Stylobate","Temple_Bedrock_Foundation"]:
  var target:MeshInstance3D=map.get_node(name)
  var before:MeshInstance3D=original.get_node(name)
  var actual_shapes:=target.find_children("*","CollisionShape3D",true,false)
  var saved_shapes:=before.find_children("*","CollisionShape3D",true,false)
  assert(actual_shapes.size()==saved_shapes.size() and not actual_shapes.is_empty())
  for i:int in actual_shapes.size():
   assert(actual_shapes[i].shape==saved_shapes[i].shape,"Architectural collision was replaced")
   assert(actual_shapes[i].transform==saved_shapes[i].transform,"Architectural collision moved")
   collision_shapes+=1
  assert(target.mesh!=before.mesh,"Missing detailed architecture override")
  for surface:int in target.mesh.get_surface_count():
   var arrays:=target.mesh.surface_get_arrays(surface)
   var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
   assert(uv.size()==arrays[Mesh.ARRAY_VERTEX].size() and uv.size()>100)
   var mat:StandardMaterial3D=target.mesh.surface_get_material(surface)
   assert(mat.albedo_texture!=null and mat.normal_enabled and mat.normal_texture!=null)
   detailed_surfaces+=1
 original.free()
 # Three lanes on the main stairs, both directions. Test the porch, doorway,
 # and both long colonnade passages with the same capsule and step assistance.
 for lane:float in [-.65,0.,.65]:
  var route:Array=[]
  for i:int in 11:
   var z:float=10.8-float(i)*1.1
   # Converge at the narrow original central gap between the front pillars.
   var p:=Vector3(-3.5+lane*clampf((z-1.)/1.5,0.,1.),4.5,z)
   var hit:=ray(p)
   assert(not hit.is_empty(),"Missing stair support")
   route.append([p.x,hit.position.y,p.z])
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 for route:Array in [
  [[-6.7,4.525,-1.0],[-3.5,4.525,-1.0],[-.2,4.525,-1.0]],
  [[-3.5,4.525,-.6],[-3.5,4.531,-2.5],[-3.5,4.531,-7.0]],
  [[-7.2,4.525,-1.5],[-7.2,4.525,-6.5],[-7.2,4.525,-12.5]],
  [[.1,4.525,-1.5],[.1,4.525,-6.5],[.1,4.525,-12.5]]]:
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 var report:={"two_way_player_walks":walks,"unchanged_collision_shapes":collision_shapes,
   "textured_stone_surfaces":detailed_surfaces}
 var output:="/home/allister/Projects/live-aligned-previews/temple-detail-2026-10-18/runtime_validation.json"
 FileAccess.open(output,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TEMPLE_DETAIL_PASS ",JSON.stringify(report))
 quit()
