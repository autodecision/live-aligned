extends SceneTree

func _initialize() -> void:
	call_deferred("capture_views")

func capture_views() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	player.set_physics_process(false)
	root.size = Vector2i(1280, 900)
	var camera: Camera3D = player.get_node("Head/Camera3D")

	var views = [
		["res://screenshot.png", Vector3(-3.5, 1.2, 12.0), Vector3(-3.5, 4.0, 0.0)],
		["res://terrace_bust_game.png", Vector3(1.5, 4.5, 8.5), Vector3(4.2, 4.5, 7.3)],
		["res://coastline_rocks_game.png", Vector3(-15.0, 6.0, 15.0), Vector3(-3.5, 4.0, 0.0)]
	]

	for v in views:
		player.global_position = v[1]
		camera.look_at(v[2], Vector3.UP)
		for i in range(30):
			await process_frame
		await RenderingServer.frame_post_draw
		var img = root.get_texture().get_image()
		img.save_png(v[0])
		print("CAPTURED ", v[0])

	quit(0)
