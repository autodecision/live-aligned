extends SceneTree
const OUT:="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func run()->void:
	var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
	var player=main.get_node("Player");player.set_physics_process(false);player.capture_mouse(true);player.rotation.y=-PI/2.
	var bust:MeshInstance3D
	for mesh in main.get_node("TempleMap").find_children("*","MeshInstance3D",true,false):
		if String(mesh.name)=="Altar_Marble_Bust":bust=mesh;break
	assert(bust!=null)
	var collision:CollisionShape3D=bust.find_children("*","CollisionShape3D",true,false)[0]
	assert(collision.shape is ConvexPolygonShape3D)
	var imported=load("res://assets/mediterranean_temple.glb").instantiate()
	var original:MeshInstance3D=imported.get_node("Altar_Marble_Bust")
	assert(bust.mesh==original.mesh and bust.material_override==null)
	var box:=bust.mesh.get_aabb();var center:Vector3=bust.global_transform*(box.position+box.size*.5)
	await physics_frame
	var query:=PhysicsRayQueryParameters3D.create(center+Vector3(-2,0,0),center)
	var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty() and "Altar_Marble_Bust" in String(hit.collider.get_path()),"Sculpture must remain solid")
	Input.action_press("move_forward")
	var results:=[]
	for height in [5.12,5.7]:
		player.global_position=Vector3(3.,height,-7.3);player.velocity=Vector3.ZERO
		var timings:=[]
		for i in range(60):
			await physics_frame
			var t:=Time.get_ticks_usec();player._physics_process(1./60.);timings.append(Time.get_ticks_usec()-t)
		var total:=0
		for t in timings:total+=t
		timings.sort()
		var mean:=float(total)/timings.size()/1000.
		assert(mean<10.,"Bust contact regression: "+str(mean)+" ms per movement update")
		results.append({"height":height,"mean_ms":mean,"p95_ms":float(timings[int(timings.size()*.95)])/1000.,"max_ms":float(timings[-1])/1000.})
	Input.action_release("move_forward")
	var report:={"visual_mesh_and_material_preserved":true,"solid_ray_contact":true,"hull_vertices":collision.shape.points.size(),"contact_results":results}
	FileAccess.open(OUT+"bust_contact_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("BUST_CONTACT_PASS ",JSON.stringify(report));imported.free();quit()
