extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
var main:Node3D
var player:CharacterBody3D
var camera:Camera3D
var clock:Node3D
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func ray(p:Vector3,up:float=3.,down:float=12.,excluded:Array[RID]=[])->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*up,p-Vector3.UP*down);q.exclude=excluded if not excluded.is_empty() else [player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func capture(label:String,point:Vector3,target:Vector3,phase:float)->void:
 camera.position=point;camera.look_at(target);clock.set_phase(phase)
 var start:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<1100:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"north_pagoda_"+label+".png")
func walk_to(target:Vector3,max_steps:int=250)->bool:
 var steps:=0
 while Vector2(player.position.x-target.x,player.position.z-target.z).length()>.28 and steps<max_steps:
  var d:=Vector3(target.x-player.position.x,0,target.z-player.position.z).normalized();player.rotation.y=atan2(-d.x,-d.z)
  Input.action_press("move_forward");await physics_frame;player._physics_process(1./60.);steps+=1
 Input.action_release("move_forward")
 return Vector2(player.position.x-target.x,player.position.z-target.z).length()<.35
func run()->void:
 if DisplayServer.get_name()=="headless":Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 root.size=Vector2i(1280,900);root.always_on_top=true;root.grab_focus()
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide();player.capture_mouse(true)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide();main.get_node("RenderOptimization").set_performance_mode(false,false)
 clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
 await physics_frame
 await capture_views();print("NORTH_PAGODA_CAPTURE_PASS");quit()
func lp(x:float,y:float,z:float)->Vector3:
 var a:float=-.88
 return Vector3(92+cos(a)*x-sin(a)*y,5.5+z,-64-sin(a)*x-cos(a)*y)
func capture_views()->void:
 player.position=Vector3(-3.5,1,12)
 await capture("day",Vector3(73,20,-43),Vector3(92,14,-64),.25)
 await capture("night",Vector3(73,20,-43),Vector3(92,14,-64),.75)
 await capture("entrance",lp(0,-14,2.4),lp(0,-1,4),.25)
 await capture("interior",lp(3.6,-4.3,2.65),lp(0,0,4.8),.25)
 await capture("second_floor",lp(-3.2,-3.2,7.05),lp(1.2,.5,7.9),.25)
 await capture("third_floor",lp(-3.2,-3.2,11.45),lp(1.2,.5,12.3),.25)
 await capture("lantern_mount",lp(-4.4,-5.0,3.2),lp(-5.15,-5.15,4.4),.75)
 await capture("sidewalk",Vector3(59.1,6.87,-40.5),Vector3(69,5.5,-41),.25)
 await capture("sidewalk_overview",Vector3(67,15,-34),Vector3(70,4.8,-42),.25)
