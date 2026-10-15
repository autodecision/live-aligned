extends SceneTree
const OUT:="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/grass_motion/"
func _initialize()->void:call_deferred("run")
func run()->void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.size=Vector2i(1280,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	main.get_node("RenderOptimization").set_performance_mode(false,false)
	var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	var water=main.get_node("AnimatedWater");water.set_process(false);water.set_water_time(0.)
	var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65.;camera.global_position=Vector3(-12,4,12);camera.look_at(Vector3(-18,2,3))
	var start:=camera.transform
	var terrain:=[]
	for mesh in main.get_node("TempleMap").find_children("*","MeshInstance3D",true,false):
		if String(mesh.name).begins_with("Cliff_Terrain") or String(mesh.name).begins_with("Distant_Islands"):terrain.append(mesh)
	var mats:=[]
	for patch in main.get_node("IslandGroundCover").get_children():
		if patch is MultiMeshInstance3D:
			for i in patch.multimesh.mesh.get_surface_count():
				var mat=patch.multimesh.mesh.surface_get_material(i)
				if not mats.has(mat):mats.append(mat)
	var rows:=[]
	var modes:Array=["before","msaa2","msaa4","no_shadows","stable_terrain","filtered2"]
	if OS.get_environment("GRASS_MOTION_MODES")!="":modes=Array(OS.get_environment("GRASS_MOTION_MODES").split(","))
	for mode in modes:
		main.get_node("WorldEnvironment").environment.glow_enabled=not mode.ends_with("noglow")
		root.use_taa=mode in ["taa","taa_performance","taa_noglow","taa_performance_noglow","taa_fsr1_noglow"]
		root.scaling_3d_mode=Viewport.SCALING_3D_MODE_FSR2 if mode=="fsr2" else Viewport.SCALING_3D_MODE_FSR if mode=="taa_fsr1_noglow" else Viewport.SCALING_3D_MODE_BILINEAR
		root.scaling_3d_scale=.75 if mode in ["fsr2","taa_performance","taa_performance_noglow","taa_fsr1_noglow","perf_before","perf_msaa2"] else 1.
		root.msaa_3d=Viewport.MSAA_4X if mode in ["msaa4","balanced_final"] else Viewport.MSAA_2X if mode in ["msaa2","filtered2","perf_msaa2"] else Viewport.MSAA_DISABLED
		main.get_node("MediterraneanSun").shadow_enabled=mode!="no_shadows"
		for mesh in terrain:mesh.lod_bias=100000. if mode in ["stable_terrain","filtered2"] else 1.
		for mat in mats:
			mat.alpha_antialiasing_mode=BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE if mode in ["filtered2","perf_msaa2","balanced_final"] and mat.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else BaseMaterial3D.ALPHA_ANTIALIASING_OFF
			mat.metallic_specular=.15 if mode=="filtered2" else .5
		camera.transform=start
		var t:=Time.get_ticks_usec()
		while Time.get_ticks_usec()-t<800000:await process_frame
		var frames:=0;t=Time.get_ticks_usec()
		while Time.get_ticks_usec()-t<1500000:await process_frame;frames+=1
		var fps:=float(frames)*1000000./float(Time.get_ticks_usec()-t)
		var poses:=[]
		for i in range(12):
			camera.transform=start;camera.rotate_y(float(i)*.0009)
			await process_frame;await RenderingServer.frame_post_draw
			var picture:=root.get_texture().get_image();picture.save_png(OUT+mode+"_%02d.png"%i)
			var b:=camera.global_basis;poses.append([[b.x.x,b.y.x,b.z.x],[b.x.y,b.y.y,b.z.y],[b.x.z,b.y.z,b.z.z]])
		var row:={"mode":mode,"fps":fps,"basis_rows":poses,"fov":65.,"resolution":[1280,900]};rows.append(row)
		print("GRASS_MOTION ",mode," ",fps)
	FileAccess.open(OUT+("final_mode_comparison.json" if modes[0]=="perf_before" else "temporal_optimized_comparison.json" if "noglow" in modes[0] else "sampling_comparison.json"),FileAccess.WRITE).store_string(JSON.stringify(rows,"  "));quit()
