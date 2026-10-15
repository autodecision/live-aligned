extends SceneTree
const OUT := "/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize() -> void: call_deferred("benchmark")
func measure(label: String) -> Dictionary:
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec()-t0<1200000: await process_frame
	var timings: Array[float]=[]
	var cpu := 0.0
	var physics := 0.0
	var draws := 0.0
	var primitives := 0.0
	t0=Time.get_ticks_usec()
	var previous:=t0
	while Time.get_ticks_usec()-t0<2500000:
		await process_frame
		var now := Time.get_ticks_usec()
		timings.append(float(now-previous)/1000.0);previous=now
		cpu+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
		physics+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
		draws+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var n:=timings.size()
	timings.sort()
	var row={"view":label,"fps":float(n)*1000000.0/float(previous-t0),"median_ms":timings[n/2],"p95_ms":timings[int(n*.95)],"cpu_ms":cpu/n,"physics_ms":physics/n,"draw_calls":draws/n,"primitives":primitives/n}
	print("BENCH ",JSON.stringify(row))
	return row
func benchmark() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,900)
	var tag:=OS.get_environment("BENCH_TAG")
	if tag.is_empty():tag="balanced"
	# Keep the measured pre-optimization baseline immutable.
	if tag=="baseline":
		push_error("Baseline is archived; choose another BENCH_TAG for the current project.")
		quit(2)
		return
	var path: String = "res://scenes/main.tscn"
	var main=load(path).instantiate();root.add_child(main)
	if main.has_node("RenderOptimization"):
		main.get_node("RenderOptimization").set_performance_mode(tag.ends_with("performance"),false)
	var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
	var views=[
		["meadow",Vector3(-12,4,12),Vector3(-18,2,3)],
		["temple",Vector3(-3.5,7,17),Vector3(-3.5,7.5,0)],
		["laboratory",Vector3(-4.15,7.1,-7.35),Vector3(-3.02,5.65,-10.9)],
		["water",Vector3(18,1,17),Vector3(11,-3,7.5)]]
	var rows:=[]
	for v in views:
		camera.global_position=v[1];camera.look_at(v[2],Vector3.UP)
		rows.append(await measure(v[0]))
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+"fps_"+tag+"_"+v[0]+".png")
	if tag=="baseline":
		camera.global_position=views[0][1];camera.look_at(views[0][2],Vector3.UP)
		var grass=main.get_node("IslandGroundCover")
		grass.hide();rows.append(await measure("meadow_no_grass"));grass.show()
		var trees:=[];var inventory:=[]
		for mesh in main.get_node("TempleMap").find_children("*","MeshInstance3D",true,false):
			if "Olive" in mesh.name or "Tree" in mesh.name or "tree" in mesh.name:
				trees.append(mesh);mesh.hide()
		rows.append(await measure("meadow_no_trees"))
		for tree in trees:tree.show()
		main.get_node("MediterraneanSun").shadow_enabled=false
		rows.append(await measure("meadow_no_sun_shadows"))
		FileAccess.open(OUT+"fps_mesh_inventory.json",FileAccess.WRITE).store_string(JSON.stringify(inventory,"  "))
	FileAccess.open(OUT+"fps_"+tag+".json",FileAccess.WRITE).store_string(JSON.stringify({"resolution":[1280,900],"vsync":false,"views":rows},"  "))
	quit()
