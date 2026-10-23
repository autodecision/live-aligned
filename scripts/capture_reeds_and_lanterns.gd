extends SceneTree

const OUT = "/home/allister/Projects/live-aligned-previews/garden-reeds-and-lanterns-2026-10-18/"
var main: Node3D
var camera: Camera3D

func _initialize() -> void:
	call_deferred("run")

func capture(label: String, point: Vector3, target: Vector3, phase: float = 0.25) -> void:
	camera.position = point
	camera.look_at(target)
	main.get_node("DayNightCycle").set_phase(phase)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 1200:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT + label + ".png")
	print("CAPTURED: ", label)

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").dialogue_locked = true
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.get_node("CanvasLayer").hide()
	player.position = Vector3(-3.5, 1.2, 12.0)
	main.get_node("CharacterDialogue").hide()
	main.get_node("VisualLab").select_preset(0)
	main.get_node("RenderOptimization").set_performance_mode(false, false)
	main.get_node("DayNightCycle").running = false
	main.get_node("DayNightCycle").set_phase(0.25)
	await physics_frame

	camera = Camera3D.new()
	main.add_child(camera)
	camera.current = true
	camera.fov = 55.0

	# Cluster 1 at (96.0, 37.2) - south rim looking from water level
	await capture("cluster_south_rim", Vector3(96.0, 4.8, 35.8), Vector3(96.0, 4.1, 37.2))

	# Cluster 4 at (94.7, 30.4) - north rim looking from water level
	await capture("cluster_north_rim", Vector3(94.7, 4.8, 31.8), Vector3(94.7, 4.1, 30.4))

	# Cluster 2 at (99.8, 33.0) - east rim
	await capture("cluster_east_rim", Vector3(98.4, 4.8, 33.0), Vector3(99.8, 4.1, 33.0))

	# Cluster 0 at (92.4, 34.8) - west rim near ramp
	await capture("cluster_west_rim", Vector3(93.8, 4.8, 34.8), Vector3(92.4, 4.1, 34.8))

	quit()
