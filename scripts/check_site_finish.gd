extends "res://scripts/check_south_garden.gd"
## Both repaired bridge thresholds, using the actual capsule in three lanes.

func run()->void:
 Engine.physics_ticks_per_second=240
 Engine.time_scale=4.0
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 player=main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.walk_speed=5.0
 for npc in main.get_node("IslandCharacters").get_children():
  npc.set_physics_process(false)
  npc.position=Vector3(0,-100,0)
 garden=main.get_node("SouthGarden")
 await physics_frame
 var bridges:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
 for name:String in ["Main_South","North_South"]:
  var bridge:Dictionary={}
  for row:Dictionary in bridges.bridges:
   if row.name==name:bridge=row
  var sections:Array=bridge.sections
  var center:Array=[sections[-3].position,sections[-1].position]
  var approach:Array=garden.plan.routes[0 if name=="Main_South" else 1]
  for i:int in range(1,approach.size()):center.append(approach[i])
  var a:=vec(sections[-3].position)
  var b:=vec(sections[-1].position)
  var side:Vector3=Vector3(-(b-a).z,0,(b-a).x).normalized()
  for lane:float in [-1.25,0.,1.25]:
   var route:Array=[]
   for i:int in center.size():
    var p:=vec(center[i])
    var width:float=1.0 if i<3 else .32
    p+=side*lane*width
    var hit:=ray(p)
    assert(not hit.is_empty(),"Missing bridge approach support")
    p.y=hit.position.y
    route.append([p.x,p.y,p.z])
   for reverse:bool in [false,true]:
    if not await walk(route,reverse):quit(1);return
 # Coincident seam vertices and matching animation fields prevent a moving crack.
 var map:Node3D=main.get_node("TempleMap")
 var pool:MeshInstance3D=map.get_node("Lower_Pool_Water_Fitted")
 var outlet:MeshInstance3D=map.get_node("Outfall_Contained_Water")
 var seam:Array[Vector3]=[]
 for p:Vector3 in pool.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  if absf(p.x-6.7)<.001 and p.z>=6.899 and p.z<=8.001:seam.append(p)
 var matches:int=0
 for p:Vector3 in outlet.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  if absf(p.x-6.7)<.001:
   for q:Vector3 in seam:
    if p.distance_to(q)<.0002:matches+=1;break
 assert(matches>=13,"Disconnected water seam")
 var pm:ShaderMaterial=pool.get_surface_override_material(0)
 var om:ShaderMaterial=outlet.get_surface_override_material(0)
 for key:String in ["current","bounds_min","bounds_max"]:
  assert(pm.get_shader_parameter(key)==om.get_shader_parameter(key),"Water fields diverge at outlet")
 var fragments:MeshInstance3D=map.get_node("Ancient_Column_Drums")
 assert(fragments.mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV].size()>100,"Fragments lack usable UVs")
 var report:Dictionary={"bridge_lane_walks":walks,"matched_water_seam_vertices":matches,"textured_column_fragments":true}
 var path:="/home/allister/Projects/live-aligned-previews/site-finish-2026-10-18/site_validation.json"
 FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("SITE_FINISH_PASS ",JSON.stringify(report))
 quit()
