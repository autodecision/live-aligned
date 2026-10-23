extends SceneTree
const OUT = "/home/allister/Projects/live-aligned-previews/garden-polish-2026-10-18/after/"
var main:Node3D
var camera:Camera3D

func _initialize()->void:call_deferred("run")

func capture(label:String, point:Vector3, target:Vector3, phase:float=0.25)->void:
	camera.position = point
	camera.look_at(target)
	main.get_node("DayNightCycle").set_phase(phase)
	var start:=Time.get_ticks_msec()
	while Time.get_ticks_msec()-start<1200:await process_frame
	RenderingServer.force_draw(false)
	root.get_texture().get_image().save_png(OUT+label+".png")
	print("CAPTURED: ", label)

func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size = Vector2i(1440,900)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main = load("res://scenes/main.tscn").instantiate()
	main.get_node("Player").dialogue_locked=true
	root.add_child(main)
	var player:CharacterBody3D = main.get_node("Player")
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	player.get_node("CanvasLayer").hide()
	player.position = Vector3(-3.5,1.2,12.0)
	main.get_node("CharacterDialogue").hide()
	main.get_node("VisualLab").select_preset(0)
	main.get_node("RenderOptimization").set_performance_mode(false,false)
	main.get_node("DayNightCycle").running = false
	main.get_node("DayNightCycle").set_phase(0.25)
	await physics_frame
	camera = Camera3D.new()
	main.add_child(camera)
	camera.current = true
	camera.fov = 65
	if not "--kestrel-only" in OS.get_cmdline_user_args():
		await capture("bottles",Vector3(-2.80,6.81,-4.06),Vector3(-1.30,6.73,-4.06))
		await capture("railing",Vector3(16,4,17),Vector3(6.8,.6,9))
		await capture("island",Vector3(101,34,54),Vector3(102,4,33))
		await capture("cliff_rock",Vector3(72,8,38),Vector3(85,3,37))
		await capture("tiles",Vector3(116,7,29),Vector3(116,4.7,34))
		await capture("outflow",Vector3(16,1,12),Vector3(10.9,-2,7.45))
	for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false)
	var robot:PS3CharacterNPC=main.get_node("IslandCharacters/Robot")
	robot.position=Vector3(106,4.735,26.54)
	robot.rotation.y=0.
	robot.model_node.rotation.y=PI
	robot.current_activity="travel"
	robot.current_state=PS3CharacterNPC.State.IDLE
	robot._motion_weight=0.
	robot._animate(0.,0.)
	camera.fov=42.
	await capture("kestrel_front",robot.position+Vector3(.05,1.48,-2.9),robot.position+Vector3(0,1.39,0))
	await capture("kestrel_side",robot.position+Vector3(1.5,1.45,-2.3),robot.position+Vector3(0,1.38,0))
	robot.current_state=PS3CharacterNPC.State.WALK
	robot._motion_weight=1.
	robot._phase=.25
	robot._animate(0.,1.45)
	await capture("kestrel_walking",robot.position+Vector3(.05,1.48,-2.9),robot.position+Vector3(0,1.39,0))
	if "--kestrel-only" in OS.get_cmdline_user_args():
		quit()
		return
	main.get_node("AnimatedWater").set_process(false)
	camera.fov=42.
	camera.position=Vector3(15,-.2,11)
	camera.look_at(Vector3(11.1,-2,7.45))
	var water=main.get_node("AnimatedWater")
	for frame:int in 30:
		for material:ShaderMaterial in water.materials:material.set_shader_parameter("water_time",frame*.05)
		for n:int in 3:await process_frame
		RenderingServer.force_draw(false)
		root.get_texture().get_image().save_png(OUT+"flow_%02d.png"%frame)
	quit()
