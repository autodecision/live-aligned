extends CharacterBody3D

const UIThemes = preload("res://scripts/ui_themes.gd")
const DIALOGUE_ZOOM_FOV := 38.0
const DIALOGUE_ZOOM_IN_SPEED := 3.4
const DIALOGUE_ZOOM_OUT_SPEED := 3.6

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
@onready var reset_button: Button = $CanvasLayer/HUD/ResetPosition
@onready var help_label: Label = $CanvasLayer/HUD/HelpLabel

var dialogue_locked := false
var dialogue_zoom_target: Node3D
var dialogue_zoom_weight: float = 0.0
var is_dialogue_zoomed: bool = false
var _pre_dialogue_fov: float = 75.0
var _pre_dialogue_head_x: float = 0.0
var _base_head_position: Vector3
var _dialogue_hud_was_visible := true
var is_mouse_captured: bool = true
var spawn_point: Vector3
var spawn_rotation: Vector3
var spawn_head_rotation: Vector3
var _toast_timer := 0.0

func _ready() -> void:
	spawn_point = global_position
	spawn_rotation = global_rotation
	spawn_head_rotation = head.rotation
	_base_head_position = head.position
	_pre_dialogue_fov = camera.fov
	reset_button.pressed.connect(reset_position)
	capture_mouse(true)
	UIThemes.add_theme_listener(_on_theme_changed)
	_apply_hud_theme(UIThemes.get_current())
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(75.0)
	floor_constant_speed = true
	floor_block_on_wall = false

func _unhandled_input(event: InputEvent) -> void:
	if dialogue_locked: return
	if event is InputEventKey and event.pressed and not event.echo and (event.physical_keycode == KEY_F10 or event.keycode == KEY_F10):
		var t := UIThemes.cycle_theme(1)
		_show_theme_toast(t)
		get_viewport().set_input_as_handled()
		return
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

func set_dialogue_locked(locked: bool) -> void:
	if locked and not dialogue_locked:
		_dialogue_hud_was_visible = $CanvasLayer/HUD.visible
	dialogue_locked = locked
	$CanvasLayer/HUD.visible = false if locked else _dialogue_hud_was_visible
	velocity = Vector3.ZERO
	if locked:
		capture_mouse(false)
		reset_button.hide()
		help_label.hide()
	else:
		if is_dialogue_zoomed:
			end_dialogue_zoom()
		help_label.show()

## Starts a Skyrim-style camera zoom and focus onto the given character's face.
func begin_dialogue_zoom(target: Node3D) -> void:
	if not is_dialogue_zoomed and dialogue_zoom_weight <= 0.001 and is_instance_valid(camera):
		_pre_dialogue_fov = camera.fov
		_pre_dialogue_head_x = head.rotation.x
	dialogue_zoom_target = target
	is_dialogue_zoomed = true
	_update_dialogue_zoom(1.0 / 60.0)

## Smoothly zooms the camera back out to the player's normal field of view.
func end_dialogue_zoom() -> void:
	is_dialogue_zoomed = false
	_update_dialogue_zoom(1.0 / 60.0)

func _update_dialogue_zoom(delta: float) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(head):
		return
	if is_dialogue_zoomed:
		dialogue_zoom_weight = move_toward(dialogue_zoom_weight, 1.0, delta * DIALOGUE_ZOOM_IN_SPEED)
		var t := smoothstep(0.0, 1.0, dialogue_zoom_weight)
		var target_fov := minf(_pre_dialogue_fov * 0.52, DIALOGUE_ZOOM_FOV)
		camera.fov = lerpf(_pre_dialogue_fov, target_fov, t)
		if is_instance_valid(dialogue_zoom_target) and dialogue_zoom_target.is_inside_tree():
			var face_pos: Vector3 = dialogue_zoom_target.get_face_focus_position() if dialogue_zoom_target.has_method("get_face_focus_position") else (dialogue_zoom_target.global_position + Vector3.UP * 1.62)
			var head_origin: Vector3 = global_position + _base_head_position
			var to_face: Vector3 = face_pos - head_origin
			var horiz_len := Vector2(to_face.x, to_face.z).length()
			if horiz_len > 0.05:
				var desired_yaw := atan2(-to_face.x, -to_face.z)
				var turn_blend := clampf(delta * 9.0, 0.18, 1.0)
				global_rotation.y = lerp_angle(global_rotation.y, desired_yaw, turn_blend)
				var desired_pitch := clampf(atan2(to_face.y, horiz_len), deg_to_rad(-55.0), deg_to_rad(55.0))
				head.rotation.x = lerpf(head.rotation.x, desired_pitch, turn_blend)
	elif dialogue_zoom_weight > 0.0:
		dialogue_zoom_weight = move_toward(dialogue_zoom_weight, 0.0, delta * DIALOGUE_ZOOM_OUT_SPEED)
		var t := smoothstep(0.0, 1.0, dialogue_zoom_weight)
		var target_fov := minf(_pre_dialogue_fov * 0.52, DIALOGUE_ZOOM_FOV)
		camera.fov = lerpf(_pre_dialogue_fov, target_fov, t)
		head.rotation.x = lerpf(_pre_dialogue_head_x, head.rotation.x, t)
		if dialogue_zoom_weight <= 0.0001:
			dialogue_zoom_weight = 0.0
			camera.fov = _pre_dialogue_fov
			head.rotation.x = _pre_dialogue_head_x
			dialogue_zoom_target = null

func capture_mouse(captured: bool) -> void:
	if dialogue_locked and captured: return
	is_mouse_captured = captured
	if reset_button:
		reset_button.visible = not captured
	if captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if help_label:
			help_label.text = "WASD: Move | Shift: Sprint | Space: Jump | Esc: Cursor / Reset | F7: Visual Lab | F8: Settings | F10: Theme"
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if help_label:
			help_label.text = "Click to capture cursor | Esc: Cursor / Reset | F7: Visual Lab | F8: Settings | F10: Theme"

func _process(delta: float) -> void:
	_update_dialogue_zoom(delta)
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			capture_mouse(is_mouse_captured)

func _exit_tree() -> void:
	UIThemes.remove_theme_listener(_on_theme_changed)

func _on_theme_changed(_id: String, theme_data: Dictionary) -> void:
	_apply_hud_theme(theme_data)

func _apply_hud_theme(theme_data: Dictionary) -> void:
	if is_instance_valid(reset_button):
		reset_button.add_theme_color_override("font_color", theme_data.ink)
		reset_button.add_theme_color_override("font_hover_color", theme_data.accent)
	if has_node("CanvasLayer/HUD/CenterContainer/Crosshair"):
		var crosshair: ColorRect = get_node("CanvasLayer/HUD/CenterContainer/Crosshair")
		crosshair.color = Color(theme_data.accent.r, theme_data.accent.g, theme_data.accent.b, 0.85)
	if has_node("CanvasLayer/HUD/TitleLabel"):
		var title: Label = get_node("CanvasLayer/HUD/TitleLabel")
		title.add_theme_color_override("font_color", theme_data.accent)

func _show_theme_toast(theme_data: Dictionary) -> void:
	if not help_label: return
	var tag: String = "[%s] " % theme_data.roygbiv_letter if theme_data.category == "ROYGBIV" else "★ "
	help_label.text = "UI Theme: %s%s  ·  F10 to cycle" % [tag, theme_data.name]
	_toast_timer = 2.5

func reset_position() -> void:
	global_position = spawn_point
	global_rotation = spawn_rotation
	head.rotation = spawn_head_rotation
	velocity = Vector3.ZERO
	reset_physics_interpolation()

func _physics_process(delta: float) -> void:
	if dialogue_locked:
		velocity = Vector3.ZERO
		return
	# Fall reset check (e.g. if player jumps into the sea off the cliff)
	if global_position.y < -25.0:
		reset_position()
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
