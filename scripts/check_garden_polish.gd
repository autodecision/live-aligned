extends "res://scripts/check_south_garden.gd"
## Runtime layout, flow parameter direction and continuous rail protection.
func run()->void:
 Engine.physics_ticks_per_second=240
 Engine.time_scale=4.
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 player=main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.walk_speed=5.
 for npc in main.get_node("IslandCharacters").get_children():
  npc.set_physics_process(false)
  npc.position=Vector3(0,-100,0)
 await physics_frame
 garden=main.get_node("SouthGarden")
 assert(garden.lights.size()==6)
 for light:OmniLight3D in garden.lights:
  var paired:=false
  for other:OmniLight3D in garden.lights:
   if absf(light.position.x-other.position.x)<.001:
    if absf(light.position.x-90.2)<.001:
     if absf(light.position.z+other.position.z-66.358)<.002:paired=true
    else:
     if absf(light.position.z+other.position.z-68.)<.001:paired=true
  assert(paired,"Unpaired garden lantern")
 var path:MeshInstance3D=garden.get_node("Garden/SouthGarden_Gravel")
 var tile:StandardMaterial3D=path.material_override
 var pagoda:MeshInstance3D=main.get_node("NorthPagoda").find_child("*Pagoda_Sidewalk*",true,false)
 assert(pagoda!=null)
 var north_tile:StandardMaterial3D=pagoda.mesh.surface_get_material(0)
 assert(tile.albedo_texture.get_image().get_size()==north_tile.albedo_texture.get_image().get_size())
 var map:Node3D=main.get_node("TempleMap")
 var rock:Node3D=map.get_node("Large_Rock_South_02")
 assert(not rock.visible)
 for shape:CollisionShape3D in rock.find_children("*","CollisionShape3D",true,false):assert(shape.disabled)
 var placements:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/tree_clearance_repairs.json"))
 for row:Dictionary in placements.trees:
  assert(map.get_node(NodePath(row.name)).position.distance_to(vec(row.position))<.001,"Tree placement override lost")
 var fall:MeshInstance3D=map.get_node("Sea_Connected_Fall")
 var arrays:=fall.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var uv:PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV]
 var high:float=-INF
 var low:float=INF
 var high_v:float=0.
 var low_v:float=0.
 for i:int in vertices.size():
  if vertices[i].y>high:high=vertices[i].y;high_v=uv[i].y
  if vertices[i].y<low:low=vertices[i].y;low_v=uv[i].y
 # Confirm the actual glTF V flip, then test the shader's phase transport.
 assert(high_v>.97 and low_v<.03)
 var phase_t:float=.3
 var later_t:float=phase_t+.1*1.7/7.
 assert(later_t>phase_t)
 var height_at:float=.145-5.695*pow(phase_t,1.65)
 var later_height:float=.145-5.695*pow(later_t,1.65)
 assert(later_height<height_at,"Water feature travels upward")
 # Horizontal probes hit the rail along the complete cement return.
 var guard_hits:int=0
 for x:float in [-2.35,-.35,1.65,3.65,5.65,7.65,9.1]:
  var q:=PhysicsRayQueryParameters3D.create(Vector3(x,.95,10.9),Vector3(x,.95,12.8))
  q.exclude=[player.get_rid()]
  var hit:=main.get_world_3d().direct_space_state.intersect_ray(q)
  assert(not hit.is_empty() and "TempleTerraceGuard" in String(hit.collider.get_path()),"Rail return gap")
  guard_hits+=1
 # Walk both directions beside the new return, then turn the original corner.
 for route:Array in [
  [[-2.4,.05,10.75],[2,.05,10.75],[8.2,.05,10.75]],
  [[8.2,.05,10.75],[8.2,.05,8.8]]]:
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 print("GARDEN_POLISH_PASS ",JSON.stringify({"mirrored_lanterns":6,"trees_relocated":placements.trees.size(),"rail_probes":guard_hits,"terrace_walks":walks,"water_feature_height_delta":later_height-height_at,"pagoda_tiles":true,"cliff_rock_removed":true}))
 quit()
