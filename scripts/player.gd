extends CharacterBody3D

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 9.0
@export var acceleration: float = 12.0
@export var deceleration: float = 16.0
@export var air_control: float = 3.0
@export var jump_velocity: float = 5.5
@export var mouse_sensitivity: float = 0.0025
@export var max_step_height: float = 0.35

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var help_label: Label = $CanvasLayer/HUD/HelpLabel

var is_mouse_captured: bool = true
var spawn_point: Vector3

func _ready() -> void:
	spawn_point = global_position
	capture_mouse(true)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(75.0)
	floor_constant_speed = true
	floor_block_on_wall = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if not is_mouse_captured:
			capture_mouse(true)
			get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("toggle_mouse"):
		capture_mouse(not is_mouse_captured)
		get_viewport().set_input_as_handled()
		
	if is_mouse_captured and event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-88.0), deg_to_rad(88.0))

func capture_mouse(captured: bool) -> void:
	is_mouse_captured = captured
	if captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if help_label:
			help_label.text = "WASD: Move | Shift: Sprint | Space: Jump | Esc: Free Cursor | F7: Visual Lab"
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if help_label:
			help_label.text = "Click to capture cursor | Esc: Free Cursor | F7: Visual Lab"

func _physics_process(delta: float) -> void:
	# Fall reset check (e.g. if player jumps into the sea off the cliff)
	if global_position.y < -25.0:
		global_position = spawn_point
		velocity = Vector3.ZERO
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump (allows normal jump on floor, or vaulting up steep terrain when against a wall)
	if (is_on_floor() or is_on_wall()) and Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# Determine target speed
	var target_speed := walk_speed
	if Input.is_action_pressed("sprint"):
		target_speed = sprint_speed

	# Get input direction relative to player rotation
	var input_dir := Vector2.ZERO
	if is_mouse_captured:
		input_dir.x = Input.get_action_strength("move_right") - Input.get_action_strength("move_left")
		input_dir.y = Input.get_action_strength("move_backward") - Input.get_action_strength("move_forward")
	
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Horizontal acceleration / friction
	var h_vel := Vector3(velocity.x, 0, velocity.z)
	var accel := acceleration if is_on_floor() else air_control
	var decel := deceleration if is_on_floor() else 1.0

	if wish_dir.length() > 0.01:
		var target_h_vel := wish_dir * target_speed
		h_vel = h_vel.move_toward(target_h_vel, accel * delta * target_speed)
	else:
		h_vel = h_vel.move_toward(Vector3.ZERO, decel * delta * target_speed)

	velocity.x = h_vel.x
	velocity.z = h_vel.z

	# Perform move with step assist
	move_and_slide()

	# Step-up assist: if we hit a small step, curb, or rocky ledge while moving forward
	if wish_dir.length() > 0.1 and is_on_wall():
		for step_offset in [0.15, 0.25, 0.35, max_step_height]:
			var test_xform := global_transform
			test_xform.origin.y += step_offset
			if not test_move(test_xform, Vector3.ZERO):
				if not test_move(test_xform, wish_dir * 0.15):
					global_position.y += step_offset * 0.5
					break
