extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/bridge_approach_checks/"
func _initialize()->void:call_deferred("run")
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size=Vector2i(1440,900);root.always_on_top=true;root.grab_focus()
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 player.position=Vector3(-3.5,1,12);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 var clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 var camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=70
 var suffix="before" if "--before" in OS.get_cmdline_user_args() else "after"
 var views=[
 ["north_threshold",Vector3(17.0,3.9,-30.7),Vector3(26,2.9,-32.7)],
 ["north_shore",Vector3(28,11,-23),Vector3(20,1,-32)],
 ["south_original",Vector3(-3.4,3.9,15.4),Vector3(6,2.2,16)],
 ["south_shore",Vector3(11,12,28),Vector3(-1,1.6,20)],
 ["south_overview",Vector3(-2,21,30),Vector3(0,1,15)],
 ["north_overview",Vector3(15,24,-29),Vector3(22,1,-31)]
 ]
 var plan:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
 for bridge in plan.bridges:
  if bridge.name not in ["Main_North","Main_South"]:continue
  var a:=Vector3(bridge.start[0],bridge.start[1],bridge.start[2])
  var d:=Vector3(bridge.direction[0],0,-bridge.direction[1])
  views.append(["north_walking" if bridge.name=="Main_North" else "south_walking",a-d*1.7+Vector3.UP*1.55,a+d*7.+Vector3.UP*.3])
 for view in views:
  root.grab_focus()
  camera.position=view[1];camera.look_at(view[2])
  for i in range(18):await process_frame
  RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUT+view[0]+"_"+suffix+".png")
  print("BRIDGE_APPROACH_CAPTURE ",view[0]," ",suffix)
 quit()
