extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
var main:Node3D
var player:CharacterBody3D
var plan:Dictionary
var samples:=0
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func local_point(x:float,y:float,z:float)->Vector3:
 var c:float=cos(plan.yaw);var s:float=sin(plan.yaw)
 return Vector3(92+c*x-s*y,5.5+z,-64-s*x-c*y)
func ray(p:Vector3,up:float=3.,down:float=12.,excluded:Array[RID]=[])->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*up,p-Vector3.UP*down);q.exclude=excluded if not excluded.is_empty() else [player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func walk_to(target:Vector3,max_steps:int=160)->bool:
 var steps:=0
 while Vector2(player.position.x-target.x,player.position.z-target.z).length()>.14 and steps<max_steps:
  var d:=Vector3(target.x-player.position.x,0,target.z-player.position.z).normalized();player.rotation.y=atan2(-d.x,-d.z)
  Input.action_press("move_forward");await physics_frame;player._physics_process(1./60.);steps+=1
 Input.action_release("move_forward");samples+=1
 if Vector2(player.position.x-target.x,player.position.z-target.z).length()>.28:
  print("PAGODA_BLOCKED target=",target," actual=",player.position)
  for j in player.get_slide_collision_count():print("BLOCKER ",player.get_slide_collision(j).get_collider().get_path())
  return false
 return true
func room(level:int)->void:
 var z:float=plan.floor_heights[level]-5.5
 for p in [Vector2(3.2,-3.25),Vector2(3.2,3.25),Vector2(-3.2,3.25),Vector2(-3.2,-3.25)]:
  assert(await walk_to(local_point(p.x,p.y,z)),"Blocked room perimeter")
  assert(absf(player.position.y-(5.5+z))<.25,"Room floor not supported")
 assert(await walk_to(local_point(3.35*cos(-PI/2+.22),3.35*sin(-PI/2+.22),z)))
func run()->void:
 Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main);player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.capture_mouse(true);player.walk_speed=5.0
 main.get_node("VisualLab").select_preset(0);main.get_node("RenderOptimization").set_performance_mode(true,false)
 main.get_node("DayNightCycle").running=false
 await physics_frame
 var pagoda=main.get_node("NorthPagoda");plan=pagoda.plan;assert(plan.bell_removed);assert(pagoda.lights.size()==8)
 # Exact collision must agree with the visible path over its full width.
 var structure:RID=pagoda.get_node("PagodaStructure").get_rid();var maximum_gap:= -100.
 for i in range(1,plan.path.size()-1):
  var p:=vec(plan.path[i]);var d:Vector3=(vec(plan.path[i+1])-vec(plan.path[i-1])).normalized();var n:=Vector3(-d.z,0,d.x).normalized()
  for cross in [-.92,0.,.92]:
   var q:Vector3=p+n*float(cross);var h:=ray(q,1.,4.);assert(not h.is_empty(),"Path has a hole")
   if absf(h.position.y-p.y)>=.12:
    print("PAVING_MISMATCH i=",i," cross=",cross," paving=",p," hit=",h.position," collider=",h.collider.get_path());quit(1);return
 # The roadside lantern is grounded and clear of the full paved width.
 var roadside:Node3D=main.get_node("IslandLanterns/Coastal_Lantern_North_05")
 for i in range(32):
  var a:=i*TAU/32.;var p:Vector3=roadside.position+Vector3(cos(a)*.245,0,sin(a)*.245)
  var hit:=ray(p,1.,3.,[player.get_rid(),roadside.get_node("PoleCollision").get_rid()]);assert(not hit.is_empty());assert(roadside.position.y-hit.position.y<.005,"Roadside lamp floats")
 for i in range(plan.path.size()-1):
  var a:=Vector2(plan.path[i][0],plan.path[i][2]);var b:=Vector2(plan.path[i+1][0],plan.path[i+1][2]);var d:=b-a;var p:=Vector2(roadside.position.x,roadside.position.z)
  var distance:=p.distance_to(a+d*clampf((p-a).dot(d)/maxf(d.length_squared(),.00001),0.,1.))
  assert(distance>float(plan.path_half_width)+.32,"Roadside lamp obstructs paving")
 # Terrain under the wider stone foundation.
 for i in range(40):
  var a:=i*TAU/40.;var p:=local_point(7.0*cos(a),7.0*sin(a),0.)
  var h:=ray(p,2.,5.,[player.get_rid(),structure]);assert(not h.is_empty());maximum_gap=maxf(maximum_gap,5.25-h.position.y)
 assert(maximum_gap<.01)
 var first:=vec(plan.path[0]);var h:=ray(first);player.position=Vector3(first.x,h.position.y+.04,first.z);player.velocity=Vector3.ZERO;await physics_frame
 for i in range(1,plan.path.size()):assert(await walk_to(vec(plan.path[i])),"Sidewalk is obstructed")
 assert(await walk_to(local_point(0,-3.6,1.)),"Cannot climb podium steps")
 var angle:float=-PI/2+.22
 assert(await walk_to(local_point(3.35*cos(angle),3.35*sin(angle),1.)))
 print("PAGODA_APPROACH_PASS")
 for flight in range(2):
  var route:Array=plan.spiral_routes[flight]
  assert(await walk_to(vec(route[0])),"Cannot enter spiral")
  for p in route:
   assert(await walk_to(vec(p)),"Spiral flight blocked")
   assert(absf(player.position.y-float(p[1]))<.42,"Stair height or head clearance failed")
  assert(await walk_to(local_point(3.35*cos(angle),3.35*sin(angle),plan.floor_heights[flight+1]-5.5)),"Cannot exit into upstairs room")
  await room(flight+1);print("PAGODA_UPSTAIRS_ROOM_PASS floor=",flight+2)
 # Descend both flights with the same physical player, without jumping.
 for flight in [1,0]:
  var route:Array=plan.spiral_routes[flight];assert(await walk_to(vec(route[-1])))
  for i in range(route.size()-1,-1,-1):
   assert(await walk_to(vec(route[i])),"Cannot descend spiral")
   assert(absf(player.position.y-float(route[i][1]))<.45,"Spiral descent loses support")
  if flight==1:assert(await walk_to(local_point(3.35*cos(angle),3.35*sin(angle),4.4+1.)))
 assert(await walk_to(local_point(3.35*cos(angle),3.35*sin(angle),1.)))
 assert(await walk_to(local_point(0,-3.6,1.)))
 assert(await walk_to(vec(plan.entry)),"Cannot leave pagoda")
 # Every hanger terminates in a real ceiling surface.
 var mounts:=0
 for light in pagoda.lights:
  var from:Vector3=light.position+Vector3.UP*.41;var q:=PhysicsRayQueryParameters3D.create(from,from+Vector3.UP*2.);q.exclude=[player.get_rid()]
  var ceiling:=main.get_world_3d().direct_space_state.intersect_ray(q);assert(not ceiling.is_empty(),"Lantern has no ceiling attachment");mounts+=1
 main.get_node("DayNightCycle").set_phase(.75)
 for light in pagoda.lights:assert(light.light_energy>1. and not light.shadow_enabled)
 assert(main.get_node("AnimatedWater").materials.size()==13);assert(main.get_node("RenderOptimization").tree_count==91)
 var report:={"bell_removed":true,"floors_accessible":3,"spiral_flights":2,"stairs_up_and_down_without_jumping":true,"room_perimeters_walked":2,"movement_samples":samples,"stair_clear_width_m":plan.stair_clear_width,"floor_separation_m":4.4,"nominal_stair_headroom_m":plan.stair_headroom,"paving_width_m":plan.path_half_width*2,"full_width_paving_collision":true,"foundation_maximum_gap_m":maximum_gap,"ceiling_mounted_lanterns":mounts,"water_surfaces_preserved":13,"trees_preserved":91,"roadside_lamp_grounded_and_clear":true}
 FileAccess.open(OUT+"pagoda_walkable_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 FileAccess.open(OUT+"north_pagoda_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("PAGODA_WALKABLE_TEST_PASS ",JSON.stringify(report));quit()
