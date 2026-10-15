extends SceneTree
const OUT:="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func measure(label:String)->Dictionary:
 var t:=Time.get_ticks_usec()
 while Time.get_ticks_usec()-t<1000000:await process_frame
 var count:=0;t=Time.get_ticks_usec()
 while Time.get_ticks_usec()-t<2000000:await process_frame;count+=1
 var row:={"view":label,"fps":float(count)*1000000./float(Time.get_ticks_usec()-t)};print("LAB_BENCH ",JSON.stringify(row));return row
func run()->void:
 root.size=Vector2i(1280,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 main.get_node("RenderOptimization").set_performance_mode(true,false)
 var lab=main.get_node("VisualLab");lab._launcher.hide()
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65.;camera.global_position=Vector3(-3.5,7,17);camera.look_at(Vector3(-3.5,7.5,0))
 var rows:=[]
 lab.select_preset(0);assert(not lab._post.visible);rows.append(await measure("original_lab_closed"))
 lab.select_preset(1);rows.append(await measure("void_light_lab_closed"))
 lab.set_panel_open(true);rows.append(await measure("void_light_lab_open"))
 lab.set_panel_open(false);lab.select_preset(0);lab.queue_free();await process_frame
 rows.append(await measure("original_without_lab"))
 FileAccess.open(OUT+"visual_lab_fps.json",FileAccess.WRITE).store_string(JSON.stringify({"resolution":[1280,900],"quality":"Performance","views":rows},"  "));quit()
