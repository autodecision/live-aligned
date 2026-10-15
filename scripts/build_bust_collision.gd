extends SceneTree
# Bake a compact solid collision hull from the current game sculpture.
# Rendering retains the original imported mesh and all marble textures.
func _initialize()->void:call_deferred("build")
func build()->void:
	var source=load("res://assets/mediterranean_temple.glb").instantiate()
	var bust:MeshInstance3D
	for mesh in source.find_children("*","MeshInstance3D",true,false):
		if String(mesh.name)=="Altar_Marble_Bust":bust=mesh;break
	assert(bust!=null)
	var shape:ConvexPolygonShape3D=bust.mesh.create_convex_shape(true,true)
	assert(shape!=null and shape.points.size()<256)
	assert(ResourceSaver.save(shape,"res://assets/bust_collision_proxy.tres")==OK)
	print("BUST_COLLISION_SAVED ",shape.points.size()," hull vertices")
	source.free();quit()
