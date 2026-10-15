extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/pagoda_sidewalk_checks/"
var main:Node3D
var player:CharacterBody3D
var samples:=0
var walks:=0
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func ray(p:Vector3,exclude:Array[RID])->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.,p-Vector3.UP*4.);q.exclude=exclude
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func walk_route(route:Dictionary,lane:float,reverse:bool)->bool:
 var points:Array=route.path;var ordered:=range(points.size()-1,-1,-1) if reverse else range(points.size())
 var first:=true
 for i in ordered:
  var p:=vec(points[i]);var d:=vec(points[mini(i+1,points.size()-1)])-vec(points[maxi(0,i-1)]);d.y=0;d=d.normalized()
  p+=Vector3(-d.z,0,d.x)*lane
  if first:
   var hit:=ray(p,[player.get_rid()]);assert(not hit.is_empty());player.position=Vector3(p.x,hit.position.y+.05,p.z);player.velocity=Vector3.ZERO;await physics_frame;first=false
  var steps:=0
  while Vector2(p.x-player.position.x,p.z-player.position.z).length()>.16 and steps<180:
   var toward:=Vector3(p.x-player.position.x,0,p.z-player.position.z).normalized();player.rotation.y=atan2(-toward.x,-toward.z)
   Input.action_press("move_forward");await physics_frame;player._physics_process(1./60.);steps+=1
  Input.action_release("move_forward")
  if steps>=180:
   for j in player.get_slide_collision_count():print("SIDEWALK_BLOCKER ",player.get_slide_collision(j).get_collider().get_path())
  if steps>=180:
   push_error("Sidewalk blocked point "+str(i)+" lane "+str(lane)+" position "+str(player.position));return false
  if absf(player.position.y-p.y)>=.28:
   push_error("Sidewalk height mismatch while walking");return false
 walks+=1
 return true
func capture(camera:Camera3D,label:String,p:Vector3,target:Vector3)->void:
 root.grab_focus();camera.position=p;camera.look_at(target)
 for i in range(22):await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUT+label+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 var views_only:bool="--views-only" in OS.get_cmdline_user_args()
 if DisplayServer.get_name()=="headless":Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 root.size=Vector2i(1440,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.walk_speed=5.;player.get_node("CanvasLayer").hide()
 main.get_node("VisualLab").select_preset(0)
 assert(not main.get_node("VisualLab")._launcher.visible,"Floating Visual Lab button returned")
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 var clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 var plan:Dictionary=main.get_node("NorthPagoda").plan
 await physics_frame
 var exclude:Array[RID]=[player.get_rid()]
 var structure:RID=main.get_node("NorthPagoda/PagodaStructure").get_rid()
 var ground_exclude:Array[RID]=[player.get_rid(),structure]
 for body in main.get_node("IslandBridges").find_children("*","StaticBody3D",true,false):ground_exclude.append(body.get_rid())
 if not views_only:
  for route in plan.sidewalk_routes:
   for i in range(route.path.size()):
    var p:=vec(route.path[i]);var d:=vec(route.path[mini(i+1,route.path.size()-1)])-vec(route.path[maxi(0,i-1)]);d.y=0;d=d.normalized();var n:=Vector3(-d.z,0,d.x)
    for lane in [-.88,0.,.88]:
     var q:Vector3=p+n*float(route.half_widths[i])*lane
     var hit:=ray(q,exclude);assert(not hit.is_empty(),"Missing paving")
     assert(absf(hit.position.y-p.y)<.12,"Paving/collision mismatch "+str(i)+" "+str(hit.position)+" expected "+str(p))
     var ground:=ray(q,ground_exclude);assert(not ground.is_empty(),"No ground under sidewalk")
     assert(ground.position.y<p.y+.015 and p.y-ground.position.y<.20,"Raised or buried sidewalk "+str(i)+" ground "+str(ground.position)+" paving "+str(q))
     samples+=1
   for lane in [-.7,0.,.7]:
    for reverse in [false,true]:
     if not await walk_route(route,lane,reverse):quit(1);return
  var report:={"supported_paving_samples":samples,"three_lane_two_way_walks":walks,"bridge_landings":2,"visual_lab_launcher_hidden":true,"trees":main.get_node("RenderOptimization").tree_count,"water_surfaces":main.get_node("AnimatedWater").materials.size()}
  FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
  print("PAGODA_SIDEWALK_CHECK_PASS ",JSON.stringify(report))
 if DisplayServer.get_name()!="headless":
  root.always_on_top=true;Input.mouse_mode=Input.MOUSE_MODE_VISIBLE;player.position=Vector3(-3.5,1,12)
  var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=68
  var a:=vec(plan.path[0]);var d:Vector3=(vec(plan.path[1])-a).normalized()
  await capture(camera,"main_bridge_threshold",a-d*1.9+Vector3.UP*1.8,a+d*4.+Vector3.UP*.1)
  await capture(camera,"main_bridge_side",Vector3(55.5,8,-43.5),Vector3(61,5.2,-41))
  var branch:Dictionary=plan.sidewalk_routes[1];a=vec(branch.path[0]);d=(vec(branch.path[-1])-a).normalized()
  await capture(camera,"second_bridge_exit",a-d*3.+Vector3.UP*1.7,a+d*4.+Vector3.UP*.3)
  await capture(camera,"junction_overview",Vector3(69,13,-35),Vector3(70,5.3,-42))
  var entry:=vec(plan.entry);var forward:=Vector3(-sin(plan.yaw),0,-cos(plan.yaw))
  await capture(camera,"pagoda_steps",entry-forward*3.+Vector3.UP*2.5,entry+forward*2.)
  await capture(camera,"path_overview",Vector3(75,23,-36),Vector3(74,5,-46))
 quit()
