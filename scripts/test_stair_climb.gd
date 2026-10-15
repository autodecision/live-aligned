extends SceneTree

var frame_count: int = 0
var player: CharacterBody3D

func _init():
	var main_scene = load("res://scenes/main.tscn")
	var root_node = main_scene.instantiate()
	root.add_child(root_node)
	player = root_node.get_node("Player") as CharacterBody3D

func _process(delta: float) -> bool:
	frame_count += 1
	Input.action_press("move_forward")
		
	if frame_count % 30 == 0:
		print("Frame ", frame_count, " | pos: ", player.global_position, " | on_floor: ", player.is_on_floor())
		
	if frame_count >= 240:
		Input.action_release("move_forward")
		print("CLIMB COMPLETED: Final pos: ", player.global_position)
		return true
		
	return false
