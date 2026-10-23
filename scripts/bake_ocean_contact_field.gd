extends SceneTree
## Rebuild after changing shores, submerged rocks or bridge footings.
## Sample the composed runtime collision, below decks, so foam follows the waterline.
const SIZE := 1024
const ORIGIN := Vector2(-64.0, -112.0)
const EXTENT := Vector2(240.0, 240.0)
const OUTPUT := "res://assets/ocean_contact_field.exr"

func _initialize() -> void:
	call_deferred("bake")

func bake() -> void:
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	main.get_node("Player").set_physics_process(false)
	main.get_node("IslandCharacters").process_mode = Node.PROCESS_MODE_DISABLED
	await physics_frame
	var excluded: Array[RID] = []
	for body: CollisionObject3D in main.find_children("*", "CollisionObject3D", true, false):
		if body is CharacterBody3D: excluded.append(body.get_rid())
	var heights := PackedFloat32Array()
	var distances := PackedFloat32Array()
	heights.resize(SIZE * SIZE)
	distances.resize(SIZE * SIZE)
	var space := main.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.new()
	query.exclude = excluded
	query.hit_from_inside = true
	var solid_samples := 0
	for z in SIZE:
		for x in SIZE:
			var p := ORIGIN + (Vector2(x, z) + Vector2.ONE * .5) / SIZE * EXTENT
			query.from = Vector3(p.x, -3.3, p.y)
			query.to = Vector3(p.x, -20.0, p.y)
			var hit := space.intersect_ray(query)
			var height: float = -15.0 if hit.is_empty() else hit.position.y
			var index := z * SIZE + x
			heights[index] = height
			distances[index] = 0.0 if height > -5.02 else 32.0
			if height > -5.02: solid_samples += 1
	# Eight-neighbor chamfer distance in metres, capped outside the foam zone.
	var step := EXTENT.x / SIZE
	var diagonal := step * sqrt(2.0)
	for z in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			var i := z * SIZE + x
			distances[i] = minf(distances[i], minf(distances[i-1] + step, minf(distances[i-SIZE] + step,
				minf(distances[i-SIZE-1] + diagonal, distances[i-SIZE+1] + diagonal))))
	for z in range(SIZE - 2, 0, -1):
		for x in range(SIZE - 2, 0, -1):
			var i := z * SIZE + x
			distances[i] = minf(distances[i], minf(distances[i+1] + step, minf(distances[i+SIZE] + step,
				minf(distances[i+SIZE-1] + diagonal, distances[i+SIZE+1] + diagonal))))
	var pixels := PackedFloat32Array()
	pixels.resize(SIZE * SIZE * 2)
	for i in SIZE * SIZE:
		pixels[i*2] = heights[i]
		pixels[i*2+1] = distances[i]
	var field := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGF, pixels.to_byte_array())
	assert(field.save_exr(OUTPUT, false) == OK)
	print("OCEAN_CONTACT_FIELD_BAKED ", {"samples": SIZE * SIZE, "solid_samples": solid_samples, "metres_per_texel": step})
	quit()
