extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
var main:Node3D
var player:CharacterBody3D
var camera:Camera3D
var cycle:Node3D
var report:Dictionary={}
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func ray(p:Vector3,up:float=1.,down:float=3.)->Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*up,p-Vector3.UP*down);query.exclude=[player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(query)
func capture(label:String,point:Vector3,target:Vector3,phase:float)->void:
 camera.global_position=point;camera.look_at(target);cycle.set_phase(phase)
 var start:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<1100:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"island_bridges_"+label+".png")
func run()->void:
 if DisplayServer.get_name()=="headless":
  Engine.physics_ticks_per_second=240;Engine.time_scale=4.0
 root.size=Vector2i(1280,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 main.get_node("RenderOptimization").set_performance_mode(true,false)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 cycle=main.get_node("DayNightCycle");cycle.running=false
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
 await physics_frame
 var bridges=main.get_node("IslandBridges");assert(bridges.bridges.size()==3)
 var walks:=[];var deck_checks:=0;var rail_checks:=0
 # Real capsule motion follows each complete route in both directions. Begin
 # inland and continue past the other landing, exercising the terrain seams.
 player.capture_mouse(true);Input.action_press("move_forward")
 for bridge in bridges.bridges:
  var a:=vec(bridge.start);var b:=vec(bridge.end);var direction:Vector3=Vector3(b.x-a.x,0,b.z-a.z).normalized()
  var side:=Vector3(-direction.z,0,direction.x)
  for section_index in range(bridge.sections.size()-1):
   var p:=vec(bridge.sections[section_index].position).lerp(vec(bridge.sections[section_index+1].position),.5)
   for offset in [-1.5,0.,1.5]:
    var hit:=ray(p+side*offset,2.,3.)
    assert(not hit.is_empty(),"Gap in bridge: "+bridge.name+" at="+str(p)+" offset="+str(offset))
    assert(hit.position.y>=p.y-.06,"Deck collision below visual surface at="+str(p)+" offset="+str(offset)+" hit="+str(hit))
    deck_checks+=1
  for reverse in [false,true]:
   var start:Vector3=b if reverse else a;var end:Vector3=a if reverse else b;var d:Vector3=-direction if reverse else direction
   var entry:Vector3=start-d*1.8;var h:=ray(entry,4.,8.);assert(not h.is_empty(),"Unsupported approach: "+bridge.name)
   player.position=Vector3(entry.x,h.position.y+.08,entry.z);player.velocity=Vector3.ZERO;player.rotation.y=atan2(-d.x,-d.z)
   var progress:float=-1.8;var steps:=0;var max_airborne:=0;var airborne:=0;var previous_progress:float=-100.;var stall:=0
   while progress<bridge.length+1.1 and steps<2400:
    await physics_frame;player._physics_process(1./60.);steps+=1
    progress=Vector3(player.position.x-start.x,0,player.position.z-start.z).dot(d)
    if player.is_on_floor():airborne=0
    else:airborne+=1;max_airborne=maxi(max_airborne,airborne)
    if progress<previous_progress+.001:stall+=1
    else:stall=0
    previous_progress=progress
    if stall>90:break
   print("BRIDGE_WALK ",bridge.name," reverse=",reverse," progress=",progress,"/",bridge.length," pos=",player.position)
   assert(progress>=bridge.length+1.,"Blocked bridge walk "+bridge.name+" reverse="+str(reverse)+" progress="+str(progress))
   assert(max_airborne<45,"Fall during crossing "+bridge.name)
   walks.append({"bridge":bridge.name,"reverse":reverse,"distance":progress,"steps":steps,"max_airborne_frames":max_airborne})
  # A sideways sweep must be stopped by each rail.
  for sign_side in [-1.,1.]:
   var middle:Vector3=a.lerp(b,.5);middle.y+=1.15
   player.position=middle+Vector3.UP*.03;player.velocity=Vector3.ZERO
   for i in range(90):
    await physics_frame
    player.velocity=side*sign_side*4.+Vector3.DOWN*.3;player.move_and_slide()
   var lateral:float=Vector3(player.position.x-middle.x,0,player.position.z-middle.z).dot(side)
   assert(absf(lateral)<1.95,"Rail did not block player")
   rail_checks+=1
 Input.action_release("move_forward")
 var lamps=main.get_node("IslandLanterns");assert(lamps.lamps.size()==43)
 assert(not lamps.has_node("Coastal_Lantern_Main_01"))
 var moved=lamps.get_node("Coastal_Lantern_Main_14");assert(moved.position.distance_to(Vector3(22.45,1.890222,-22.25))<.001)
 var exclusions:Array[RID]=[player.get_rid()]
 for lamp in lamps.lamps:exclusions.append(lamp.get_node("PoleCollision").get_rid())
 var max_gap:float=-1000.
 for lamp in lamps.lamps:
  for i in range(32):
   var p:Vector3=lamp.position+Vector3(cos(i*TAU/32)*.245,0,sin(i*TAU/32)*.245)
   var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*.4,p-Vector3.UP*1.);query.exclude=exclusions
   var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query)
   assert(not hit.is_empty(),"Unsupported lantern "+lamp.name)
   max_gap=maxf(max_gap,p.y-hit.position.y)
 assert(max_gap<.005,"Floating lantern base")
 cycle.set_phase(.75)
 for light in lamps.lights:assert(light.light_energy>2. and not light.shadow_enabled)
 cycle.set_phase(.25)
 for light in lamps.lights:assert(light.light_energy<.001)
 report={"bridges":3,"bridge_lanterns":21,"total_lanterns":43,"uphill_lantern_removed":true,"cliff_lantern_moved_toward_tree":true,"walks":walks,"deck_ray_checks":deck_checks,"guard_rail_sweeps":rail_checks,"lantern_ground_samples":43*32,"maximum_lantern_base_gap":max_gap,"night_cycle_controls_all_bridge_lights":true}
 FileAccess.open(OUT+"island_bridges_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 if DisplayServer.get_name()=="headless":print("BRIDGES_TEST_PASS");quit();return
 player.position=Vector3(-3.5,1,12)
 await capture("overview_day",Vector3(48,90,72),Vector3(39,0,-12),.25)
 await capture("overview_night",Vector3(48,75,58),Vector3(40,1,-13),.75)
 await capture("main_north_day",Vector3(24,8,-30),Vector3(53,6,-38),.25)
 await capture("main_north_night",Vector3(24,8,-30),Vector3(53,6,-38),.75)
 await capture("deck_night",Vector3(27,6.6,-32.7),Vector3(52,6,-38),.75)
 await capture("main_south_day",Vector3(38,16,40),Vector3(43,3,18),.25)
 await capture("north_south_night",Vector3(96,15,-13),Vector3(78,4,-8),.75)
 await capture("removed_lamp",Vector3(-.5,7,5),Vector3(-8,3,16),.75)
 await capture("moved_lamp",Vector3(18.5,5,-16.2),Vector3(24,4,-23),.75)
 print("BRIDGES_CAPTURE_PASS");quit()
