extends Node3D

# Small spatial batches let the renderer cull remote parts of the meadow.
const PATCH_SIZE := 12.0
var instance_total := 0
var patch_total := 0

func _ready() -> void:
	var source: Node = load("res://assets/gscatter_ground_cover.glb").instantiate()
	var meshes := {}
	for child in source.find_children("*", "MeshInstance3D", true, false):
		meshes[String(child.name)] = child.mesh
		for surface in child.mesh.get_surface_count():
			var material = child.mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if "ShortSward" in String(child.name) else BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				material.alpha_scissor_threshold = 0.35
				# Smooth the cutout edges of meadow cards across MSAA samples.
				# This uses coverage, without temporal noise or blended sorting.
				material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF if "ShortSward" in String(child.name) else BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
				if "ShortSward" in String(child.name):
					material.vertex_color_use_as_albedo = true
					material.vertex_color_is_srgb = false
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://assets/gscatter_ground_cover_instances.json"))
	if FileAccess.file_exists("res://assets/north_pagoda_cover.json"):
		rows.append_array(JSON.parse_string(FileAccess.get_file_as_string("res://assets/north_pagoda_cover.json")))
	var groups := {}
	for row in rows:
		var p: Array = row.origin
		var key := "%s_%d_%d" % [row.asset, floori(p[0]/PATCH_SIZE), floori(p[2]/PATCH_SIZE)]
		if not groups.has(key): groups[key] = []
		groups[key].append(row)
	for key in groups:
		var batch: Array = groups[key]
		var first: Dictionary = batch[0]
		assert(meshes.has(first.asset), "Missing meadow mesh: " + first.asset)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[first.asset]
		mm.instance_count = batch.size()
		var center := Vector3(floorf(first.origin[0]/PATCH_SIZE)*PATCH_SIZE, 0, floorf(first.origin[2]/PATCH_SIZE)*PATCH_SIZE)
		for i in batch.size():
			var row: Dictionary = batch[i]
			var b: Array = row.basis
			var basis := Basis(Vector3(b[0][0],b[0][1],b[0][2]),Vector3(b[1][0],b[1][1],b[1][2]),Vector3(b[2][0],b[2][1],b[2][2]))
			var p: Array = row.origin
			mm.set_instance_transform(i,Transform3D(basis,Vector3(p[0],p[1],p[2])-center))
		var patch := MultiMeshInstance3D.new()
		patch.name = key
		patch.multimesh = mm
		patch.position = center
		patch.visibility_range_end = 85.0
		patch.visibility_range_end_margin = 8.0
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(patch)
		instance_total += batch.size()
		patch_total += 1
	source.free()
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/island_ground.gdshader")
	material.set_shader_parameter("meadow_texture",load("res://assets/textures/rocky_terrain_02_Diffuse_2k.jpg"))
	for mesh in get_parent().find_children("*", "MeshInstance3D", true, false):
		if String(mesh.name).begins_with("Cliff_Terrain") or String(mesh.name).begins_with("Distant_Islands"):
			mesh.material_override = material
	print("GSCATTER_GROUND_COVER ", instance_total, " plants in ", patch_total, " spatial batches")
