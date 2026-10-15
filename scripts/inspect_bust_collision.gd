extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 for shape in main.get_node("TempleMap").find_children("*","CollisionShape3D",true,false):
  if "Bust" in String(shape.get_path()):
   print("BUST_COLLIDER ",shape.get_path()," ",shape.shape," ",shape.global_transform)
   if shape.shape is ConcavePolygonShape3D:print("BUST_FACES ",shape.shape.get_faces().size()/3)
 quit()
