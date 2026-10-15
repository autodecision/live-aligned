extends SceneTree
## Verify the closed wall strips and open windows; optionally capture both rooms.
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/pagoda_window_wall_checks/"
var main:Node3D
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func lp(x:float,y:float,z:float)->Vector3:
 var a:float=-.88
 return Vector3(92+cos(a)*x-sin(a)*y,5.5+z,-64-sin(a)*x-cos(a)*y)
func wall_ray(side:int,half:float,q:float,z:float)->Dictionary:
 var a:float=-side*PI/2.;var nx:float=-sin(a);var ny:float=cos(a)
 var x:float=nx*half+cos(a)*q;var y:float=ny*half+sin(a)*q
 var query:=PhysicsRayQueryParameters3D.create(lp(x-nx,y-ny,z),lp(x+nx,y+ny,z))
 return main.get_world_3d().direct_space_state.intersect_ray(query)
func capture(label:String,point:Vector3,target:Vector3)->void:
 root.grab_focus();camera.position=point;camera.look_at(target)
 for i in range(30):await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUT+label+".png")
func run()->void:
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player:CharacterBody3D=main.get_node("Player")
 player.set_physics_process(false);player.set_process_unhandled_input(false)
 player.position=Vector3(-3.5,1,12);player.get_node("CanvasLayer").hide()
 main.get_node("VisualLab").select_preset(0)
 var clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 await physics_frame
 var pagoda:Node3D=main.get_node("NorthPagoda")
 assert(pagoda.plan.window_wall_infill_panels==24)
 var panels:MeshInstance3D=pagoda.find_child("North_Pagoda_Pagoda_Window_Wall_Infill",true,false)
 var cedar:MeshInstance3D=pagoda.find_child("North_Pagoda_Pagoda_Red_Cedar",true,false)
 assert(panels!=null and cedar!=null)
 assert(panels.mesh.surface_get_material(0)==cedar.mesh.surface_get_material(0),"Infill must share the pillar material")
 var closed:=0;var open:=0
 for room in [Vector2(5.4,5.3),Vector2(9.8,4.65)]:
  for side in range(4):
   for q in [-room.y*.9,0.,room.y*.9]:
    for height in [1.1,2.,2.9]:
     var hit:=wall_ray(side,room.y,q,room.x+height)
     assert(not hit.is_empty(),"Unsealed window-side or corner wall")
     assert(hit.collider==pagoda.get_node("PagodaStructure"))
     closed+=1
   for q in [-room.y*.43,room.y*.43]:
    assert(wall_ray(side,room.y,q,room.x+2.).is_empty(),"Infill blocked a lattice window")
    open+=1
 print("PAGODA_WINDOW_WALLS_PASS closed_samples=",closed," open_windows=",open," shared_pillar_material=true")
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
