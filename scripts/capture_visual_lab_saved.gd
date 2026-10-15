extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1280,900)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 var lab=main.get_node("VisualLab");var water=main.get_node("AnimatedWater");water.set_process(false);water.set_water_time(0.)
 await physics_frame
 var query:=PhysicsRayQueryParameters3D.create(Vector3(-3.5,30,11.5),Vector3(-3.5,-20,11.5))
 var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query);assert(not hit.is_empty())
 player.global_position=hit.position+Vector3(0,.01,0)
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65.;camera.global_position=player.global_position+Vector3(0,1.65,0);camera.look_at(Vector3(-3.5,7.5,0))
 player.rotation=Vector3(0,camera.rotation.y,0);player.get_node("Head").rotation=Vector3(camera.rotation.x,0,0)
 lab.select_preset(3);lab._on_value_changed(.18,"temperature");lab._on_value_changed(65.,"fov")
 lab._name_edit.text="Coastal gold example";assert(not lab.save_profile("Coastal gold example").is_empty());lab.set_panel_open(true)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var t:=Time.get_ticks_usec()
 while Time.get_ticks_usec()-t<1700000:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/visual_lab_saved_ui.png")
 print("SAVED_UI_CAPTURED ",player.global_position);quit()
