extends SceneTree

func _init():
	var scene = load("res://assets/mediterranean_temple.glb")
	if not scene:
		print("ERROR: could not load scene")
		quit(1)
		return
	var inst = scene.instantiate()
	print("Scene root: ", inst.name, " child count: ", inst.get_child_count())
	var static_body_count := 0
	var collision_shape_count := 0
	var mesh_count := 0
	
	var stack: Array[Node] = [inst]
	while not stack.is_empty():
		var current: Node = stack.pop_back()
		if current is StaticBody3D:
			static_body_count += 1
		elif current is CollisionShape3D:
			collision_shape_count += 1
		elif current is MeshInstance3D:
			mesh_count += 1
		for child in current.get_children():
			stack.push_back(child)
			
	print("INSPECTION RESULTS:")
	print("  MeshInstance3D count: ", mesh_count)
	print("  StaticBody3D count: ", static_body_count)
	print("  CollisionShape3D count: ", collision_shape_count)
	quit(0)
