extends SceneTree
## Integration check against the actual map, rigs, stairs and bridge deck.
## godot --headless --path . --script res://scripts/check_character_walking.gd
## Windowed -- --capture writes representative views outside the repository.
const OUT := "/tmp/live-aligned-character-walking/"
var main: Node3D
var npcs: Array[Node] = []
var failed := false
var measurements: Dictionary = {}

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func run() -> void:
	var capture := "--capture" in OS.get_cmdline_user_args()
	if not capture:
		Engine.physics_ticks_per_second = 240
		Engine.time_scale = 4.0
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.position = Vector3(-20, 4, 0)
	npcs = main.get_node("IslandCharacters").get_children()
	for npc in npcs:
		npc.set_physics_process(false)
		measurements[npc.name] = {"distance": 0.0, "backward_frames": 0, "moving_frames": 0, "max_stuck": 0.0, "visited": {}, "min_y": 100.0, "max_y": -100.0}
	await physics_frame
	if capture:
		await capture_views(player)
		quit()
		return
	# Long enough for the 160 m round-trip bridge inspection and several surveys.
	for frame in 13200:
		for npc in npcs:
			var before: Vector3 = npc.global_position
			npc._physics_process(1.0 / 60.0)
			var step: Vector3 = npc.global_position - before
			step.y = 0.0
			var m: Dictionary = measurements[npc.name]
			m.distance += step.length()
			m.min_y = minf(m.min_y, npc.position.y)
			m.max_y = maxf(m.max_y, npc.position.y)
			m.max_stuck = maxf(m.max_stuck, npc.stuck_timer)
			if step.length() > 0.006:
				m.moving_frames += 1
				# Asset +Z must point along actual travel, including after turns.
				if npc.model_node.global_basis.z.dot(step.normalized()) < 0.0:
					m.backward_frames += 1
			if npc.current_state == PS3CharacterNPC.State.IDLE:
				m.visited[npc.current_waypoint_idx] = true
		await physics_frame
		if frame % 3600 == 0:
			for npc in npcs:
				print("CHARACTER_PROGRESS ", frame / 60, "s ", npc.name, " destination=", npc.current_waypoint_idx, " stops=", npc.completed_stops, " laps=", npc.completed_laps, " position=", npc.position)
	for npc in npcs:
		var m: Dictionary = measurements[npc.name]
		check(npc.completed_laps >= 1, npc.name + " did not finish its route")
		check(npc.recovery_count == 0, npc.name + " needed an unplanned recovery")
		check(m.max_stuck < 1.0, npc.name + " got stuck on its route")
		check(m.backward_frames == 0, npc.name + " walked backwards")
		check(m.min_y > -0.1, npc.name + " fell below the map")
		for i in npc.route.size():
			if npc.route[i].has("activity"):
				check(m.visited.has(i), npc.name + " missed task " + str(i))
		m["laps"] = npc.completed_laps
		m["stops"] = npc.completed_stops
		m["recoveries"] = npc.recovery_count
		print("CHARACTER_RESULT ", npc.name, " ", JSON.stringify(m))
	check(measurements.Scientist.max_y - measurements.Scientist.min_y > 4.0, "Scientist did not climb and descend temple stairs")
	check(measurements.Robot.distance > 160.0, "Robot did not traverse the bridge and return")
	await check_player_yield(player)
	check_gaits()
	DirAccess.make_dir_recursive_absolute(OUT)
	FileAccess.open(OUT + "validation.json", FileAccess.WRITE).store_string(JSON.stringify({"passed": not failed, "characters": measurements}, "  "))
	print("CHARACTER_WALKING_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func check_gaits() -> void:
	# Inspect the actual rig transforms, including rolled shoulder axes and feet.
	for npc in npcs:
		var minimum := Vector3(INF, INF, INF)
		var maximum := Vector3(-INF, -INF, -INF)
		var hand_min := INF
		var hand_max := -INF
		npc._motion_weight = 1.0
		npc.current_activity = "travel"
		npc.position = Vector3(-3.5, 0.05, 10.5)
		npc.rotation.y = 0.0
		for frame in 60:
			npc._phase = float(frame) / 60.0
			npc._animate(0.0, 0.0)
			var foot: Vector3 = npc.skeleton.get_bone_global_pose(npc.skeleton.find_bone("foot.L")).origin
			var hand: Vector3 = npc.skeleton.get_bone_global_pose(npc.skeleton.find_bone("hand.L")).origin
			minimum = minimum.min(foot)
			maximum = maximum.max(foot)
			hand_min = minf(hand_min, hand.z)
			hand_max = maxf(hand_max, hand.z)
		check(maximum.z - minimum.z > 0.65, npc.name + " stride is too restricted")
		check(maximum.y - minimum.y > 0.10, npc.name + " feet do not clear the ground")
		check(hand_max - hand_min > 0.30, npc.name + " arms do not swing forward and back")
		print("GAIT_RANGE ", npc.name, " foot=", maximum - minimum, " hand_swing=", hand_max - hand_min)

func check_player_yield(player: CharacterBody3D) -> void:
	var npc: PS3CharacterNPC = npcs[2]
	npc.position = npc.waypoints[3]
	npc.current_waypoint_idx = 4
	npc.current_state = PS3CharacterNPC.State.WALK
	var direction: Vector3 = npc.waypoints[4] - npc.position
	direction.y = 0
	direction = direction.normalized()
	npc.rotation.y = atan2(-direction.x, -direction.z)
	npc.velocity = Vector3.ZERO
	player.position = npc.position + direction
	var before := npc.position
	for frame in 90:
		npc._physics_process(1.0 / 60.0)
		await physics_frame
	check(Vector2(npc.position.x - before.x, npc.position.z - before.z).length() < 0.08, "NPC did not yield to the player")
	player.position = Vector3(-20, 4, 0)
	for frame in 120:
		npc._physics_process(1.0 / 60.0)
		await physics_frame
	check(npc.position.distance_to(before) > 1.0, "NPC did not resume after player moved away")

func capture_views(player: CharacterBody3D) -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	root.grab_focus()
	player.get_node("CanvasLayer").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main.get_node("DayNightCycle").running = false
	main.get_node("DayNightCycle").set_phase(0.25)
	main.get_node("VisualLab").select_preset(0)
	var camera := Camera3D.new()
	main.add_child(camera)
	camera.current = true
	camera.fov = 54
	for npc in npcs:
		# Advance normal route behavior into a clear walking stretch.
		for frame in 230:
			npc._physics_process(1.0 / 60.0)
			await physics_frame
		for frame in 90:
			npc._physics_process(1.0 / 60.0)
			await physics_frame
			if frame % 15 == 0:
				var offset := Vector3(2.5, 1.8, -3.0) if npc.name == "Envoy" else Vector3(-3.8, 1.9, 3.5)
				camera.position = npc.position + offset
				camera.look_at(npc.position + Vector3.UP * 1.1)
				await process_frame
				RenderingServer.force_draw(false)
				root.get_texture().get_image().save_png(OUT + String(npc.name) + "_walk_%02d.png" % (frame / 15))
