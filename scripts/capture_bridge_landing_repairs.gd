extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
var main:Node3D
var player:CharacterBody3D
var camera:Camera3D
var clock:Node3D
var excluded:Array[RID]=[]
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func ray(p:Vector3,up:float=1.,down:float=3.,exclude:Array[RID]=[])->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*up,p-Vector3.UP*down);q.exclude=exclude if not exclude.is_empty() else [player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func capture(label:String,point:Vector3,target:Vector3,phase:float=.25)->void:
 camera.position=point;camera.look_at(target);clock.set_phase(phase)
 var start:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<1100:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"landing_repair_"+label+".png")
func run()->void:
 if DisplayServer.get_name()=="headless":Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 root.size=Vector2i(1280,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide();player.capture_mouse(true)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=75
 await physics_frame
 var plan:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
 await capture_views(plan)
 print("LANDING_REPAIR_CAPTURE_PASS");quit()
func capture_views(plan:Variant)->void:
 player.position=Vector3(-3.5,1.,12)
 var north=plan.bridges[0];var end:=vec(north.end);var d:=Vector3(north.direction[0],0,-north.direction[1]);var side:=Vector3(-d.z,0,d.x)
 await capture("north_arrival",end-d*4.+Vector3.UP*1.7,end+d*4.+Vector3.UP*1.1)
 await capture("north_landing_side",Vector3(56,10,-33),Vector3(59,4.8,-40))
 await capture("south_connection",Vector3(84,8.2,16),Vector3(78.5,5.3,21.3))
 await capture("south_bank_side",Vector3(75,10,32),Vector3(81,4.9,21))
 await capture("north_south_connection",Vector3(92,8.5,21),Vector3(86.4,4.0,17))
 await capture("weathered_rocks",Vector3(62,10,-51),Vector3(53.3,9,-58))
 await capture("midday_deck",Vector3(50,7.05,19.7),Vector3(0,3.7,15.7))
 await capture("north_night",end-d*4.+Vector3.UP*1.7,end+d*4.+Vector3.UP*1.1,.75)
