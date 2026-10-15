extends SceneTree

func _initialize() -> void:
	call_deferred("capture_views")

func capture_views() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	player.set_physics_process(false)
	root.size = Vector2i(1280, 900)
	for view in [
		["entrance_game.png", Vector3(-3.5, 4.525, 4.8), Vector3(-3.5, 6.2, -3.0)],
		["interior_game.png", Vector3(-5.15, 4.525, -3.5), Vector3(-3.5, 6.3, -9.8)]
	]:
		player.global_position = view[1]
		var camera: Camera3D = player.get_node("Head/Camera3D")
		camera.look_at(view[2], Vector3.UP)
		for i in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_texture().get_image()
		img.save_png("/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/" + view[0])
		print("CAPTURED ", view[0])
	quit()
