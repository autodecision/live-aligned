extends SceneTree

var main: Node3D
var player: CharacterBody3D
var checks := {}

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	player = main.get_node("Player")
	for i in range(30):
		await physics_frame
	# Travel from the existing spawn up the stair and into the sanctuary.
	Input.action_press("move_forward")
	for i in range(600):
		await physics_frame
		if player.global_position.z < -7.2:
			break
	Input.action_release("move_forward")
	for i in range(20):
		await physics_frame
	checks["spawn_stairs_to_interior"] = player.global_position.z < -6.8 and player.is_on_floor() and abs(player.global_position.y - 4.525) < 0.04
	print("INTERIOR_POSITION ", player.global_position)
	# The doorway remains passable across three capsule center lanes.
	for lane in [-3.85, -3.5, -3.15]:
		player.global_position = Vector3(lane, 4.55, 1.05)
		player.velocity = Vector3.ZERO
		Input.action_press("move_forward")
		for i in range(90):
			await physics_frame
		Input.action_release("move_forward")
		for i in range(12):
			await physics_frame
		checks["entrance_lane_" + str(lane)] = player.global_position.z < -4.0 and player.is_on_floor()
	# Leave through the same entrance and colonnade, without jumping.
	player.global_position = Vector3(-3.5, 4.55, -5.0)
	player.velocity = Vector3.ZERO
	Input.action_press("move_backward")
	for i in range(240):
		await physics_frame
		if player.global_position.z > 1.4:
			break
	Input.action_release("move_backward")
	for i in range(12):
		await physics_frame
	checks["exit_through_door"] = player.global_position.z > 1.4 and player.is_on_floor()
	var space = main.get_world_3d().direct_space_state
	for side in [-1.0, 1.0]:
		var query = PhysicsRayQueryParameters3D.create(Vector3(-3.5, 5.6, -5), Vector3(-3.5 + side*4.0, 5.6, -5), 1)
		checks["solid_side_wall_" + str(side)] = not space.intersect_ray(query).is_empty()
	var failed := false
	for key in checks:
		if not checks[key]:
			failed = true
	print("ENTRANCE_RUNTIME_CHECKS ", JSON.stringify(checks))
	var output = FileAccess.open("res://entrance_runtime_validation.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"checks": checks, "final_position": [player.global_position.x, player.global_position.y, player.global_position.z]}, "  "))
	main.queue_free()
	quit(1 if failed else 0)
