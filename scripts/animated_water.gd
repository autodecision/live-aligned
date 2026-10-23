extends Node3D

# Blender procedural drivers do not survive GLB export; animate the imported
# connected meshes directly in Godot, including their moving surface normals.
var materials: Array[ShaderMaterial] = []
var water_mesh_names: Array[String] = []
var elapsed := 0.0

func _ready() -> void:
	var shader = load("res://shaders/flowing_water.gdshader")
	for mesh in get_parent().get_node("TempleMap").find_children("*", "MeshInstance3D", true, false):
		for i in mesh.mesh.get_surface_count():
			var original = mesh.mesh.surface_get_material(i)
			if original == null or not original.resource_name.begins_with("Water"): continue
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/outfall_volume.gdshader") if mesh.name in ["Sea_Connected_Fall", "Bowl_Overflow_Surface", "Bowl_Overflow_Stream"] else shader
			var kind := 1
			if "moving swells" in original.resource_name: kind = 0
			elif "falling ribbons" in original.resource_name: kind = 2
			# One shader and world-space clock for the playable ocean and horizon.
			if kind == 0:
				material.shader = preload("res://shaders/ocean_horizon.gdshader")
				material.set_shader_parameter("contact_field", load("res://assets/ocean_contact_field.exr"))
				mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if mesh.name in ["Bowl_Overflow_Surface", "Bowl_Overflow_Stream"]:
				material.set_shader_parameter("fold_amplitude", .12)
			material.set_shader_parameter("water_kind",kind)
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			material.set_shader_parameter("bounds_min",box.position)
			material.set_shader_parameter("bounds_max",box.end)
			var current := Vector2(.13,.24)
			if kind == 0: current = Vector2(.4,-.18)
			elif "outfall" in original.resource_name: current = Vector2(.9,0)
			elif "rill" in original.resource_name: current = Vector2(0,.6)
			material.set_shader_parameter("current",current)
			mesh.set_surface_override_material(i,material)
			mesh.extra_cull_margin = .6 if kind == 0 else .4
			materials.append(material)
			water_mesh_names.append(String(mesh.name))
	assert(materials.size()==13,"Expected all 13 water surfaces")
	# One level pool and outlet share a ripple field and edge bounds. Separate
	# currents/edge fades used to expose the join despite coincident geometry.
	var connected := ["Lower_Pool_Water_Fitted", "Outfall_Contained_Water"]
	var joined_bounds := AABB()
	for i in connected.size():
		var mesh: MeshInstance3D = get_parent().get_node("TempleMap/" + connected[i])
		var bounds: AABB = mesh.global_transform * mesh.get_aabb()
		joined_bounds = bounds if i == 0 else joined_bounds.merge(bounds)
	for name: String in connected:
		var material: ShaderMaterial = materials[water_mesh_names.find(name)]
		material.set_shader_parameter("bounds_min", joined_bounds.position)
		material.set_shader_parameter("bounds_max", joined_bounds.end)
		material.set_shader_parameter("current", Vector2(.42, 0.0))
	_add_outfall_spray()
	print("ANIMATED_WATER ",water_mesh_names)

func set_water_time(value: float) -> void:
	elapsed = value
	for material in materials: material.set_shader_parameter("water_time",elapsed)

func _process(delta: float) -> void:
	set_water_time(elapsed+delta)

func _add_outfall_spray() -> void:
	var spray:=GPUParticles3D.new()
	spray.name="OutfallImpactSpray"
	spray.position=Vector3(12.4,-4.84,7.45)
	spray.amount=40
	spray.lifetime=.85
	spray.preprocess=.85
	spray.visibility_aabb=AABB(Vector3(-1,-2,-1),Vector3(2,4,2))
	spray.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var motion:=ParticleProcessMaterial.new()
	motion.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX
	motion.emission_box_extents=Vector3(.26,.015,.40)
	motion.direction=Vector3(0,1,0)
	motion.spread=46.0
	motion.initial_velocity_min=.8
	motion.initial_velocity_max=1.6
	motion.gravity=Vector3(0,-4,0)
	motion.scale_min=.012
	motion.scale_max=.032
	var bead:=SphereMesh.new()
	bead.radius=1.0
	bead.height=2.0
	bead.radial_segments=6
	bead.rings=3
	var material:=StandardMaterial3D.new()
	material.albedo_color=Color(.56,.78,.78)
	material.roughness=.28
	bead.material=material
	spray.draw_pass_1=bead
	spray.process_material=motion
	add_child(spray)
