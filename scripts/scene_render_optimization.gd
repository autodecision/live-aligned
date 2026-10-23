extends Node3D

# Preserve the imported render meshes. Foliage uses alpha cutouts,
# allowing depth rejection instead of sorting/blending every overlapping leaf.
var foliage_material_count := 0
var tree_count := 0
var trees: Array[MeshInstance3D] = []
var lod_timer := 0.0
var performance_mode := false
var hud_label: Label
const SETTINGS_FILE := "user://graphics.cfg"

func _ready() -> void:
	get_viewport().use_occlusion_culling = true
	var optimized_materials := {}
	# Identical packed attributes, triangles and LODs; unused imported vertices
	# are removed from these shared buffers. Leaf visibility is unchanged.
	var tree_mesh: ArrayMesh = load("res://assets/olive_tree_render_lod_compact.res")
	var shadow_mesh: ArrayMesh = load("res://assets/olive_tree_shadow_lod_compact.res")
	var bust_collision: ConvexPolygonShape3D = load("res://assets/bust_collision_proxy.tres")
	for mesh in get_parent().get_node("TempleMap").find_children("*", "MeshInstance3D", true, false):
		# The sculpture's concave render-mesh collider makes contact/step
		# recovery extremely expensive. Keep the detailed visible mesh and
		# use a compact solid hull for player contact.
		if String(mesh.name)=="Altar_Marble_Bust":
			for collider in mesh.find_children("*","CollisionShape3D",true,false):
				collider.shape = bust_collision
		var is_tree: bool = "Olive" in mesh.name or "Tree" in mesh.name or "tree" in mesh.name
		if is_tree:
			mesh.mesh = tree_mesh
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mesh.lod_bias = 0.6
			trees.append(mesh)
			tree_count += 1
		for i in mesh.mesh.get_surface_count():
			var material = mesh.mesh.surface_get_material(i)
			if not material is StandardMaterial3D: continue
			if material.resource_name not in ["island_tree_01_leaves","fern_02"]: continue
			var id: String = material.resource_name
			if not optimized_materials.has(id):
				var cutout: StandardMaterial3D = material.duplicate()
				cutout.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				cutout.alpha_scissor_threshold = .3
				cutout.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
				optimized_materials[id] = cutout
				foliage_material_count += 1
			mesh.set_surface_override_material(i,optimized_materials[id])
	for tree in trees:
		var shadow := MeshInstance3D.new()
		shadow.name = "Olive_Shadow_Proxy"
		shadow.mesh = shadow_mesh
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		tree.add_child(shadow)
		for i in shadow_mesh.get_surface_count():
			var material = tree.get_surface_override_material(i)
			if material: shadow.set_surface_override_material(i,material)
	var sun: DirectionalLight3D = get_parent().get_node("MediterraneanSun")
	sun.directional_shadow_max_distance = 40.0
	sun.directional_shadow_fade_start = .8
	hud_label = Label.new()
	hud_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	hud_label.position = Vector2(-310,20)
	hud_label.size = Vector2(290,30)
	hud_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud_label.add_theme_color_override("font_shadow_color",Color(0,0,0,.8))
	hud_label.add_theme_constant_override("shadow_offset_x",1)
	hud_label.add_theme_constant_override("shadow_offset_y",1)
	get_parent().get_node("Player/CanvasLayer/HUD").add_child(hud_label)
	var config := ConfigFile.new()
	if config.load(SETTINGS_FILE)==OK:
		performance_mode = config.get_value("graphics","performance_mode",false)
	set_performance_mode(performance_mode,false)
	print("RENDER_OPTIMIZATION ",tree_count," trees, ",foliage_material_count," shared cutout materials")

# The canopy mesh has no distance LODs, so leaf clusters never pop into view.
# Wood retains native LODs at a stable bias. Update only the FPS label here.
func _process(delta: float) -> void:
	lod_timer += delta
	if lod_timer < .25: return
	lod_timer = 0.0
	hud_label.text = "%s · %d FPS  |  F6" % ["Performance" if performance_mode else "Balanced",Engine.get_frames_per_second()]

func set_performance_mode(enabled: bool, persist: bool = false) -> void:
	performance_mode = enabled
	var viewport := get_viewport()
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	viewport.scaling_3d_scale = .75 if enabled else 1.0
	# Thin grass needs coverage samples: FXAA alone leaves crawling edges.
	viewport.msaa_3d = Viewport.MSAA_2X if enabled else Viewport.MSAA_4X
	var sun:DirectionalLight3D=get_parent().get_node("MediterraneanSun")
	sun.directional_shadow_max_distance = 28.0 if enabled else 40.0
	# Keep the first cascade across the near walkway, avoiding the old 4m blur band.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_split_1 = .38
	sun.directional_shadow_split_2 = .45
	sun.directional_shadow_split_3 = .75
	sun.directional_shadow_blend_splits = true
	sun.shadow_blur = .7
	viewport.anisotropic_filtering_level = 2
	for patch in get_parent().get_node("IslandGroundCover").get_children():
		if patch is MultiMeshInstance3D:
			patch.visibility_range_end = (45.0 if "ShortSward" in patch.name else 60.0) if enabled else 85.0
	lod_timer = .25
	if persist:
		var config := ConfigFile.new()
		config.set_value("graphics","performance_mode",enabled)
		config.save(SETTINGS_FILE)

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode==KEY_F6 or event.keycode==KEY_F6):
		set_performance_mode(not performance_mode,true)
		get_viewport().set_input_as_handled()
