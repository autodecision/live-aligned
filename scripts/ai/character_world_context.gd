extends RefCounted
## Public, transient world facts. Reads scene state only; never opens character memory.
const MAX_CONTEXT_CHARS := 6500
const MAX_CHARACTERS := 8
const ROSTER := {"alien_suit": "The Envoy", "female_scientist": "Dr. Vale", "robot": "Kestrel-09"}
const BRIDGE_NAMES := {"Main_North": "main-to-north island bridge", "Main_South": "main-to-south island bridge", "North_South": "north-to-south island bridge"}

func build_context(world: Node, speaker: Node3D, player: Node3D, characters: Node) -> String:
	var lines: Array[String] = [
		"CURRENT PUBLIC WORLD SNAPSHOT (transient; refreshed immediately before this request).",
		"Use this snapshot as authoritative for current locations over older dialogue or recalled claims. Positions may change after this instant; do not describe old sightings as current. All listed public character positions are available to you even out of sight. This does not give access to anyone else's thoughts, memories, plans, or private conversation.",
		"Directions use map north (-Z), east (+X), south (+Z), west (-X). Distances are approximate horizontal straight-line metres, not walking distances or safe routes; bridges and stairs are needed between islands/elevations. Do not invent current tasks or routes, and do not claim to move, summon, or control anyone.",
	]
	var landmarks := _landmarks(world)
	var origin_valid := _position_available(speaker)
	if origin_valid:
		lines.append("You (%s): %s." % [_name(speaker), describe_position(speaker.global_position, landmarks)])
	else:
		lines.append("Your current location is unavailable.")
	if _position_available(player):
		lines.append("Player: %s%s." % [describe_position(player.global_position, landmarks), _relative(player.global_position, speaker) if origin_valid else ""])
	else:
		lines.append("Player location is unavailable.")
	lines.append("Live character roster:")
	var found := {}
	var count := 0
	if is_instance_valid(characters):
		for child in characters.get_children():
			if not child is PS3CharacterNPC: continue
			if count >= MAX_CHARACTERS:
				lines.append("Additional characters omitted from this bounded snapshot; their positions are unavailable here.")
				break
			count += 1
			found[child.character_id] = true
			if not _position_available(child):
				lines.append("- %s: current location unavailable." % _name(child))
				continue
			var motion := "paused for conversation" if child._dialogue_paused else ("moving" if Vector2(child.velocity.x, child.velocity.z).length() > 0.12 else "currently stationary")
			lines.append("- %s: %s%s; %s." % [_name(child), describe_position(child.global_position, landmarks), _relative(child.global_position, speaker) if origin_valid and child != speaker else "", motion])
	for id in ROSTER:
		if not found.has(id): lines.append("- %s: absent from the live roster; current location unknown." % ROSTER[id])
	lines.append("Mapped landmarks currently present:")
	for landmark in landmarks:
		lines.append("- %s%s." % [landmark.label, _relative(landmark.center, speaker) if origin_valid else ""])
	if landmarks.is_empty(): lines.append("No landmark anchors available. Say location is unavailable rather than guessing.")
	return "\n".join(lines).left(MAX_CONTEXT_CHARS)

func _name(actor: Node3D) -> String:
	return str(actor.character_name).replace("\n", " ").replace("\r", " ").left(80)

func _position_available(actor: Node3D) -> bool:
	return is_instance_valid(actor) and actor.is_inside_tree() and actor.global_position.is_finite()

func _relative(point: Vector3, speaker: Node3D) -> String:
	var offset := point - speaker.global_position
	var distance := Vector2(offset.x, offset.z).length()
	var result := "; within a metre of you" if distance < 1.0 else "; about %d m %s of you" % [roundi(distance), _direction(offset)]
	if absf(offset.y) >= 2.5: result += ", about %d m %s" % [roundi(absf(offset.y)), "higher" if offset.y > 0 else "lower"]
	return result

func _direction(offset: Vector3) -> String:
	# atan2(x, -z): north=0, east=PI/2, south=PI.
	var compass := ["north", "northeast", "east", "southeast", "south", "southwest", "west", "northwest"]
	return compass[posmod(roundi(atan2(offset.x, -offset.z) / (PI / 4.0)), 8)]

func describe_position(point: Vector3, landmarks: Array[Dictionary]) -> String:
	if not point.is_finite() or landmarks.is_empty(): return "location unavailable (no reliable landmark match)"
	var nearest: Dictionary = {}
	var nearest_point := Vector3.ZERO
	var score := INF
	for landmark in landmarks:
		var anchor: Vector3 = landmark.center
		if landmark.has("bounds"):
			var bounds: AABB = landmark.bounds
			anchor = point.clamp(bounds.position, bounds.end)
		elif landmark.has("path"):
			var path: Array[Vector3] = landmark.path
			var best := INF
			for i in range(path.size() - 1):
				var candidate := Geometry3D.get_closest_point_to_segment(point, path[i], path[i + 1])
				if point.distance_squared_to(candidate) < best:
					best = point.distance_squared_to(candidate)
					anchor = candidate
		var distance := point.distance_to(anchor)
		if distance < score:
			score = distance
			nearest = landmark
			nearest_point = anchor
	if nearest.is_empty(): return "location unavailable"
	var offset := point - nearest_point
	var horizontal := Vector2(offset.x, offset.z).length()
	var place := "by %s" % nearest.label if horizontal < 3.0 else "about %d m %s of %s" % [roundi(horizontal), _direction(offset), nearest.label]
	if absf(offset.y) >= 2.5: place += ", about %d m %s its anchor" % [roundi(absf(offset.y)), "above" if offset.y > 0 else "below"]
	if score > 35.0: place = "away from the mapped landmarks; " + place
	return place

func _landmarks(world: Node) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not is_instance_valid(world): return result
	# Actual transformed mesh bounds follow the installed runtime geometry.
	for row in [
		["TempleMap/Temple_Interior_Tiled_Floor", "temple interior"],
		["TempleMap/Altar_Marble_Bust", "temple bust and altar"],
		["TempleMap/Lower_Pool_Water_Fitted", "lower pool"],
		["TempleMap/Fountain_Circular_Water", "circular fountain"],
		["TempleMap/Central_Stair_Courtyard", "central stairs courtyard"],
		["TempleMap/Temple_Terrace_Plaza", "temple terrace and forecourt"],
		["SouthGarden/Garden/SouthGarden_Pond_Water", "south garden koi pond"],
		["SouthGarden/Garden/SouthGarden_Zen_Sand", "south garden raked sand garden"],
	]:
		var mesh := world.get_node_or_null(row[0]) as MeshInstance3D
		if mesh and mesh.mesh:
			var bounds := mesh.global_transform * mesh.get_aabb()
			result.append({"label": row[1], "center": bounds.get_center(), "bounds": bounds})
	var bridges := world.get_node_or_null("IslandBridges") as Node3D
	if bridges:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
		if parsed is Dictionary:
			for bridge in parsed.get("bridges", []):
				if not bridge is Dictionary or not BRIDGE_NAMES.has(bridge.get("name", "")): continue
				var path: Array[Vector3] = []
				for section in bridge.get("sections", []):
					var p: Variant = section.get("position", [])
					if p is Array and p.size() == 3: path.append(bridges.to_global(Vector3(p[0], p[1], p[2])))
				if path.size() >= 2:
					result.append({"label": BRIDGE_NAMES[bridge.name], "center": path[path.size() / 2], "path": path})
	var pagoda := world.get_node_or_null("NorthPagoda") as Node3D
	if pagoda:
		var plan: Variant = pagoda.get("plan")
		if plan is Dictionary:
			var center: Variant = plan.get("center", [])
			if center is Array and center.size() == 3:
				result.append({"label": "north island pagoda", "center": pagoda.to_global(Vector3(center[0], center[1], center[2]))})
				var floors: Array = plan.get("floor_heights", [])
				var halves: Array = plan.get("room_halves", [])
				for i in mini(3, mini(floors.size(), halves.size())):
					var floor_center := Vector3(center[0], floors[i], center[2])
					var half: float = halves[i]
					var footprint := AABB(floor_center - Vector3(half, 0.0, half), Vector3(half * 2.0, 0.1, half * 2.0))
					result.append({"label": "north pagoda %s floor" % ["ground", "middle", "top"][i], "center": pagoda.to_global(floor_center), "bounds": pagoda.global_transform * footprint})
			var entry: Variant = plan.get("entry", [])
			if entry is Array and entry.size() == 3:
				result.append({"label": "north pagoda entrance", "center": pagoda.to_global(Vector3(entry[0], entry[1], entry[2]))})
	var garden := world.get_node_or_null("SouthGarden") as Node3D
	if garden:
		# The deck is batched with benches visually. Its installed plank collision
		# provides a precise footprint without treating every wood mesh as a deck.
		var structure := garden.get_node_or_null("GardenStructure")
		var deck_bounds := AABB()
		var plank_count := 0
		if structure:
			for child in structure.get_children():
				if child is CollisionShape3D and child.shape is BoxShape3D and child.shape.size.is_equal_approx(Vector3(3.0, 0.12, 0.11)):
					var plank: AABB = child.global_transform * AABB(-child.shape.size * 0.5, child.shape.size)
					deck_bounds = plank if plank_count == 0 else deck_bounds.merge(plank)
					plank_count += 1
		if plank_count > 1: result.append({"label": "south garden timber viewing deck", "center": deck_bounds.get_center(), "bounds": deck_bounds})
		var plan: Variant = garden.get("plan")
		if plan is Dictionary:
			var routes: Variant = plan.get("routes", [])
			# The third path in the installed garden plan is its public perimeter loop.
			if routes is Array and routes.size() > 2:
				var path: Array[Vector3] = []
				for p in routes[2]:
					if p is Array and p.size() == 3: path.append(garden.to_global(Vector3(p[0], p[1], p[2])))
				if path.size() >= 2: result.append({"label": "south garden perimeter path", "center": path[0], "path": path})
	return result
