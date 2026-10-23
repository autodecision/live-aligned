extends SceneTree
## Opens the playable garden without changing the normal game spawn or saved look.
func _initialize()->void:call_deferred("run")
func run()->void:
 var main:Node3D = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 current_scene = main
 await physics_frame
 var player:CharacterBody3D = main.get_node("Player")
 player.global_position = Vector3(102.9,4.8,29.0)
 player.velocity = Vector3.ZERO
 player.rotation.y = .95
 player.head.rotation.x = -.18
 player.spawn_point = player.global_position
