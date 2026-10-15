extends SceneTree
const OUT:="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize() -> void:call_deferred("run")
func measure(label:String)->Dictionary:
	var start:=Time.get_ticks_usec()
	while Time.get_ticks_usec()-start<700000:await process_frame
	var frames:=0;var physics:=0.;var primitives:=0.;var draws:=0.
	start=Time.get_ticks_usec()
	while Time.get_ticks_usec()-start<1800000:
		await process_frame;frames+=1
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.
		primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var row:={"label":label,"fps":float(frames)*1000000./float(Time.get_ticks_usec()-start),"physics_ms":physics/frames,"primitives":primitives/frames,"draws":draws/frames}
	print("BUST_PROFILE ",JSON.stringify(row));return row
func run()->void:
	root.size=Vector2i(1280,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	main.get_node("RenderOptimization").set_performance_mode(false,false)
	var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var bust:MeshInstance3D
	for mesh in main.get_node("TempleMap").find_children("*","MeshInstance3D",true,false):
		if "Altar_Marble_Bust" in mesh.name:bust=mesh;break
	assert(bust!=null)
	var b:=bust.mesh.get_aabb();var center:Vector3=bust.global_transform*(b.position+b.size*.65)
	print("BUST_INFO ",bust.get_path()," ",bust.global_position," ",b," material ",bust.get_active_material(0))
	var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
	var rows:=[]
	for distance in [3.,1.3,.65]:
		camera.global_position=center+Vector3(-distance,0.,0.);camera.look_at(center)
		rows.append(await measure("distance_"+str(distance)))
		await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"bust_before_"+str(distance)+".png")
	bust.hide();rows.append(await measure("close_without_bust"));bust.show()
	main.get_node("MediterraneanSun").shadow_enabled=false;rows.append(await measure("close_without_shadows"));main.get_node("MediterraneanSun").shadow_enabled=true
	var material:Material=bust.get_active_material(0)
	var simple:=StandardMaterial3D.new();simple.albedo_color=Color(.7,.7,.7);bust.material_override=simple
	rows.append(await measure("close_simple_material"));bust.material_override=null
	var foliage:=[]
	for mesh in main.get_node("TempleMap").find_children("*","MeshInstance3D",true,false):
		if "Olive" in mesh.name:foliage.append(mesh);mesh.hide()
	rows.append(await measure("close_without_trees"))
	for mesh in foliage:mesh.show()
	main.get_node("IslandGroundCover").hide();rows.append(await measure("close_without_grass"));main.get_node("IslandGroundCover").show()
	FileAccess.open(OUT+"bust_profile_before.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "))
	quit()
