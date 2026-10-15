extends Node3D

# Small spatial batches let the renderer cull remote parts of the meadow.
const PATCH_SIZE := 12.0
const GRASS_LIBRARY := preload("res://assets/original_grass.glb")
var instance_total := 0
var patch_total := 0

# Keep historical placement keys and patch names for saved plans and F6 culling.
static func grass_asset_name(placement_key: String) -> String:
	if "ShortSward" in placement_key: return "LA_Grass_ShortSward"
	if "BromusSterilis" in placement_key: return "LA_Grass_DrySeedHead"
	if "LoliumPerenne" in placement_key or "TrisetumFlavescens" in placement_key: return "LA_Grass_MeadowTuft"
	assert(false, "Unknown meadow placement key: " + placement_key)
	return ""

static func grass_asset_scale(placement_key: String) -> float:
	return 0.40 if "LoliumPerenne" in placement_key else 1.0

func _ready() -> void:
	var source: Node = GRASS_LIBRARY.instantiate()
	var meshes := {}
	for child in source.find_children("*", "MeshInstance3D", true, false):
		meshes[String(child.name)] = child.mesh
		for surface in child.mesh.get_surface_count():
			var material = child.mesh.surface_get_material(surface)
			if material is StandardMaterial3D:
				# Solid blade/seed silhouettes use the existing 2x/4x MSAA.
				# No cutout textures, dithering, or transparent-card sorting.
				material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
				material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_OFF
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
		var asset_name := grass_asset_name(first.asset)
		assert(meshes.has(asset_name), "Missing original meadow mesh: " + asset_name)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = meshes[asset_name]
		mm.instance_count = batch.size()
		var center := Vector3(floorf(first.origin[0]/PATCH_SIZE)*PATCH_SIZE, 0, floorf(first.origin[2]/PATCH_SIZE)*PATCH_SIZE)
		for i in batch.size():
			var row: Dictionary = batch[i]
			var b: Array = row.basis
			var basis := Basis(Vector3(b[0][0],b[0][1],b[0][2]),Vector3(b[1][0],b[1][1],b[1][2]),Vector3(b[2][0],b[2][1],b[2][2]))
			basis = basis.scaled(Vector3.ONE * grass_asset_scale(row.asset))
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
	print("ORIGINAL_GROUND_COVER ", instance_total, " plants in ", patch_total, " spatial batches; 3 original meshes")
