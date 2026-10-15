extends SceneTree

const OUT := "/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/original_grass_checks/"
const GrassCover = preload("res://scripts/island_ground_cover.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440, 900)
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.get_node("CanvasLayer").hide()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# Preview selection and graphics changes are explicitly non-persistent.
	var lab = main.get_node("VisualLab")
	lab.select_preset(0)
	lab._launcher.hide()
	var cover = main.get_node("IslandGroundCover")
	var meshes := {}
	var material_ids := {}
	var count := 0
	for patch in cover.get_children():
		assert(patch is MultiMeshInstance3D)
		assert(patch.get_child_count() == 0, "Grass must have no collision bodies")
		var mesh: Mesh = patch.multimesh.mesh
		meshes[mesh.get_instance_id()] = true
		assert(mesh.get_surface_count() == 1)
		var arrays := mesh.surface_get_arrays(0)
		assert(arrays[Mesh.ARRAY_COLOR].size() == arrays[Mesh.ARRAY_VERTEX].size())
		var mat: StandardMaterial3D = mesh.surface_get_material(0)
		material_ids[mat.get_instance_id()] = true
		assert(mat.albedo_texture == null and mat.normal_texture == null)
		assert(mat.vertex_color_use_as_albedo and not mat.vertex_color_is_srgb)
		assert(mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED)
		count += patch.multimesh.instance_count
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/gscatter_ground_cover_instances.json"))
	rows.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/north_pagoda_cover.json")))
	assert(count == rows.size() and count == cover.instance_total)
	assert(meshes.size() == 3 and material_ids.size() == 1)
	# Check every saved transform, including the compact tuft substitution.
	var slots := {}
	# The headless dummy renderer does not retain MultiMesh transform buffers.
	var transform_rows: Array = rows if DisplayServer.get_name() != "headless" else []
	for row in transform_rows:
		var key := "%s_%d_%d" % [row.asset, floori(row.origin[0]/cover.PATCH_SIZE), floori(row.origin[2]/cover.PATCH_SIZE)]
		var patch: MultiMeshInstance3D = cover.get_node(NodePath(key))
		var index: int = slots.get(key, 0)
		slots[key] = index+1
		var transform := patch.multimesh.get_instance_transform(index)
		var actual := patch.transform * transform
		assert(actual.origin.distance_to(Vector3(row.origin[0], row.origin[1], row.origin[2])) < .0001)
		var b: Array = row.basis
		var expected := Basis(Vector3(b[0][0], b[0][1], b[0][2]), Vector3(b[1][0], b[1][1], b[1][2]), Vector3(b[2][0], b[2][1], b[2][2]))
		expected = expected.scaled(Vector3.ONE * GrassCover.grass_asset_scale(row.asset))
		assert(actual.basis.is_equal_approx(expected))
	var optimization = main.get_node("RenderOptimization")
	optimization.set_performance_mode(true, false)
	assert(root.msaa_3d == Viewport.MSAA_2X)
	optimization.set_performance_mode(false, false)
	assert(root.msaa_3d == Viewport.MSAA_4X)
	assert(optimization.tree_count == 91)
	assert(main.get_node("AnimatedWater").materials.size() == 13)
	var report := {"instances": count, "shared_meshes": meshes.size(), "shared_materials": material_ids.size(),
		"textures": 0, "saved_transforms_verified": transform_rows.size(), "both_msaa_modes_preserved": true,
		"tree_count": 91, "water_surfaces": 13}
	FileAccess.open(OUT+"validation.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("ORIGINAL_GRASS_CHECK_PASS ", JSON.stringify(report))
	if DisplayServer.get_name() != "headless":
		root.always_on_top = true
		root.grab_focus()
		var clock = main.get_node("DayNightCycle")
		clock.running = false
		var camera := Camera3D.new()
		main.add_child(camera)
		camera.current = true
		camera.fov = 65
		await physics_frame
		var excluded: Array[RID] = [player.get_rid()]
		for body in main.find_children("*", "StaticBody3D", true, false):
			if "Cliff_Terrain" not in String(body.get_path()): excluded.append(body.get_rid())
		var close_points := []
		for point in [Vector3(-13, 0, 10), Vector3(-16, 0, 6)]:
			var query := PhysicsRayQueryParameters3D.create(point+Vector3.UP*40, point-Vector3.UP*10)
			query.exclude = excluded
			var hit: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(query)
			assert(not hit.is_empty())
			close_points.append(hit.position)
		var views := [
			["main_meadow", Vector3(-12, 4, 12), Vector3(-18, 2, 3), .25],
			["grass_close", close_points[0]+Vector3.UP*.8, close_points[1]+Vector3.UP*.12, .25],
			["north_meadow", Vector3(55, 20, -26), Vector3(64, 6, -46), .25],
			["pagoda_path", Vector3(59.1, 6.87, -40.5), Vector3(69, 5.5, -41), .25],
			["coast_sunset", Vector3(-12, 4, 12), Vector3(-18, 2, 3), .47]
		]
		for view in views:
			camera.position = view[1]
			camera.look_at(view[2])
			clock.set_phase(view[3])
			for i in range(50): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+view[0]+".png")
			print("ORIGINAL_GRASS_CAPTURE ", view[0])
	quit()
