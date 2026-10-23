extends "res://scripts/check_south_garden.gd"
## Verify the reported second urn, scoped crown, weathered stones and rear pair.
func run()->void:
 Engine.physics_ticks_per_second=240
 Engine.time_scale=4.0
 main=load('res://scenes/main.tscn').instantiate()
 root.add_child(main)
 player=main.get_node('Player')
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 for npc in main.get_node('IslandCharacters').get_children():
  npc.set_physics_process(false)
  npc.position=Vector3(0,-100,0)
 await physics_frame
 var map:Node3D=main.get_node('TempleMap')
 var crown:MeshInstance3D=map.get_node('Temple_Entablature')
 var vertices:int=0
 for i:int in crown.mesh.get_surface_count():
  var mat:StandardMaterial3D=crown.mesh.surface_get_material(i)
  assert(mat.albedo_texture!=null and mat.normal_enabled,'Missing roof stone texture')
  vertices+=crown.mesh.surface_get_array_len(i)
 assert(vertices>30000,'Scoped crown did not install')
 var urn:MeshInstance3D=map.get_node('Fountain_Offering_Vase')
 assert(urn.position.distance_to(Vector3(4.3,3.5476567,-5.4))<.001)
 var aabb:AABB=urn.get_aabb()
 var base:Vector3=urn.global_transform*(aabb.position+Vector3(aabb.size.x*.5,0,aabb.size.z*.5))
 for offset:Vector3 in [Vector3.ZERO,Vector3(.10,0,0),Vector3(-.10,0,0),Vector3(0,0,.10),Vector3(0,0,-.10)]:
  var q:=PhysicsRayQueryParameters3D.create(base+offset+Vector3.UP*.015,base+offset-Vector3.UP*.08)
  q.exclude=[player.get_rid()]
  var hit:=main.get_world_3d().direct_space_state.intersect_ray(q)
  assert(not hit.is_empty(),'Urn base unsupported')
  assert(absf(hit.position.y-3.55)<.012)
 var moved:Node3D=map.get_node('Olive_Ridge_BG_2')
 var back:Node3D=map.get_node('Olive_Temple_Back_R')
 assert(Vector2(moved.position.x-back.position.x,moved.position.z-back.position.z).length()>7.0)
 assert(moved.position.distance_to(Vector3(10.9,5.701597,-18.5))<.001)
 var soil:=ray(moved.position)
 assert(not soil.is_empty() and absf(soil.position.y-moved.position.y)<.10,'Tree not grounded')
 var sea_plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/temple_clearance.json'))
 for label:String in sea_plan.sea_rocks:
  var stone:MeshInstance3D=map.get_node(NodePath(label))
  for i:int in stone.mesh.get_surface_count():
   var mat:StandardMaterial3D=stone.mesh.surface_get_material(i)
   assert(mat.vertex_color_use_as_albedo and mat.normal_enabled and mat.uv1_world_triplanar)
   assert(mat.normal_texture!=null)
   assert(mat.albedo_texture!=null)
   assert(stone.mesh.surface_get_arrays(i)[Mesh.ARRAY_COLOR]!=null,'Missing stone colors')
 for route:Array in [
  [[3.45,3.55,-5.5],[3.45,3.55,-7.0],[3.45,3.55,-8.0]],
  [[5.1,3.55,-5.5],[5.1,3.55,-7.0],[5.1,3.55,-8.0]]]:
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 print('TEMPLE_CROWN_PASS ',JSON.stringify({'crown_render_vertices':vertices,'urn_base_samples':5,'urn_player_walks':walks,'weathered_rocks':sea_plan.sea_rocks.size(),'rear_pair_clear':true}))
 quit()
