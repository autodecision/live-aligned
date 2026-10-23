extends SceneTree
const OUT = "/home/allister/Projects/live-aligned-previews/south-garden-refinement-2026-10-15/"
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
	main.get_node("VisualLab").select_preset(0)
	main.get_node("RenderOptimization").set_performance_mode(false,false)
	main.get_node("DayNightCycle").running = false
	main.get_node("DayNightCycle").set_phase(0.25)
	await physics_frame
	
	camera = Camera3D.new()
	main.add_child(camera)
	camera.current = true
	camera.fov = 65

	# 1. Matching user Image 2: Looking south across pond
	await capture("verify_across_pond", Vector3(89.5, 5.8, 25.0), Vector3(95.0, 4.6, 35.5))
	
	# 2. Three-way intersection lantern closeup
	await capture("verify_three_way_lantern", Vector3(101.5, 5.8, 40.0), Vector3(104.41, 5.3, 42.8))
	
	# 3. Right sidewalk corner lantern closeup
	await capture("verify_corner_lantern", Vector3(89.5, 5.6, 38.5), Vector3(87.8, 5.2, 41.1))
	
	# 4. Matching user Image 1: Looking up from beach slope near Large_Rock_South_02
	await capture("verify_slope_without_hanging_trees", Vector3(82.0, 1.8, 42.0), Vector3(86.0, 3.8, 38.0))
	
	# 5. South lawn olive grove (showing Tree 02 and Tree 05 flat on plateau)
	await capture("verify_south_olive_grove", Vector3(99.0, 6.8, 38.5), Vector3(103.0, 4.8, 45.5))
	
	# 6. Night view showing all 5 glowing lanterns
	await capture("verify_night_lanterns", Vector3(98.0, 10.5, 24.0), Vector3(102.0, 4.6, 36.0), 0.75)
	
	print("ALL_CAPTURES_DONE")
	quit()
