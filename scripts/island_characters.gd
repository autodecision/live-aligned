class_name IslandCharacters
extends Node3D

var envoy: PS3CharacterNPC
var scientist: PS3CharacterNPC
var robot: PS3CharacterNPC

func _ready() -> void:
	_spawn_characters()
	print("ISLAND_CHARACTERS 3 characters: island sightseeing, water survey, island infrastructure inspection")

func _point(position: Vector3) -> Dictionary:
	return {"position": position}

func _task(position: Vector3, activity: String, duration: float, interest: Vector3) -> Dictionary:
	return {"position": position, "activity": activity, "duration": duration, "look_at": interest}

func _make_character(node_name: String, display_name: String, asset: String, speed: float) -> PS3CharacterNPC:
	var npc := PS3CharacterNPC.new()
	npc.name = node_name
	npc.character_name = display_name
	npc.character_id = asset
	npc.model_path = "res://assets/characters/" + asset + ".glb"
	npc.walk_speed = speed
	return npc

func _spawn_characters() -> void:
	var bridge_plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
	var garden_plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/south_garden.json"))
	var pagoda_plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/north_pagoda.json"))
	# The Envoy tours the connected islands, studying the pagoda and koi pond.
	# Every crossing follows a deck; its shore walks follow the paved plans.
	envoy = _make_character("Envoy", "The Envoy", "alien_suit", 1.35)
	envoy.turn_speed = 2.1
	var main_north_crossing := _bridge_route(bridge_plan, "Main_North")
	var main_sidewalk := _plan_path(pagoda_plan.sidewalk_routes[0].path)
	var north_branch := _plan_path(pagoda_plan.sidewalk_routes[1].path)
	var entry_path := _pagoda_entry_path(pagoda_plan)
	var north_crossing := _bridge_route(bridge_plan, "North_South")
	var north_arrival := _plan_path(garden_plan.routes[1])
	var south_crossing := _bridge_route(bridge_plan, "Main_South")
	var south_arrival := _plan_path(garden_plan.routes[0])
	var envoy_route: Array[Dictionary] = main_north_crossing.duplicate(true)
	envoy_route[0] = _task(envoy_route[0].position, "observe", 5.0, Vector3(0, 5, -5))
	envoy_route.append_array(main_sidewalk)
	envoy_route[-1] = _task(main_sidewalk[-1].position, "observe", 7.0, Vector3(92, 8, -64))
	envoy_route.append_array(_reversed(entry_path))
	envoy_route.append_array(_reversed(north_branch))
	envoy_route.append_array(north_crossing)
	envoy_route.append_array(north_arrival)
	# The west gravel lane leads onto the existing viewing deck, clear of reeds.
	envoy_route.append_array([
		_point(Vector3(89, 4.74, 28.5)),
		_point(Vector3(88, 4.735, 34)),
		_task(Vector3(90.8, 4.73, 33.7), "observe", 9.0, Vector3(96, 4.0, 34)),
		_point(Vector3(88, 4.735, 34)),
		_point(Vector3(89, 4.74, 28.5)),
	])
	envoy_route.append_array(_reversed(north_arrival))
	envoy_route.append_array(_reversed(north_crossing))
	envoy_route.append_array(north_branch)
	# Return from the junction along only the mainland half of the sidewalk.
	var junction_index: int = main_sidewalk.size() - entry_path.size()
	envoy_route.append_array(_reversed(main_sidewalk.slice(0, junction_index + 1)))
	envoy_route.append_array(_reversed(main_north_crossing))
	envoy.set_route(envoy_route)
	add_child(envoy)

	# Dr. Vale surveys the pool, checks readings, then goes up to inspect the temple.
	# The central stair lane is continuous; lateral movement happens on landings.
	scientist = _make_character("Scientist", "Dr. Vale", "female_scientist", 1.55)
	scientist.set_route([
		_task(Vector3(-1.5, 0.06, 10.5), "record", 5.5, Vector3(2.5, 0.3, 10)),
		_point(Vector3(-3.5, 0.06, 10.5)),
		_point(Vector3(-3.5, 1.1, 7.5)),
		_point(Vector3(-3.5, 3.5, 3.5)),
		_point(Vector3(-3.5, 4.53, -1.0)),
		_task(Vector3(-1.5, 4.53, -1.0), "observe", 4.0, Vector3(1, 5, -4)),
		_point(Vector3(-3.5, 4.53, -1.0)),
		_point(Vector3(-3.5, 3.5, 3.5)),
		_point(Vector3(-3.5, 1.1, 7.5)),
		_point(Vector3(-3.5, 0.06, 10.5)),
		_task(Vector3(-5.8, 0.06, 10.5), "record", 4.0, Vector3(-5.8, 3, 3)),
	])
	add_child(scientist)

	# Kestrel follows the actual deck, garden paving and pagoda sidewalk plans.
	# Its rounds inspect both southern bridges, the sand garden and pagoda entry.
	robot = _make_character("Robot", "Kestrel-09", "robot", 1.45)
	robot.turn_speed = 1.9
	var patrol: Array[Dictionary] = south_crossing.duplicate(true)
	patrol[0] = _task(patrol[0].position, "inspect", 4.0, patrol[0].position + Vector3(0, 0, -3))
	var middle: int = patrol.size() / 2
	patrol[middle] = _task(patrol[middle].position, "inspect", 4.0, patrol[middle].position + Vector3(0, 0, -3))
	patrol.append_array(south_arrival)
	patrol.append(_point(Vector3(89, 4.74, 28.5)))
	var garden_loop := _plan_path(garden_plan.routes[2])
	# Inspect the sand bed from the gravel, leaving its raked surface untouched.
	garden_loop[3] = _task(garden_loop[3].position, "inspect", 7.0, Vector3(111.5, 4.8, 34))
	patrol.append_array(garden_loop)
	patrol.append(_point(Vector3(91.6, 4.735, 27.8)))
	patrol.append_array(_reversed(north_arrival))
	patrol.append_array(_reversed(north_crossing))
	patrol.append_array(north_branch)
	# Join the Main_North sidewalk at the branch junction, following every bend.
	patrol.append_array(entry_path)
	var entry: Vector3 = entry_path[-1].position
	patrol[-1] = _task(entry, "inspect", 7.0, Vector3(92, 8.0, -64))
	patrol.append_array(_reversed(entry_path))
	patrol.append_array(_reversed(north_branch))
	patrol.append_array(north_crossing)
	patrol.append_array(north_arrival)
	patrol.append(_point(Vector3(91, 4.735, 28.5)))
	patrol.append_array(_reversed(south_arrival))
	patrol.append_array(_reversed(south_crossing))
	robot.set_route(patrol)
	add_child(robot)

func _plan_path(points: Array) -> Array[Dictionary]:
	var route_points: Array[Dictionary] = []
	for p: Array in points:
		route_points.append(_point(Vector3(p[0], p[1], p[2])))
	return route_points

func _reversed(points: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = points.duplicate(true)
	result.reverse()
	return result

func _bridge_route(plan: Dictionary, bridge_name: String) -> Array[Dictionary]:
	for bridge: Dictionary in plan.bridges:
		if bridge.name != bridge_name:
			continue
		var points: Array[Dictionary] = []
		for i in range(0, bridge.sections.size(), 4):
			var p: Array = bridge.sections[i].position
			points.append(_point(Vector3(p[0], p[1] + 0.04, p[2])))
		var end: Array = bridge.sections[-1].position
		var end_point := Vector3(end[0], end[1] + 0.04, end[2])
		if not points[-1].position.is_equal_approx(end_point):
			points.append(_point(end_point))
		return points
	return []

func _pagoda_entry_path(plan: Dictionary) -> Array[Dictionary]:
	var branch_end: Array = plan.sidewalk_routes[1].path[-1]
	var junction := Vector3(branch_end[0], branch_end[1], branch_end[2])
	var path: Array = plan.sidewalk_routes[0].path
	var nearest := 0
	var distance := INF
	for i in path.size():
		var p: Array = path[i]
		var separation := junction.distance_to(Vector3(p[0], p[1], p[2]))
		if separation < distance:
			distance = separation
			nearest = i
	return _plan_path(path.slice(nearest))

func get_envoy() -> PS3CharacterNPC:
	return envoy

func get_scientist() -> PS3CharacterNPC:
	return scientist

func get_robot() -> PS3CharacterNPC:
	return robot

func get_character_by_id(character_id: String) -> PS3CharacterNPC:
	for child in get_children():
		if child is PS3CharacterNPC and child.character_id == character_id:
			return child
	return null
