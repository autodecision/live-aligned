extends SceneTree
const OUT = "/home/allister/Projects/live-aligned-previews/lab-props-2026-10-18/after/"
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
	var map:Node3D=main.get_node("TempleMap")
	var hidden:int=0
	for mesh:MeshInstance3D in map.find_children("*","MeshInstance3D",true,false):
		var label:=String(mesh.name)
		if label.begins_with("Lab_Microscope_") or label.begins_with("Lab_Reagent_Bottle") or label.begins_with("Lab_Bottle_Cap") or label.begins_with("Lab_Bottle_Label") or label=="Lab_Glass_Slide":
			assert(not mesh.visible,"Original lab prop is still visible")
			hidden+=1
	assert(hidden==53)
	var detail:Node3D=map.get_node("LabPropDetail")
	assert(detail.find_children("*","MeshInstance3D",true,false).size()==3)
	var glass:MeshInstance3D=detail.get_node("LabDetail_Glass")
	for surface:int in glass.mesh.get_surface_count():
		var material:StandardMaterial3D=glass.mesh.surface_get_material(surface)
		# glTF BLEND imports with an alpha depth prepass in this Godot version.
		assert(material.transparency in [BaseMaterial3D.TRANSPARENCY_ALPHA,BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS])
		assert(material.albedo_color.a<.4)
		print("LAB_GLASS ",material.resource_name," transparency=",material.transparency," alpha=",material.albedo_color.a)
	var original:Node3D=load("res://assets/mediterranean_temple.glb").instantiate()
	var actual_shapes:=map.get_node("Lab_Microscope_Base").find_children("*","CollisionShape3D",true,false)
	var before_shapes:=original.get_node("Lab_Microscope_Base").find_children("*","CollisionShape3D",true,false)
	assert(actual_shapes.size()==before_shapes.size() and actual_shapes.size()==1)
	assert(actual_shapes[0].shape==before_shapes[0].shape)
	original.free()
	print("LAB_PROPS_PASS: 53 originals hidden, 3 detail meshes, transparent glass, preserved microscope collision")
	
	camera = Camera3D.new()
	main.add_child(camera)
	camera.current = true
	camera.fov = 65

	await capture("microscope",Vector3(-2.35,6.13,-3.92),Vector3(-1.60,5.91,-3.37))
	await capture("bottles",Vector3(-2.80,6.81,-4.06),Vector3(-1.30,6.73,-4.06))
	await capture("bench",Vector3(-3.05,6.55,-4.55),Vector3(-1.35,6.20,-4.02))
	quit()
