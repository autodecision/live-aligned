extends SceneTree
## Exercise the real draw/read/stow task and export the actual bone poses.
const OUT := "/home/allister/Projects/live-aligned-previews/site-finish-2026-10-18/scientist/"
var main: Node3D
var scientist: PS3CharacterNPC
var camera: Camera3D
var poses: Array = []
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		failed = true

func save_pose(label: String) -> void:
	var bones := {}
	for bone: String in scientist._bones:
		var transform: Transform3D = scientist.skeleton.get_bone_global_pose(scientist._bones[bone]) * scientist._global_rest[bone].affine_inverse()
		bones[bone] = [
			[transform.basis.x.x, transform.basis.y.x, transform.basis.z.x, transform.origin.x],
			[transform.basis.x.y, transform.basis.y.y, transform.basis.z.y, transform.origin.y],
			[transform.basis.x.z, transform.basis.y.z, transform.basis.z.z, transform.origin.z],
			[0.0, 0.0, 0.0, 1.0]]
	poses.append({"label": label, "bones": bones})

func capture(label: String, offset: Vector3, target: Vector3) -> void:
	camera.position = scientist.position + offset
	camera.look_at(scientist.position + target)
	for frame in 10:
		await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT + label + ".png")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var capture_views := "--capture" in OS.get_cmdline_user_args()
	root.size = Vector2i(1440, 900)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.position = Vector3(-20, 4, 0)
	player.get_node("CanvasLayer").hide()
	main.get_node("CharacterDialogue").hide()
	main.get_node("VisualLab").select_preset(0)
	main.get_node("DayNightCycle").running = false
	main.get_node("DayNightCycle").set_phase(.25)
	for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false)
	scientist = main.get_node("IslandCharacters/Scientist")
	scientist.position = Vector3(-1.5, .065, 10.5)
	scientist.rotation.y = -.55
	scientist.current_state = PS3CharacterNPC.State.IDLE
	scientist.current_activity = "record"
	scientist._motion_weight = 0.0
	await physics_frame
	if capture_views:
		root.always_on_top = true
		root.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		camera = Camera3D.new()
		main.add_child(camera)
		camera.current = true
		camera.fov = 45
	for frame in 330:
		scientist.state_timer = 5.5 - float(frame) / 60.0
		scientist._elapsed += 1.0 / 60.0
		scientist._animate(1.0 / 60.0, 0.0)
		if frame == 0:check(not scientist.palm_pad.visible, "Reader visible before reaching into pocket")
		if frame == 90:
			check(scientist.palm_pad.visible, "Missing reader during record activity")
			var head: Vector3 = scientist.skeleton.get_bone_global_pose(scientist._bones.head).origin
			var to_head := (head - scientist.palm_pad.position).normalized()
			check(scientist.palm_pad.basis.z.dot(to_head) > .55, "Reader screen faces away from the scientist")
			check(scientist.palm_pad.position.y > 1.05, "Reader was not raised to reading height")
		if frame % 15 == 0:save_pose("record_%03d" % frame)
		if capture_views and frame in [9, 27, 90, 294, 329]:
			await capture("task_%03d" % frame, Vector3(-2.2, 1.8, -1.7), Vector3(0, 1.15, 0))
	check(not scientist.palm_pad.visible, "Reader not stowed before walking")
	for phase in 60:
		scientist.current_activity = "travel"
		scientist.current_state = PS3CharacterNPC.State.WALK
		scientist._motion_weight = 1.0
		scientist._phase = float(phase) / 60.0
		scientist._animate(0.0, 0.0)
		save_pose("walk_%02d" % phase)
		check(not scientist.palm_pad.visible, "Reader visible during walking")
	scientist._motion_weight = 0.0
	scientist.current_state = PS3CharacterNPC.State.IDLE
	scientist.current_activity = "observe"
	scientist._animate(1.0, 0.0)
	save_pose("observe")
	if capture_views:
		await capture("badge_front", Vector3(-.7, 1.65, -1.9), Vector3(0, 1.25, 0))
		await capture("badge_side", Vector3(-1.8, 1.45, -.4), Vector3(0, 1.25, 0))
	FileAccess.open(OUT + "poses.json", FileAccess.WRITE).store_string(JSON.stringify(poses))
	print("SCIENTIST_ACCESSORIES_", "FAIL" if failed else "PASS", " poses=", poses.size())
	quit(1 if failed else 0)
