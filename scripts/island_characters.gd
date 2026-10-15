class_name IslandCharacters
extends Node3D

var envoy: PS3CharacterNPC
var scientist: PS3CharacterNPC
var robot: PS3CharacterNPC

func _ready() -> void:
	_spawn_characters()
	print("ISLAND_CHARACTERS 3 characters: temple rounds, water survey, bridge inspection")

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
	# The Envoy makes measured rounds, stopping to study the shrine and the sea.
	envoy = _make_character("Envoy", "The Envoy", "alien_suit", 1.35)
	envoy.turn_speed = 2.1
	envoy.set_route([
		_task(Vector3(-3.5, 4.53, 0.0), "observe", 5.0, Vector3(-3.5, 2, 12)),
		_point(Vector3(-3.5, 4.53, -4.0)),
		_task(Vector3(-3.5, 4.53, -8.0), "observe", 6.0, Vector3(0, 6, -10)),
		_point(Vector3(-3.5, 4.53, -3.0)),
		_point(Vector3(-3.5, 4.53, -0.5)),
		_point(Vector3(-7.0, 4.53, -0.5)),
		_task(Vector3(-7.0, 4.53, -10.0), "observe", 4.5, Vector3(-20, 4, -10)),
		_point(Vector3(-7.0, 4.53, -0.5)),
		_point(Vector3(-3.5, 4.53, -0.5)),
	])
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

	# Kestrel checks the actual bridge deck from end to end. Use its scoped plan
	# so subsequent bridge grading doesn't leave the patrol walking into a cliff.
	robot = _make_character("Robot", "Kestrel-09", "robot", 1.45)
	robot.turn_speed = 1.9
	var patrol: Array[Dictionary] = []
	var plan: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
	for bridge in plan.bridges:
		if bridge.name != "Main_South":
			continue
		var sections: Array = bridge.sections
		var indices: Array[int] = []
		for i in range(0, sections.size(), 8):
			indices.append(i)
		if indices[-1] != sections.size() - 1:
			indices.append(sections.size() - 1)
		for i in indices:
			var p: Array = sections[i].position
			var position := Vector3(p[0], p[1] + 0.04, p[2])
			if i == 0 or i == indices[-1] or i == indices[indices.size() / 2]:
				patrol.append(_task(position, "inspect", 4.0, position + Vector3(0, 0, -3)))
			else:
				patrol.append(_point(position))
		for j in range(indices.size() - 2, 0, -1):
			var p: Array = sections[indices[j]].position
			patrol.append(_point(Vector3(p[0], p[1] + 0.04, p[2])))
	robot.set_route(patrol)
	add_child(robot)

func get_envoy() -> PS3CharacterNPC:
	return envoy

func get_scientist() -> PS3CharacterNPC:
	return scientist

func get_robot() -> PS3CharacterNPC:
	return robot
