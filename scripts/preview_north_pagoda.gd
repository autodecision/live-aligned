extends SceneTree
## Opens the actual walkthrough at the pagoda without changing the default spawn.
func _initialize()->void:call_deferred("run")
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main);current_scene=main
 await physics_frame
 var plan:Dictionary=main.get_node("NorthPagoda").plan;var p:Array=plan.path[-1];var player:CharacterBody3D=main.get_node("Player")
 player.global_position=Vector3(p[0],p[1]+.04,p[2]);player.velocity=Vector3.ZERO;player.rotation.y=plan.yaw;player.head.rotation.x=0.;player.spawn_point=player.global_position
