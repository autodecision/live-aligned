class_name PS3CharacterNPC
extends CharacterBody3D
## Distance-driven, grounded walking for the three +Z-facing character rigs.
## Route corners are transit points; only named tasks cause a deliberate stop.

@export var character_name: String = "Character"
@export var character_id: String = "alien_suit"
@export var model_path: String = "res://assets/characters/alien_suit.glb"
@export var walk_speed: float = 1.5
@export var turn_speed: float = 2.5
@export var acceleration: float = 3.0
@export var arrival_distance: float = 0.22
@export var waypoints: Array = []

enum State { IDLE, WALK }
var current_state: State = State.IDLE
var current_waypoint_idx: int = 0
var current_activity: String = "observe"
var state_timer: float = 0.0
var stuck_timer: float = 0.0
var completed_stops: int = 0
var completed_laps: int = 0
var recovery_count: int = 0
var route: Array[Dictionary] = []
var model_node: Node3D
var skeleton: Skeleton3D
var collision_shape: CollisionShape3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _bones: Dictionary = {}
var _rest: Dictionary = {}
var _global_rest: Dictionary = {}
var _phase: float = 0.0
var _motion_weight: float = 0.0
var _activity_weight: float = 0.0
var _elapsed: float = 0.0
var _stride: float = 1.48
var _lift: float = 0.16
var _hip_drop: float = 0.13
var _arm_swing: float = 0.42
var _head_yaw: float = 0.0
var _turn_rate: float = 0.0
var _detour: Vector3
var _has_detour: bool = false
var _grounded_once: bool = false
var _player: Node3D

func set_waypoints(points: Array) -> void:
	route.clear()
	waypoints.clear()
	for point in points:
		var p: Vector3 = point if point is Vector3 else Vector3(point[0], point[1], point[2])
		waypoints.append(p)
		route.append({"position": p})

func set_route(stops: Array[Dictionary]) -> void:
	route = stops.duplicate(true)
	waypoints.clear()
	for stop in route:
		waypoints.append(stop.position)

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(55.0)
	floor_constant_speed = true
	floor_block_on_wall = false
	_setup_collision()
	_setup_model()
	if route.is_empty() and not waypoints.is_empty():
		set_waypoints(waypoints.duplicate())
	if not waypoints.is_empty():
		global_position = waypoints[0]
		if waypoints.size() > 1:
			var direction: Vector3 = waypoints[1] - waypoints[0]
			rotation.y = atan2(-direction.x, -direction.z)
	state_timer = 1.0
	_player = get_tree().current_scene.get_node_or_null("Player") if get_tree().current_scene else get_parent().get_parent().get_node_or_null("Player")

func _setup_collision() -> void:
	collision_shape = CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	match character_id:
		"female_scientist":
			capsule.radius = 0.32
			capsule.height = 1.82
			_stride = 1.24
			_hip_drop = 0.105
			_arm_swing = 0.48
		"robot":
			capsule.radius = 0.38
			capsule.height = 2.14
			_stride = 1.30
			_hip_drop = 0.115
			_lift = 0.19
			_arm_swing = 0.32
		_:
			capsule.radius = 0.35
			capsule.height = 2.26
	collision_shape.position.y = capsule.height * 0.5
	collision_shape.shape = capsule
	add_child(collision_shape)

func _setup_model() -> void:
	var scene := load(model_path) as PackedScene
	if not scene:
		push_error("PS3CharacterNPC: missing model " + model_path)
		return
	model_node = scene.instantiate()
	# The portable assets face +Z. The controller, cameras and routes use -Z.
	model_node.rotation.y = PI
	add_child(model_node)
	var skeletons := model_node.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	skeleton = skeletons[0] as Skeleton3D
	for i in skeleton.get_bone_count():
		var bone := skeleton.get_bone_name(i)
		_bones[bone] = i
		_rest[bone] = skeleton.get_bone_rest(i)
		_global_rest[bone] = skeleton.get_bone_global_rest(i)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if not _grounded_once:
		# Wait until physics has registered the world before placing the feet.
		var ground := _ground_at(global_position, 1.5, 5.0)
		if not ground.is_empty():
			global_position.y = ground.position.y + 0.015
			_grounded_once = true
	if global_position.y < -20.0 and not waypoints.is_empty():
		global_position = waypoints[0] + Vector3.UP * 0.1
		velocity = Vector3.ZERO
		current_waypoint_idx = 0
		current_state = State.IDLE
		state_timer = 1.0
		_grounded_once = false
		recovery_count += 1
	if not is_on_floor():
		velocity.y -= gravity * delta
	var previous_position := global_position
	var previous_yaw := rotation.y
	var desired := Vector3.ZERO
	var yielding := false
	if not route.is_empty():
		if current_state == State.IDLE:
			_face_interest(delta)
			state_timer -= delta
			if state_timer <= 0.0 and route.size() > 1:
				_advance_route()
		else:
			var target: Vector3 = _detour if _has_detour else route[current_waypoint_idx].position
			var difference := target - global_position
			difference.y = 0.0
			var distance := difference.length()
			if distance < arrival_distance and absf(target.y - global_position.y) < 0.85:
				if _has_detour:
					_has_detour = false
				elif route[current_waypoint_idx].has("activity"):
					current_state = State.IDLE
					current_activity = route[current_waypoint_idx].activity
					state_timer = route[current_waypoint_idx].get("duration", 4.0)
					completed_stops += 1
				else:
					_advance_route()
			else:
				var yaw := atan2(-difference.x, -difference.z)
				rotation.y = rotate_toward(rotation.y, yaw, turn_speed * delta)
				var error := absf(angle_difference(rotation.y, yaw))
				# Brake for a sharp turn and step around before moving off.
				var alignment := smoothstep(0.1, 0.9, cos(error))
				var braking := minf(1.0, sqrt(maxf(distance - 0.10, 0.0) * 2.0 * acceleration) / walk_speed)
				desired = -global_basis.z * walk_speed * alignment * braking
				yielding = _person_ahead()
				if yielding or not _safe_ground_ahead(desired):
					desired = Vector3.ZERO
	var horizontal := Vector3(velocity.x, 0, velocity.z).move_toward(desired, acceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	move_and_slide()
	if is_on_wall() and desired.length() > 0.1:
		_step_up(desired.normalized())
	var displacement := global_position - previous_position
	displacement.y = 0.0
	var speed := displacement.length() / maxf(delta, 0.001)
	_turn_rate = angle_difference(previous_yaw, rotation.y) / delta
	if current_state == State.WALK and desired.length() > 0.3 and speed < 0.12 and not yielding:
		stuck_timer += delta
		if stuck_timer > 2.0:
			_find_detour()
			stuck_timer = 0.0
	else:
		stuck_timer = maxf(0.0, stuck_timer - delta * 2.0)
	_animate(delta, speed)

func _advance_route() -> void:
	current_waypoint_idx = (current_waypoint_idx + 1) % route.size()
	if current_waypoint_idx == 0:
		completed_laps += 1
	current_state = State.WALK
	current_activity = "travel"
	stuck_timer = 0.0

func _face_interest(delta: float) -> void:
	var point: Vector3 = route[current_waypoint_idx].get("look_at", global_position - global_basis.z * 3.0)
	var direction := point - global_position
	if Vector2(direction.x, direction.z).length() > 0.1:
		rotation.y = rotate_toward(rotation.y, atan2(-direction.x, -direction.z), turn_speed * 0.5 * delta)

func _person_ahead() -> bool:
	# Yield to the player without altering their movement/collision preferences.
	if not is_instance_valid(_player):
		return false
	var offset := _player.global_position - global_position
	return absf(offset.y) < 1.5 and offset.length() < 1.45 and offset.dot(-global_basis.z) > 0.3

func _ground_at(point: Vector3, above: float = 0.55, below: float = 0.8) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * above, point - Vector3.UP * below, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func _safe_ground_ahead(desired: Vector3) -> bool:
	if desired.length() < 0.1:
		return true
	var hit := _ground_at(global_position + desired.normalized() * 0.5)
	return not hit.is_empty() and hit.normal.y > 0.55

func _step_up(direction: Vector3) -> void:
	# A curb needs both capsule clearance and an actual walkable landing.
	for height in [0.12, 0.22, 0.32]:
		var raised := global_transform
		raised.origin.y += height
		if test_move(raised, Vector3.ZERO) or test_move(raised, direction * 0.2):
			continue
		var landing := _ground_at(global_position + direction * 0.35, height + 0.1, 0.1)
		if not landing.is_empty() and landing.normal.y > 0.65 and landing.position.y > global_position.y + 0.02:
			global_position.y += height * 0.5
			return

func _find_detour() -> void:
	# Keep the same task. Never silently skip it or teleport through an obstacle.
	for side in [1.0, -1.0]:
		var offset: Vector3 = global_basis.x * side * 0.85 - global_basis.z * 0.35
		var hit := _ground_at(global_position + offset)
		if not hit.is_empty() and not test_move(global_transform, offset):
			_detour = hit.position
			_has_detour = true
			recovery_count += 1
			return

func _rotate_rest(bone: String, axis: Vector3, angle: float) -> void:
	if not _bones.has(bone):
		return
	# Convert a model-space axis into this particular bone's rolled rest frame.
	# The shoulders have different rolls; blindly rotating local X twists them.
	var local_axis: Vector3 = _global_rest[bone].basis.inverse() * axis
	var rotation_q: Quaternion = _rest[bone].basis.get_rotation_quaternion() * Quaternion(local_axis.normalized(), angle)
	skeleton.set_bone_pose_rotation(_bones[bone], rotation_q)

func _set_global_rotation(bone: String, rotation_q: Quaternion) -> void:
	var index: int = _bones[bone]
	var parent := skeleton.get_bone_parent(index)
	var parent_q := Quaternion.IDENTITY
	if parent >= 0:
		parent_q = skeleton.get_bone_global_pose(parent).basis.get_rotation_quaternion()
	skeleton.set_bone_pose_rotation(index, parent_q.inverse() * rotation_q)

func _solve_leg(side: String, ankle: Vector3, pitch: float) -> void:
	var thigh := "thigh." + side
	var shin := "shin." + side
	var foot := "foot." + side
	var hip := skeleton.get_bone_global_pose(_bones[thigh]).origin
	var upper: float = _rest[shin].origin.length()
	var lower: float = _rest[foot].origin.length()
	var to_ankle := ankle - hip
	var distance := clampf(to_ankle.length(), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var direction := to_ankle.normalized()
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var height := sqrt(maxf(upper * upper - along * along, 0.0))
	# Knees bend toward the asset's +Z-facing toes.
	var pole := (Vector3.BACK - direction * direction.dot(Vector3.BACK)).normalized()
	var knee := hip + direction * along + pole * height
	var thigh_rest: Basis = _global_rest[thigh].basis
	var shin_rest: Basis = _global_rest[shin].basis
	_set_global_rotation(thigh, Quaternion(thigh_rest.y.normalized(), (knee - hip).normalized()) * thigh_rest.get_rotation_quaternion())
	_set_global_rotation(shin, Quaternion(shin_rest.y.normalized(), (ankle - knee).normalized()) * shin_rest.get_rotation_quaternion())
	_set_global_rotation(foot, Quaternion(Vector3.RIGHT, pitch) * _global_rest[foot].basis.get_rotation_quaternion())

func _animate(delta: float, speed: float) -> void:
	if not skeleton:
		return
	var turning := minf(absf(_turn_rate) * 0.22, 0.45)
	var moving := maxf(speed, turning)
	_motion_weight = move_toward(_motion_weight, clampf(moving / 0.65, 0.0, 1.0), delta * 4.0)
	# One full gait cycle covers one stride, independent of frame rate or speed.
	_phase = fposmod(_phase + moving * delta / _stride, 1.0)
	var wave := sin(_phase * TAU)
	var arm_wave := cos(_phase * TAU)
	var breath := sin(_elapsed * 1.8)
	var task_amount := 1.0 if current_state == State.IDLE and state_timer > 0.7 else 0.0
	_activity_weight = move_toward(_activity_weight, task_amount, delta * 2.0)
	for bone in _bones:
		skeleton.set_bone_pose_rotation(_bones[bone], _rest[bone].basis.get_rotation_quaternion())
	var pelvis: Vector3 = _rest["pelvis"].origin
	pelvis += Vector3(wave * 0.018, -_hip_drop + absf(wave) * 0.025, 0) * _motion_weight
	pelvis.y += breath * 0.003 * (1.0 - _motion_weight)
	skeleton.set_bone_pose_position(_bones["pelvis"], pelvis)
	_rotate_rest("pelvis", Vector3.UP, wave * 0.055 * _motion_weight)
	_rotate_rest("spine", Vector3.UP, -wave * 0.08 * _motion_weight)
	_rotate_rest("chest", Vector3.RIGHT, 0.035 * _motion_weight + breath * 0.008)
	for side in ["L", "R"]:
		var sign_side := 1.0 if side == "L" else -1.0
		var cycle := fposmod(_phase + (0.0 if side == "L" else 0.5), 1.0)
		var z: float
		var lift := 0.0
		var pitch := 0.0
		if cycle < 0.6:
			# Constant backwards foot speed cancels body travel during stance.
			z = _stride * (0.3 - cycle)
			pitch = smoothstep(0.42, 0.6, cycle) * 0.20
		else:
			var swing := (cycle - 0.6) / 0.4
			z = lerpf(-_stride * 0.3, _stride * 0.3, smoothstep(0.0, 1.0, swing))
			lift = sin(swing * PI) * _lift
			pitch = lerpf(0.20, -0.08, swing)
		var foot_rest: Vector3 = _global_rest["foot." + side].origin
		var ankle := foot_rest + Vector3(0, lift, z) * _motion_weight
		var world_foot := skeleton.to_global(Vector3(ankle.x, 0, ankle.z))
		world_foot.y = global_position.y
		var ground := _ground_at(world_foot, 0.65, 0.85)
		if not ground.is_empty():
			ankle.y += clampf(ground.position.y - global_position.y, -0.3, 0.32)
		_solve_leg(side, ankle, pitch * _motion_weight)
		_rotate_rest("upper_arm." + side, Vector3.RIGHT, sign_side * arm_wave * _arm_swing * _motion_weight)
		_rotate_rest("forearm." + side, Vector3.RIGHT, -0.16 - maxf(0, -sign_side * arm_wave) * 0.30 * _motion_weight)
		_rotate_rest("hand." + side, Vector3.RIGHT, -0.06 + sign_side * wave * 0.04 * _motion_weight)
	var gaze := sin(_elapsed * 0.55) * 0.16 * (1.0 - _motion_weight)
	if current_state == State.WALK and not route.is_empty():
		var difference: Vector3 = route[current_waypoint_idx].position - global_position
		gaze = clampf(angle_difference(rotation.y, atan2(-difference.x, -difference.z)), -0.5, 0.5)
	_head_yaw = lerpf(_head_yaw, gaze, 1.0 - exp(-delta * 5.0))
	_rotate_rest("head", Vector3.UP, _head_yaw)
	# Quiet, readable tasks: study the surroundings, check a wrist, scan equipment.
	if current_activity == "record":
		_rotate_rest("upper_arm.L", Vector3.RIGHT, -0.42 * _activity_weight)
		_rotate_rest("forearm.L", Vector3.RIGHT, -1.15 * _activity_weight - 0.16)
		_rotate_rest("upper_arm.R", Vector3.RIGHT, -0.22 * _activity_weight)
		_rotate_rest("forearm.R", Vector3.RIGHT, -0.75 * _activity_weight - 0.16)
		_rotate_rest("head", Vector3.RIGHT, 0.22 * _activity_weight)
	elif current_activity == "inspect":
		_rotate_rest("chest", Vector3.RIGHT, 0.10 * _activity_weight)
		_rotate_rest("upper_arm.R", Vector3.RIGHT, -0.55 * _activity_weight)
		_rotate_rest("forearm.R", Vector3.RIGHT, -0.7 * _activity_weight - 0.16)
		_rotate_rest("head", Vector3.RIGHT, 0.18 * _activity_weight)
