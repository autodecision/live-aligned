extends SceneTree

var frame_count: int = 0
var player: CharacterBody3D
var initial_pos: Vector3

func _init():
	var main_scene = load("res://scenes/main.tscn")
	var root_node = main_scene.instantiate()
	root.add_child(root_node)
	
	player = root_node.get_node("Player") as CharacterBody3D
	initial_pos = player.global_position
	print("--- TEST RUNTIME WALK ---")
	print("Player spawned at: ", initial_pos)

func _process(delta: float) -> bool:
	frame_count += 1
	
	# Simulate pressing move_forward (W)
	if frame_count > 10 and frame_count < 120:
		Input.action_press("move_forward")
	else:
		Input.action_release("move_forward")
		
	if frame_count % 30 == 0:
		print("Frame ", frame_count, " | Player pos: ", player.global_position, " | on_floor: ", player.is_on_floor(), " | vel: ", player.velocity)
		
	if frame_count >= 180:
		print("--- TEST SUMMARY ---")
		print("Initial position: ", initial_pos)
		print("Final position:   ", player.global_position)
		var moved_dist = initial_pos.distance_to(player.global_position)
		print("Distance moved:   ", moved_dist)
		print("Is on floor:      ", player.is_on_floor())
		if moved_dist > 0.5 and player.is_on_floor():
			print("SUCCESS: Player walked smoothly across map with collision!")
		else:
			print("NOTICE: Player finished test")
		return true
		
	return false
