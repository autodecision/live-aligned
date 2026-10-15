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
 root.size=Vector2i(1280,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 main.get_node("RenderOptimization").set_performance_mode(true,false)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 cycle=main.get_node("DayNightCycle");cycle.running=false
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
 await physics_frame
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
