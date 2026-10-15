extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/bridge_approach_checks/"
var main:Node3D
var player:CharacterBody3D
var terrain_excluded:Array[RID]=[]
var report:={"support":[],"walks":[]}
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func ray(p:Vector3,excluded:Array[RID])->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*8.,p-Vector3.UP*15.);q.exclude=excluded
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func walk(a:Vector3,b:Vector3,label:String)->void:
 var exclude:Array[RID]=[player.get_rid()]
 var hit:=ray(a,exclude);assert(not hit.is_empty(),"No walk start "+label)
 player.position=Vector3(a.x,hit.position.y+.07,a.z);player.velocity=Vector3.ZERO
 await physics_frame
 var steps:=0
 while Vector2(player.position.x-b.x,player.position.z-b.z).length()>.2 and steps<1600:
  var toward:=Vector3(b.x-player.position.x,0,b.z-player.position.z).normalized()
  player.rotation.y=atan2(-toward.x,-toward.z)
  Input.action_press("move_forward");await physics_frame;player._physics_process(1./60.);steps+=1
 Input.action_release("move_forward")
 var error:=Vector2(player.position.x-b.x,player.position.z-b.z).length()
 if error>=.3:
  for i in player.get_slide_collision_count():print("BRIDGE_BLOCKER ",player.get_slide_collision(i).get_collider().get_path())
 assert(error<.3,"Blocked "+label+" at "+str(player.position)+" remaining "+str(error))
 assert(player.position.y>0.,"Fell below landing "+label)
 report.walks.append({"label":label,"steps":steps,"remaining":error})
 print("BRIDGE_APPROACH_WALK ",label," steps=",steps)
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.walk_speed=5.
 main.get_node("DayNightCycle").running=false
 main.get_node("VisualLab").select_preset(0)
 await physics_frame
 terrain_excluded=[player.get_rid()]
 for body in main.find_children("*","StaticBody3D",true,false):
  if "Cliff_Terrain" not in String(body.get_path()):terrain_excluded.append(body.get_rid())
 var plan:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
 for bridge in plan.bridges:
  if bridge.name not in ["Main_North","Main_South"]:continue
  var a:=vec(bridge.start);var b:=vec(bridge.end)
  var d:=Vector3(bridge.direction[0],0,-bridge.direction[1]);var side:=Vector3(-d.z,0,d.x)
  # Exclude the bridge itself, so a deck cannot disguise a hole in its bank.
  for distance in [-1.,-.5,0.,.5,1.]:
   for lane in [-2.1,-1.3,0.,1.3,2.1]:
    var p:Vector3=a+d*distance+side*lane
    var hit:=ray(p,terrain_excluded);assert(not hit.is_empty(),"Missing bank "+bridge.name)
    var expected:float=a.y+(b.y-a.y)*maxf(distance,0.)/bridge.length+1.15*sin(PI*maxf(distance,0.)/bridge.length)
    var gap:float=expected-hit.position.y
    assert(gap<.16 and gap>-.19,"Uneven threshold "+bridge.name+" lane "+str(lane)+" gap "+str(gap))
    if distance>=0.:assert(gap>.015,"Ground cuts through deck "+bridge.name)
    report.support.append({"bridge":bridge.name,"distance":distance,"lane":lane,"gap":gap})
  for lane in [-1.2,0.,1.2]:
   var start:Vector3=a-d*4.+side*lane;var finish:Vector3=a+d*7.+side*lane
   await walk(start,finish,bridge.name+" approach lane "+str(lane))
   await walk(finish,start,bridge.name+" return lane "+str(lane))
  # Walk the whole span in each direction, including both shore connections.
  await walk(a-d*3.,b+d*3.,bridge.name+" full crossing")
  await walk(b+d*3.,a-d*3.,bridge.name+" full return")
 var optimizer=main.get_node("RenderOptimization")
 optimizer.set_performance_mode(true,false);assert(root.msaa_3d==Viewport.MSAA_2X)
 optimizer.set_performance_mode(false,false);assert(root.msaa_3d==Viewport.MSAA_4X)
 assert(optimizer.tree_count==91 and main.get_node("AnimatedWater").materials.size()==13)
 report["trees"]=91;report["water_surfaces"]=13;report["both_graphics_modes"]=true
 FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("BRIDGE_APPROACH_CHECK_PASS terrain_samples=",report.support.size()," walks=",report.walks.size())
 quit()
