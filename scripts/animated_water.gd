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
			material.shader = shader
			var kind := 1
			if "moving swells" in original.resource_name: kind = 0
			elif "falling ribbons" in original.resource_name: kind = 2
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
			mesh.extra_cull_margin = .4
			materials.append(material)
			water_mesh_names.append(String(mesh.name))
	assert(materials.size()==13,"Expected all 13 water surfaces")
	print("ANIMATED_WATER ",water_mesh_names)

func set_water_time(value: float) -> void:
	elapsed = value
	for material in materials: material.set_shader_parameter("water_time",elapsed)

func _process(delta: float) -> void:
	set_water_time(elapsed+delta)
