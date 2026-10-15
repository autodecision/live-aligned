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
	var water = main.get_node("AnimatedWater")
	var start: float = water.elapsed
	for i in range(15): await process_frame
	assert(water.elapsed>start,"Water runtime clock must advance")
	assert(water.materials.size()==13)
	water.set_process(false)
	var views := [
		["dense_meadow_main",Vector3(-12,4,12),Vector3(-18,2,3)],
		["dense_meadow_north",Vector3(55,20,-26),Vector3(64,6,-46)],
		["dense_meadow_overview",Vector3(112,115,118),Vector3(25,0,-15)],
		["flowing_water_sea",Vector3(18,1,17),Vector3(11,-3.0,7.5)],
		["flowing_water_cascade",Vector3(10,6,11),Vector3(4.3,1.8,3.4)]
	]
	var differences := {}
	for v in views:
		camera.global_position = v[1]
		camera.look_at(v[2],Vector3.UP)
		var first: Image
		for t in [0.0,1.25]:
			water.set_water_time(t)
			for i in range(18): await process_frame
			await RenderingServer.frame_post_draw
			var picture := root.get_texture().get_image()
			picture.save_png(OUTPUT+v[0]+("_a" if t==0.0 else "_b")+".png")
			if t==0.0: first=picture
			elif String(v[0]).begins_with("flowing"):
				var a=first.get_data();var b=picture.get_data();var changed:=0
				for j in range(a.size()):
					if absi(int(a[j])-int(b[j]))>5: changed+=1
				assert(changed>5000,"Water must visibly change between times")
				differences[v[0]]=changed
		print("CAPTURED ",v[0])
	var ground=main.get_node("IslandGroundCover")
	assert(ground.instance_total==49620)
	var report={"instances":ground.instance_total,"water_surfaces":water.water_mesh_names,"runtime_clock_advances":water.elapsed>start,"changed_pixel_channels":differences}
	FileAccess.open(OUTPUT+"dense_meadow_water_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("MEADOW_WATER_VALIDATED ",JSON.stringify(report))
	quit(0)
