extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/temple_back_slope_checks/"
var main:Node3D
var player:CharacterBody3D
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func support(x:float,y:float)->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(Vector3(x,30,-y),Vector3(x,-10,-y))
 q.exclude=[player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func walk(x:float,reverse:bool)->void:
 var start:=22. if reverse else 11.
 var finish:=11. if reverse else 22.
 var hit:=support(x,start)
 assert(not hit.is_empty())
 player.position=hit.position+Vector3.UP*.06;player.velocity=Vector3.ZERO
 await physics_frame
 var steps:=0
 while absf(-player.position.z-finish)>.16 and steps<600:
  var d:Vector3=(Vector3(x,player.position.y,-finish)-player.position).normalized()
  player.rotation.y=atan2(-d.x,-d.z)
  Input.action_press("move_forward");await physics_frame;player._physics_process(1./60.)
  steps+=1
 Input.action_release("move_forward")
 if steps>=600:
  for i in player.get_slide_collision_count():print("BACK_SLOPE_BLOCKER ",player.get_slide_collision(i).get_collider().get_path())
 assert(steps<600,"Back slope blocked x="+str(x)+" position="+str(player.position))
 assert(absf(player.position.y-support(x,finish).position.y)<.2,"Lost slope support")
 print("BACK_SLOPE_WALK_PASS x=",x," reverse=",reverse," steps=",steps)
func capture(label:String,p:Vector3,target:Vector3)->void:
 root.grab_focus();camera.position=p;camera.look_at(target)
 for i in range(25):await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUT+label+"_after.png")
func run()->void:
 var headless:=DisplayServer.get_name()=="headless"
 if headless:Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.walk_speed=5.
 main.get_node("VisualLab").select_preset(0)
 var clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 await physics_frame
 var samples:=0
 for y in range(12,22):
  var low:=100.;var high:=-100.
  for x in [9.6,10.7,11.8]:
   var hit:=support(x,y);assert(not hit.is_empty(),"Missing widened slope")
   assert("Cliff_Terrain" in String(hit.collider.get_path()),"Unexpected slope obstruction")
   low=minf(low,hit.position.y);high=maxf(high,hit.position.y);samples+=1
  assert(high-low<.4,"Widened slope has excessive crossfall")
 for x in [9.8,10.8,11.8]:
  for reverse in [false,true]:await walk(x,reverse)
 print("TEMPLE_BACK_SLOPE_PASS supported_samples=",samples," two_way_lane_walks=6")
 if not headless:
  DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1440,900);root.always_on_top=true
  player.position=Vector3(-3.5,1,12);player.get_node("CanvasLayer").hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  main.get_node("RenderOptimization").set_performance_mode(false,false)
  camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=70
  await capture("back_slope_walking",Vector3(8.4,5.6,-13.6),Vector3(8.4,6.4,-21))
  await capture("back_slope_side",Vector3(16,10,-13),Vector3(8.5,4.5,-19))
  await capture("back_slope_overview",Vector3(14,18,-25),Vector3(8.5,4.5,-16))
  await capture("back_slope_new_width",Vector3(10.8,5.4,-12.7),Vector3(10.8,6.4,-21))
 quit()
