extends SceneTree
## Verifies bidirectional player walking between the island plateaus, waterline, and underwater bottom
## on all three islands (Main, North, South), plus the tightened top-left South Island sidewalk.

const OUT = "/home/allister/Projects/live-aligned-previews/island-shore-slopes-2026-10-18/"
var main: Node3D
var player: CharacterBody3D
var camera: Camera3D
var report: Dictionary = {"walks": [], "profiles": {}}


func _initialize() -> void:
	call_deferred("run")


func vec(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


func ray(p: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3.UP * 25.0, p - Vector3.UP * 25.0)
	q.exclude = [player.get_rid()]
	return main.get_world_3d().direct_space_state.intersect_ray(q)


func walk_waypoints(points: Array, label: String, expect_bottom_start: bool = false, expect_bottom_end: bool = false) -> void:
	var start_pt := vec(points[0])
	var start_hit := ray(start_pt)
	assert(not start_hit.is_empty(), "Missing ground at start of " + label + " " + str(start_pt))
	player.position = Vector3(start_pt.x, start_hit.position.y + 0.06, start_pt.z)
	player.velocity = Vector3.ZERO
	await physics_frame

	var start_y := player.position.y
	if expect_bottom_start:
		assert(start_y <= -6.6, "Expected underwater bottom start for " + label + ", got y=" + str(start_y))
	else:
		assert(start_y >= 1.5, "Expected upper island start for " + label + ", got y=" + str(start_y))

	var total_steps: int = 0
	var min_y: float = start_y
	var max_y: float = start_y
	var crossed_waterline: bool = false

	for idx in range(1, points.size()):
		var target := vec(points[idx])
		var seg_steps: int = 0
		while Vector2(target.x - player.position.x, target.z - player.position.z).length() > 0.25 and seg_steps < 900:
			var toward := Vector3(target.x - player.position.x, 0.0, target.z - player.position.z).normalized()
			player.rotation.y = atan2(-toward.x, -toward.z)
			Input.action_press("move_forward")
			await physics_frame
			player._physics_process(1.0 / 60.0)
			seg_steps += 1
			total_steps += 1
			min_y = minf(min_y, player.position.y)
			max_y = maxf(max_y, player.position.y)
			if absf(player.position.y - (-5.0)) < 0.35:
				crossed_waterline = true
		Input.action_release("move_forward")
		var err := Vector2(target.x - player.position.x, target.z - player.position.z).length()
		if err >= 0.35:
			for c_i in player.get_slide_collision_count():
				print("SHORE_BLOCKER ", label, " -> ", player.get_slide_collision(c_i).get_collider().get_path())
		assert(err < 0.35, "Blocked on " + label + " at waypoint " + str(idx) + " pos=" + str(player.position) + " err=" + str(err))

	var end_y := player.position.y
	if expect_bottom_end:
		assert(end_y <= -6.6, "Expected underwater bottom finish for " + label + ", got y=" + str(end_y))
	else:
		assert(end_y >= 1.5, "Expected upper island finish for " + label + ", got y=" + str(end_y))
	assert(crossed_waterline, "Did not cross waterline (y=-5.0) during " + label)

	var row := {
		"label": label,
		"steps": total_steps,
		"start_y": snappedf(start_y, 0.01),
		"end_y": snappedf(end_y, 0.01),
		"min_y": snappedf(min_y, 0.01),
		"max_y": snappedf(max_y, 0.01),
	}
	report.walks.append(row)
	print("SHORE_WALK_PASS ", JSON.stringify(row))


func capture(label: String, pos: Vector3, target: Vector3, fov: float = 55.0) -> void:
	camera.fov = fov
	camera.position = pos
	camera.look_at(target, Vector3.UP)
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 900:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT + label + ".png")


func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var headless: bool = DisplayServer.get_name() == "headless"
	var views_only: bool = "--views-only" in OS.get_cmdline_user_args()
	if headless:
		Engine.physics_ticks_per_second = 240
		Engine.time_scale = 4.0
	root.size = Vector2i(1600, 900)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.get_node("CanvasLayer").hide()
	player.walk_speed = 5.0
	player.capture_mouse(true)
	for npc in main.get_node("IslandCharacters").get_children():
		npc.set_physics_process(false)
		npc.position = Vector3(0, -100, 0)
	main.get_node("VisualLab").select_preset(0)
	main.get_node("RenderOptimization").set_performance_mode(false, false)
	main.get_node("DayNightCycle").running = false
	main.get_node("DayNightCycle").set_phase(0.25)
	await physics_frame

	if not views_only:
		var beach_routes := [
			{
				"name": "Main_Island_South_Beach",
				"points": [[-8.0, 3.05, 19.0], [-8.0, 3.26, 27.0], [-8.0, -1.0, 36.0], [-8.0, -5.0, 44.0], [-8.0, -7.25, 48.5]],
			},
			{
				"name": "Main_Island_East_Beach",
				"points": [[14.5, 2.25, -16.5], [19.5, 1.52, -16.5], [32.0, -2.0, -16.5], [41.5, -5.0, -16.5], [48.5, -7.25, -16.5]],
			},
			{
				"name": "North_Island_East_Beach",
				"points": [[106.0, 5.1, -64.0], [112.0, 3.8, -64.0], [122.0, -0.2, -64.0], [133.5, -5.0, -64.0], [139.5, -7.3, -64.0]],
			},
			{
				"name": "North_Island_SSE_Beach",
				"points": [[96.0, 5.3, -51.0], [96.0, 3.95, -45.0], [96.0, 0.15, -36.0], [96.0, -5.0, -25.0], [96.0, -7.4, -19.0]],
			},
			{
				"name": "South_Island_East_Beach",
				"points": [[118.5, 4.73, 38.0], [121.0, 4.3, 38.0], [131.0, -0.3, 38.0], [142.0, -5.0, 38.0], [148.5, -7.8, 38.0]],
			},
			{
				"name": "South_Island_South_Beach",
				"points": [[114.5, 4.73, 41.5], [114.5, 4.6, 44.5], [114.5, 0.0, 55.0], [114.5, -5.0, 65.5], [114.5, -7.8, 72.0]],
			},
		]

		for b in beach_routes:
			var pts: Array = b.points
			await walk_waypoints(pts, b.name + "_down_to_bottom", false, true)
			var rev: Array = pts.duplicate()
			rev.reverse()
			await walk_waypoints(rev, b.name + "_up_from_bottom", true, false)

	if not headless:
		camera = Camera3D.new()
		camera.current = true
		main.add_child(camera)
		player.visible = false
		await process_frame

		# 1. Exact top-down view of South Island matching the user's screenshot framing
		await capture("south_island_topdown_tightened_sidewalk", Vector3(101.0, 44.0, 34.0), Vector3(101.0, 4.65, 33.99), 52.0)
		# 2. Close-up of the tightened top-left South Island sidewalk junction
		await capture("south_island_top_left_sidewalk_closeup", Vector3(84.5, 22.0, 23.0), Vector3(85.5, 4.7, 22.99), 50.0)
		# 3. South Island East & South sloped beaches
		await capture("south_island_east_and_south_beaches", Vector3(154.0, 22.0, 66.0), Vector3(118.0, -1.0, 44.0), 58.0)
		# 4. Main Island South & East sloped beaches
		await capture("main_island_south_and_east_beaches", Vector3(-22.0, 19.0, 54.0), Vector3(4.0, -1.5, 20.0), 58.0)
		# 5. North Island East & SSE sloped beaches
		await capture("north_island_east_and_sse_beaches", Vector3(146.0, 23.0, -24.0), Vector3(104.0, 0.0, -56.0), 58.0)
		# 6. High overview of all three sloped islands
		await capture("overview_all_three_sloped_islands", Vector3(58.0, 115.0, 95.0), Vector3(62.0, 0.0, -5.0), 60.0)

	FileAccess.open(OUT + "shore_slope_validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("ISLAND_SHORE_SLOPES_PASS walks=", report.walks.size())
	quit()
