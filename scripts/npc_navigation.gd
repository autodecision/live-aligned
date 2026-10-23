class_name NPCNavigation
extends Node
## Runtime walkable-surface navigation for character approaches. Bakes once from
## the composed map's static colliders (collision layer 1) on a worker thread,
## then removes sea-floor, pond/pool and raked-sand polygons so characters never
## path through water or across the zen garden. Uses its own navigation map so it
## cannot interfere with any other navigation user.

signal ready_changed(is_ready: bool)

const SEA_SURFACE_Y := -5.0
const AGENT_RADIUS := 0.25
const AGENT_HEIGHT := 1.9
const AGENT_MAX_CLIMB := 0.5
const AGENT_MAX_SLOPE := 55.0
const CELL_SIZE := 0.25
const CELL_HEIGHT := 0.1
## Extra flat no-walk areas (node path under the world root, vertical tolerance).
const AVOID_SURFACES := [
	["SouthGarden/Garden/SouthGarden_Pond_Water", 3.0],
	["SouthGarden/Garden/SouthGarden_Zen_Sand", 0.5],
]

@export var bake_delay_frames := 6
var world: Node
var navigation_mesh: NavigationMesh
var removed_polygons := 0
var bake_msec := 0
var _map := RID()
var _region := RID()
var _ready_state := false
var _baking := false
var _bake_started := 0


func _ready() -> void:
	if world == null:
		world = get_tree().current_scene if get_tree().current_scene else get_parent().get_parent()
	_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_map, CELL_SIZE)
	NavigationServer3D.map_set_cell_height(_map, CELL_HEIGHT)
	NavigationServer3D.map_set_use_edge_connections(_map, false)
	NavigationServer3D.map_set_active(_map, true)
	_region = NavigationServer3D.region_create()
	NavigationServer3D.region_set_map(_region, _map)
	# Runtime repairs replace terrain colliders during their own _ready calls.
	for i in bake_delay_frames:
		await get_tree().physics_frame
	bake()


func _exit_tree() -> void:
	if _region.is_valid():
		NavigationServer3D.free_rid(_region)
	if _map.is_valid():
		NavigationServer3D.free_rid(_map)


func is_ready() -> bool:
	return _ready_state and NavigationServer3D.map_get_iteration_id(_map) > 0


func bake() -> void:
	if _baking or not is_instance_valid(world):
		return
	_baking = true
	_ready_state = false
	var mesh := NavigationMesh.new()
	mesh.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	mesh.geometry_collision_mask = 1
	mesh.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_ROOT_NODE_CHILDREN
	mesh.cell_size = CELL_SIZE
	mesh.cell_height = CELL_HEIGHT
	mesh.agent_radius = AGENT_RADIUS
	mesh.agent_height = AGENT_HEIGHT
	mesh.agent_max_climb = AGENT_MAX_CLIMB
	mesh.agent_max_slope = AGENT_MAX_SLOPE
	mesh.region_min_size = 4.0
	var source := NavigationMeshSourceGeometryData3D.new()
	# Parsing reads the scene tree and must stay on the main thread; it is fast.
	NavigationServer3D.parse_source_geometry_data(mesh, source, world)
	_bake_started = Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data_async(mesh, source, _on_baked.bind(mesh))


func _on_baked(mesh: NavigationMesh) -> void:
	if not is_inside_tree():
		return
	bake_msec = Time.get_ticks_msec() - _bake_started
	navigation_mesh = _without_unwalkable(mesh)
	NavigationServer3D.region_set_navigation_mesh(_region, navigation_mesh)
	_baking = false
	# The server applies the region on its next synchronization.
	for i in 3:
		await get_tree().physics_frame
	_ready_state = navigation_mesh.get_polygon_count() > 0
	print("NPC_NAVIGATION polygons=%d removed=%d bake_ms=%d" % [navigation_mesh.get_polygon_count(), removed_polygons, bake_msec])
	ready_changed.emit(_ready_state)


func _water_volumes() -> Array[Dictionary]:
	var volumes: Array[Dictionary] = []
	var water := world.get_node_or_null("AnimatedWater")
	var temple := world.get_node_or_null("TempleMap")
	if water and temple and "water_mesh_names" in water:
		for mesh_name in water.water_mesh_names:
			var mesh := temple.find_child(mesh_name, true, false) as MeshInstance3D
			if mesh == null or mesh.mesh == null:
				continue
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			# The ocean and vertical falls are handled by the sea-surface test.
			if bounds.size.x > 120.0 or bounds.size.z > 120.0 or bounds.size.y > 1.5:
				continue
			volumes.append({"bounds": bounds, "depth": 3.0})
	for row in AVOID_SURFACES:
		var surface := world.get_node_or_null(row[0]) as MeshInstance3D
		if surface and surface.mesh:
			volumes.append({"bounds": surface.global_transform * surface.get_aabb(), "depth": float(row[1])})
	return volumes


func _without_unwalkable(mesh: NavigationMesh) -> NavigationMesh:
	var volumes := _water_volumes()
	var vertices := mesh.vertices
	var kept: Array[PackedInt32Array] = []
	removed_polygons = 0
	for index in mesh.get_polygon_count():
		var polygon := mesh.get_polygon(index)
		var center := Vector3.ZERO
		var lowest := INF
		for vertex in polygon:
			center += vertices[vertex]
			lowest = minf(lowest, vertices[vertex].y)
		center /= maxf(1.0, polygon.size())
		var blocked := lowest < SEA_SURFACE_Y + 0.6
		for volume in volumes:
			if blocked:
				break
			var bounds: AABB = volume.bounds
			var inside := center.x > bounds.position.x - 0.2 and center.x < bounds.end.x + 0.2 and center.z > bounds.position.z - 0.2 and center.z < bounds.end.z + 0.2
			blocked = inside and center.y < bounds.end.y + 0.3 and center.y > bounds.position.y - float(volume.depth)
		if blocked:
			removed_polygons += 1
		else:
			kept.append(polygon)
	var filtered: NavigationMesh = mesh.duplicate()
	filtered.clear_polygons()
	filtered.vertices = vertices
	for polygon in kept:
		filtered.add_polygon(polygon)
	return filtered


func closest_point(point: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(_map, point) if is_ready() else point


## Returns an empty array until the bake is ready or when no path exists.
func find_path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if not is_ready():
		return PackedVector3Array()
	var start := NavigationServer3D.map_get_closest_point(_map, from)
	var end := NavigationServer3D.map_get_closest_point(_map, to)
	return NavigationServer3D.map_get_path(_map, start, end, true)


static func path_length(path: PackedVector3Array) -> float:
	var length := 0.0
	for i in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
	return length
