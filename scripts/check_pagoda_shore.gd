extends "res://scripts/check_south_garden.gd"
## Verify the western beach is sealed below water and traversable across its former cut.
const SHORE_OUT="/home/allister/Projects/live-aligned-previews/pagoda-shore-2026-10-19/final/"
var terrain_samples:int=0
var buried_vertices:int=0
var floor_exclusions:Array[RID]=[]

func require(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1)
 return ok

func ground_at(x:float,z:float)->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(Vector3(x,1,z),Vector3(x,-20,z))
 q.exclude=[player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(q)

func floor_at(p:Vector3)->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,-5.3,p.z),Vector3(p.x,-20,p.z))
 q.exclude=floor_exclusions
 return main.get_world_3d().direct_space_state.intersect_ray(q)

func shore_view(label:String,p:Vector3,target:Vector3)->void:
 camera.position=p;camera.look_at(target)
 for i:int in range(25):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(SHORE_OUT+label+".png")

func run()->void:
 DirAccess.make_dir_recursive_absolute(SHORE_OUT)
 var headless:bool=DisplayServer.get_name()=="headless"
 if headless:Engine.physics_ticks_per_second=240;Engine.time_scale=4.0
 root.size=Vector2i(1440,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.visible=false
 player.walk_speed=5.0;player.capture_mouse(true)
 player.get_node("CanvasLayer").hide();main.get_node("CharacterDialogue").hide()
 main.get_node("VisualLab").select_preset(0);main.get_node("VisualLab")._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 main.get_node("DayNightCycle").running=false;main.get_node("DayNightCycle").set_phase(.25)
 for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false);npc.position=Vector3(0,-100,0)
 await physics_frame
 floor_exclusions.append(player.get_rid())
 for body:StaticBody3D in main.find_children("*","StaticBody3D",true,false):
  if not 'Ocean_Seabed' in str(body.get_path()):floor_exclusions.append(body.get_rid())
 var shore:MeshInstance3D=main.get_node("NorthPagoda").find_child("North_Pagoda_Pagoda_Meadow_Ground",true,false)
 if not require(shore!=null,"Missing shoreline instance"):return
 var faces:PackedVector3Array=shore.mesh.get_faces()
 var edges:Dictionary={}
 for i:int in range(0,faces.size(),3):
  for e:int in 3:
   var a:Vector3=(shore.global_transform*faces[i+e]).snapped(Vector3.ONE*.0001)
   var b:Vector3=(shore.global_transform*faces[i+(e+1)%3]).snapped(Vector3.ONE*.0001)
   var key:Array=[a,b] if str(a)<str(b) else [b,a]
   edges[key]=int(edges.get(key,0))+1
 var checked:Dictionary={}
 for key:Array in edges:
  if edges[key]!=1:continue
  for p:Vector3 in key:
   if p.x>=39.254 or checked.has(p):continue
   checked[p]=true
   var hit:=floor_at(p)
   if not require(not hit.is_empty() and hit.position.y-p.y>.08,"Exposed shoreline edge "+str(p)):return
   buried_vertices+=1
 if not require(buried_vertices>80,"Expected submerged western boundary"):return
 # Sample closely across the former cut; a continuous surface must have no drop.
 for y:float in [43.,50.,57.,64.]:
  var route:Array=[]
  var previous:Dictionary={}
  for i:int in range(57):
   var x:float=28.+i*.25
   var hit:=ground_at(x,-y)
   if not require(not hit.is_empty(),"Hole in shore at "+str(Vector2(x,-y))):return
   if not previous.is_empty():
    if not require(absf(hit.position.y-previous.position.y)<.30,"Steep discontinuity at "+str(hit.position)):return
   previous=hit;terrain_samples+=1
   if i%4==0:route.append([x,hit.position.y,-y])
  if not await walk(route):quit(1);return
  if not await walk(route,true):quit(1);return
 if not headless:
  camera=Camera3D.new();camera.current=true;camera.fov=70;main.add_child(camera)
  main.get_node("AnimatedWater").set_process(false);main.get_node("AnimatedWater").set_water_time(12.)
  await shore_view("west",Vector3(23,-3.6,-52),Vector3(57,0,-55))
  await shore_view("west_high",Vector3(25,18,-40),Vector3(61,-1,-52))
  await shore_view("southwest",Vector3(43,-3.6,-20),Vector3(61,0,-48))
  await shore_view("underwater",Vector3(25,-7,-52),Vector3(41,-6,-52))
 var result:Dictionary={"walks":walks,"continuous_soil_samples":terrain_samples,"buried_boundary_vertices":buried_vertices}
 FileAccess.open(SHORE_OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 print("PAGODA_SHORE_PASS ",JSON.stringify(result))
 quit()
