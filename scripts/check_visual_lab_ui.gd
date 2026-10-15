extends SceneTree
const OUT:="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func snapshot(path:String)->void:
 for i in range(15):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+path+".png")
func run()->void:
 root.size=Vector2i(1280,900)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 var water=main.get_node("AnimatedWater");water.set_process(false);water.set_water_time(0.)
 var lab=main.get_node("VisualLab");var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65.
 camera.global_position=Vector3(-3.5,7,17);camera.look_at(Vector3(-3.5,7.5,0))
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 lab.select_preset(0)
 lab.set_panel_open(true)
 await snapshot("visual_lab_original_ui")
 lab.select_preset(1)
 await snapshot("visual_lab_void_ui")
 lab._tabs.current_tab=1
 await snapshot("visual_lab_light_ui")
 lab._tabs.current_tab=3
 await snapshot("visual_lab_lens_ui")
 root.size=Vector2i(1280,720)
 await snapshot("visual_lab_720_ui")
 print("LAB_LAYOUT ",lab._panel.get_global_rect()," status ",lab._status.get_global_rect())
 root.size=Vector2i(1280,900);lab.set_panel_open(false)
 for i in lab.Profiles.PRESETS.size():
  lab.select_preset(i)
  await snapshot("visual_lab_preset_"+lab.Profiles.PRESETS[i].id)
 lab.select_preset(3)
 lab._on_value_changed(.18,"temperature");lab._on_value_changed(65.,"fov")
 var ground_query:=PhysicsRayQueryParameters3D.create(Vector3(-3.5,40,17),Vector3(-3.5,-20,17))
 var ground:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(ground_query);assert(not ground.is_empty())
 player.global_position=ground.position+Vector3(0,.01,0);camera.global_position=player.global_position+Vector3(0,1.65,0);camera.look_at(Vector3(-3.5,7.5,0))
 player.rotation=Vector3(0,camera.rotation.y,0);player.get_node("Head").rotation=Vector3(camera.rotation.x,0,0)
 lab._name_edit.text="Coastal gold example";assert(not lab.save_profile("Coastal gold example").is_empty())
 lab._tabs.current_tab=0;lab.set_panel_open(true)
 for i in range(45):await process_frame
 await snapshot("visual_lab_saved_ui")
 print("VISUAL_LAB_UI_CAPTURE_PASS")
 quit()
