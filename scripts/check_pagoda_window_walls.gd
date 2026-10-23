extends SceneTree
## Verify window barriers, real player jump attempts, and the existing wall infill.
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/pagoda_window_wall_checks/"
var main:Node3D
var camera:Camera3D
var player:CharacterBody3D
var jump_attempts:int=0
func jump_at_window(side:int,half:float,q:float,floor_z:float,diagonal:float)->void:
 var angle:float=-side*PI/2.0
 var nx:float=-sin(angle);var ny:float=cos(angle)
 var wall_x:float=nx*half+cos(angle)*q
 var wall_y:float=ny*half+sin(angle)*q
 var outward:Vector3=(lp(wall_x+nx,wall_y+ny,floor_z)-lp(wall_x,wall_y,floor_z)).normalized()
 var tangent:Vector3=(lp(wall_x+cos(angle),wall_y+sin(angle),floor_z)-lp(wall_x,wall_y,floor_z)).normalized()
 # Start on the sill, already airborne and sprinting: even this higher jump
 # must hit a window rather than getting stopped by the lower plaster wall.
 player.position=lp(wall_x-nx*.9,wall_y-ny*.9,floor_z+.94)
 player.velocity=Vector3.ZERO
 player.reset_physics_interpolation()
 var direction:Vector3=(outward+tangent*diagonal).normalized()
 player.rotation.y=atan2(-direction.x,-direction.z)
 await physics_frame
 player.velocity=direction*player.sprint_speed+Vector3.UP*player.jump_velocity
 Input.action_press('move_forward');Input.action_press('sprint')
 var touched_window:=false
 var wall_point:Vector3=lp(wall_x,wall_y,floor_z)
 for step:int in range(84):
  await physics_frame
  player._physics_process(1.0/60.0)
  assert((player.position-wall_point).dot(outward)<-.30,'Player escaped through lattice window')
  for hit:int in player.get_slide_collision_count():
   touched_window=touched_window or player.get_slide_collision(hit).get_collider().name=='PagodaWindows'
 Input.action_release('move_forward');Input.action_release('sprint')
 assert(touched_window,'Jump did not exercise the window barrier')
 jump_attempts+=1
func _initialize()->void:call_deferred("run")
func lp(x:float,y:float,z:float)->Vector3:
 var a:float=-.88
 return Vector3(92+cos(a)*x-sin(a)*y,5.5+z,-64-sin(a)*x-cos(a)*y)
func wall_ray(side:int,half:float,q:float,z:float)->Dictionary:
 var a:float=-side*PI/2.;var nx:float=-sin(a);var ny:float=cos(a)
 var x:float=nx*half+cos(a)*q;var y:float=ny*half+sin(a)*q
 var query:=PhysicsRayQueryParameters3D.create(lp(x-nx,y-ny,z),lp(x+nx,y+ny,z))
 query.exclude=[player.get_rid(),main.get_node('NorthPagoda/InteriorFurnishings/FurnitureCollision').get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(query)
func capture(label:String,point:Vector3,target:Vector3)->void:
 root.grab_focus();camera.position=point;camera.look_at(target)
 for i in range(30):await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUT+label+".png")
func run()->void:
 if DisplayServer.get_name()=='headless':
  Engine.physics_ticks_per_second=240
  Engine.time_scale=4.0
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player")
 player.set_physics_process(false);player.set_process_unhandled_input(false)
 player.position=Vector3(-3.5,1,12);player.get_node("CanvasLayer").hide()
 main.get_node("VisualLab").select_preset(0)
 var clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 for npc:Node in main.get_node('IslandCharacters').get_children():npc.set_physics_process(false)
 player.capture_mouse(true)
 await physics_frame
 var pagoda:Node3D=main.get_node("NorthPagoda")
 assert(pagoda.plan.window_wall_infill_panels==24)
 var panels:MeshInstance3D=pagoda.find_child("North_Pagoda_Pagoda_Window_Wall_Infill",true,false)
 var cedar:MeshInstance3D=pagoda.find_child("North_Pagoda_Pagoda_Red_Cedar",true,false)
 assert(panels!=null and cedar!=null)
 assert(panels.mesh.surface_get_material(0)==cedar.mesh.surface_get_material(0),"Infill must share the pillar material")
 assert(pagoda.get_node('PagodaWindows').get_child_count()==8)
 var closed:=0;var windows:=0
 for room in [Vector2(5.4,5.3),Vector2(9.8,4.65)]:
  for side in range(4):
   for q in [-room.y*.9,0.,room.y*.9]:
    for height in [1.1,2.,2.9]:
     var hit:=wall_ray(side,room.y,q,room.x+height)
     assert(not hit.is_empty(),"Unsealed window-side or corner wall")
     assert(hit.collider in [pagoda.get_node("PagodaStructure"),pagoda.get_node('PagodaWindows')],str(hit.collider.get_path()))
     closed+=1
   for q in [-room.y*.43,room.y*.43]:
    for height:float in [1.0,1.5,2.0,2.5,3.0]:
     var hit:=wall_ray(side,room.y,q,room.x+height)
     assert(not hit.is_empty() and hit.collider==pagoda.get_node('PagodaWindows'),'Unblocked lattice window')
    windows+=1
    for diagonal:float in [-.35,0.,.35]:await jump_at_window(side,room.y,q,room.x,diagonal)
 print("PAGODA_WINDOW_WALLS_PASS closed_samples=",closed," blocked_windows=",windows," physical_jumps=",jump_attempts," shared_pillar_material=true")
 if DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(OUT)
  root.size=Vector2i(1280,900);root.always_on_top=true
  Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
  main.get_node("RenderOptimization").set_performance_mode(false,false)
  camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=72
  await capture("second_floor_corner",lp(3.15,3.15,7.05),lp(5.3,5.3,7.6))
  await capture("second_floor_center",lp(.25,3.15,7.05),lp(0,5.3,7.5))
  await capture("third_floor_corner",lp(2.6,2.6,11.45),lp(4.65,4.65,12.0))
  await capture("third_floor_center",lp(.25,2.8,11.45),lp(0,4.65,11.9))
  print("PAGODA_WINDOW_WALLS_CAPTURES ",OUT)
 quit()
