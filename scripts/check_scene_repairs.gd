extends SceneTree
const OUTPUT := "/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize() -> void:
	call_deferred("run_checks")
func run_checks() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.get_node("CanvasLayer").hide()
	root.size = Vector2i(1280,900)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.current = true
	camera.near = .04
	camera.fov = 65
	var views := [
		["game_fixed_rear_lab",Vector3(-4.15,7.1,-7.35),Vector3(-3.02,5.65,-10.9)],
		["game_fixed_pillars",Vector3(-3.5,8.8,16),Vector3(-3.5,7.5,0)],
		["game_fixed_planter",Vector3(0,1.35,11),Vector3(-1.04,.27,9.86)],
		["game_fixed_fountain_back",Vector3(9,6.7,-1.2),Vector3(4.5,5,-3.5)],
		["game_fixed_bust",Vector3(1.9,6.35,-5.15),Vector3(4.2,5.65,-7.3)],
		["game_gscatter_ground",Vector3(-12,4,12),Vector3(-18,2,3)],
		["game_gscatter_overview",Vector3(112,115,118),Vector3(25,0,-15)]
	]
	var frames := []
	for v in views:
		camera.global_position = v[1]
		camera.look_at(v[2],Vector3.UP)
		for i in range(25): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUTPUT+v[0]+".png")
		frames.append({"view":v[0],"fps":Engine.get_frames_per_second(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		print("CAPTURED ",v[0])
	var ground = main.get_node("IslandGroundCover")
	assert(ground.instance_total>6000)
	var report = {"ground_cover_instances":ground.instance_total,"spatial_batches":ground.patch_total,"views":frames}
	var f = FileAccess.open(OUTPUT+"game_scene_repairs_validation.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(report,"  "))
	print("GAME_SCENE_CHECKS ",JSON.stringify(report))
	quit(0)
