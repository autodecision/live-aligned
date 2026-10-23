extends SceneTree
const OUT = "/home/allister/Projects/live-aligned-previews/site-finish-2026-10-18/after/"
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
	root.always_on_top = true
	root.grab_focus()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	main = load("res://scenes/main.tscn").instantiate()
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

	await capture("island_overview",Vector3(100,31,48),Vector3(99,4,32))
	await capture("east_lantern",Vector3(117.5,6.2,28.5),Vector3(116,5.4,25.2))
	await capture("west_lantern",Vector3(90.5,6.2,37.4),Vector3(87.8,5.2,41.1))
	await capture("bridge_join",Vector3(84,6.7,24),Vector3(83,4.7,18.5))
	await capture("pool_objects",Vector3(1.3,1.5,9.1),Vector3(.2,.5,8))
	await capture("outfall",Vector3(5.9,2.5,6.1),Vector3(7.2,.2,7.5))
	await capture("outfall_wide",Vector3(13,2,13),Vector3(8,-.3,7.5))
	quit()
