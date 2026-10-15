extends SceneTree
const OUT := "/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize() -> void: call_deferred("check")
func check() -> void:
	root.size=Vector2i(1280,900)
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	main.get_node("RenderOptimization").set_performance_mode(false,false)
	if OS.get_environment("CHECK_TAG")!="before":
		var tree_mesh: ArrayMesh=load("res://assets/olive_tree_render_lod.res")
		var leaf_surfaces:=0
		for i in tree_mesh.get_surface_count():
			if tree_mesh.surface_get_material(i).resource_name=="island_tree_01_leaves":
				leaf_surfaces+=1
				var surface:Dictionary=RenderingServer.mesh_get_surface(tree_mesh.get_rid(),i)
				assert(surface.get("lods",[]).is_empty(),"Leaf geometry must stay constant across distance")
		assert(leaf_surfaces>0)
		await physics_frame
		var exclude: Array[RID]=[]
		for body in main.find_children("*","StaticBody3D",true,false):
			if "Cliff_Terrain" not in String(body.get_path()):exclude.append(body.get_rid())
		var checked:=0
		for x in [2.2,3.,4.,5.,6.5]:
			for z in [10.8,11.2,11.8]:
				var query:=PhysicsRayQueryParameters3D.create(Vector3(x,10,z),Vector3(x,-2,z))
				query.exclude=exclude
				var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query)
				assert(not hit.is_empty())
				assert(hit.position.y<-.2,"Terrain covers pool paving at "+str(Vector2(x,z))+": "+str(hit))
				checked+=1
		print("POOL_CANOPY_VALIDATED ",checked," unobstructed concrete samples; fixed canopy")
		var tree_samples:=0
		for tree in main.get_node("RenderOptimization").trees:
			if String(tree.name) not in ["Olive_Cliff_Far_R","Coastal_Olive_Overlook"]:continue
			var bottom:=INF
			var points:=PackedVector3Array()
			for i in tree.mesh.get_surface_count():
				var arrays=tree.mesh.surface_get_arrays(i)
				points.append_array(arrays[Mesh.ARRAY_VERTEX])
			for point in points:bottom=minf(bottom,point.y)
			var worst:=-INF
			for point in points:
				if point.y>bottom+.08:continue
				var p:Vector3=tree.global_transform*point
				var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,30,p.z),Vector3(p.x,-5,p.z))
				query.exclude=exclude
				var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query)
				assert(not hit.is_empty(),"Unsupported tree root "+tree.name)
				worst=maxf(worst,p.y-hit.position.y)
				tree_samples+=1
			assert(worst<.02,"Floating root "+tree.name+": "+str(worst))
			print("TREE_ROOTS_VALIDATED ",tree.name," gap ",worst)
		assert(tree_samples>0)
		FileAccess.open(OUT+"pool_canopy_runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"fixed_leaf_geometry":true,"clear_paving_samples":checked,"tree_root_samples":tree_samples,"grass_instances":main.get_node("IslandGroundCover").instance_total},"  "))
	var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=70
	var tag:=OS.get_environment("CHECK_TAG")
	if tag.is_empty():tag="after"
	var views=[
		["pool_front",Vector3(3.5,1.7,9),Vector3(3.8,1.2,14)],
		["pool_east",Vector3(5.5,1.7,8.5),Vector3(11.5,1.0,8.5)],
		["pool_overview",Vector3(15,12,21),Vector3(2,0,8)],
		["canopy_near",Vector3(-12,4,12),Vector3(-18,5,3)],
		["canopy_far",Vector3(-8,4,19),Vector3(-18,5,3)]]
	for v in views:
		camera.global_position=v[1];camera.look_at(v[2],Vector3.UP)
		for i in range(35):await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OUT+tag+"_"+v[0]+".png")
		print("POOL_CAPTURE ",tag," ",v[0])
	quit()
