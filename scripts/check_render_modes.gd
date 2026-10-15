extends SceneTree
const OUT := "/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize() -> void: call_deferred("check")
func check() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("This visual input check requires a rendering window.")
		quit(2)
		return
	root.size=Vector2i(1280,900)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var render=main.get_node("RenderOptimization")
	var had_settings:=FileAccess.file_exists(render.SETTINGS_FILE)
	var old_settings:=FileAccess.get_file_as_bytes(render.SETTINGS_FILE) if had_settings else PackedByteArray()
	var old_mode:bool=render.performance_mode
	render.set_performance_mode(false,false)
	for i in range(20):await process_frame
	assert(is_equal_approx(root.scaling_3d_scale,1.0))
	assert(root.msaa_3d==Viewport.MSAA_4X)
	assert(render.tree_count==91 and render.trees.size()==91)
	var grass_rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/gscatter_ground_cover_instances.json"))
	assert(main.get_node("IslandGroundCover").instance_total==grass_rows.size())
	var water=main.get_node("AnimatedWater");var start:float=water.elapsed
	var press:=InputEventKey.new();press.physical_keycode=KEY_F6;press.keycode=KEY_F6;press.pressed=true
	Input.parse_input_event(press)
	for i in range(25):await process_frame
	assert(render.performance_mode and is_equal_approx(root.scaling_3d_scale,.75))
	assert(root.msaa_3d==Viewport.MSAA_2X)
	assert("Performance" in render.hud_label.text)
	var config:=ConfigFile.new();assert(config.load(render.SETTINGS_FILE)==OK)
	assert(config.get_value("graphics","performance_mode")==true)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"fps_performance_hud.png")
	var echo:=press.duplicate();echo.echo=true;Input.parse_input_event(echo)
	await process_frame
	assert(render.performance_mode)
	var release:=press.duplicate();release.pressed=false;Input.parse_input_event(release)
	await process_frame
	Input.parse_input_event(press)
	for i in range(25):await process_frame
	assert(not render.performance_mode and is_equal_approx(root.scaling_3d_scale,1.0))
	assert(root.msaa_3d==Viewport.MSAA_4X)
	assert(water.elapsed>start and water.materials.size()==13)
	assert("Balanced" in render.hud_label.text)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+"fps_balanced_hud.png")
	if had_settings:FileAccess.open(render.SETTINGS_FILE,FileAccess.WRITE).store_buffer(old_settings)
	else:DirAccess.remove_absolute(ProjectSettings.globalize_path(render.SETTINGS_FILE))
	render.set_performance_mode(old_mode,false)
	FileAccess.open(OUT+"render_modes_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"trees":91,"grass":grass_rows.size(),"water_surfaces":13,"f6_toggle":true,"key_repeat_ignored":true,"preference_saved_and_test_restored":true,"water_clock_advances":true,"native_resolution_restored":true},"  "))
	print("RENDER_MODES_PASS")
	quit()
