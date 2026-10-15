extends SceneTree

func _init():
	var scene = load("res://assets/mediterranean_temple.glb")
	var inst: Node3D = scene.instantiate()
	
	for child in inst.get_children():
		if "plaza" in child.name.to_lower() or "stylobate" in child.name.to_lower() or "stair" in child.name.to_lower():
			if child is Node3D:
				var aabb: AABB
				if child is VisualInstance3D:
					aabb = child.get_aabb()
				print("NODE: ", child.name, " pos: ", child.position, " AABB: ", aabb)
	quit(0)
