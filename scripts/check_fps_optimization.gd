extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var main:Node3D=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player:CharacterBody3D=main.get_node("Player");player.set_physics_process(false)
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true
 var ocean=main.get_node("OceanGround")
 var floor_mesh:MeshInstance3D=ocean.find_child("Ocean_Seabed",true,false)
 var shoals:MeshInstance3D=ocean.find_child("Ocean_Seabed_Shoals",true,false)
 assert(ocean.submerged_visuals.size()>9)
 assert(floor_mesh.mesh.get_faces().size()/3==170086)
 assert(shoals.mesh.get_faces().size()/3==1594)
 assert(floor_mesh.mesh.get_aabb().end.y< -5.56)
 var collider:CollisionShape3D
 for shape:CollisionShape3D in floor_mesh.find_children("*","CollisionShape3D",true,false):collider=shape
 assert(collider!=null and not collider.disabled)
 assert((collider.shape as ConcavePolygonShape3D).get_faces().size()/3==171680)
 for height:float in [4.0,-4.3,-4.41,-5.1,-7.0,4.0]:
  camera.position=Vector3(24,height,-52);ocean._process(0.0)
  for mesh:MeshInstance3D in ocean.submerged_visuals:assert(mesh.visible==(height< -4.4))
  assert(shoals.visible)
  assert(not collider.disabled and floor_mesh.get_node("GroundCollision").collision_layer==1)
 var render=main.get_node("RenderOptimization")
 for performance:bool in [false,true,false]:
  render.set_performance_mode(performance,false)
  assert(root.msaa_3d==(Viewport.MSAA_2X if performance else Viewport.MSAA_4X))
  assert(is_equal_approx(root.scaling_3d_scale,.75 if performance else 1.0))
 assert(render.tree_count==91 and main.get_node("IslandGroundCover").instance_total==81325)
 assert(main.get_node("AnimatedWater").materials.size()==13)
 for tree:MeshInstance3D in render.trees:
  assert(tree.mesh.resource_path.ends_with("olive_tree_render_lod_compact.res"))
  assert(not (tree.mesh.get("_surfaces")[1] as Dictionary).has("lods"))
 print("FPS_OPTIMIZATION_PASS 91 unchanged canopies; 81325 plants; both graphics modes; submerged rendering and full floor collision")
 quit()
