extends SceneTree
const OUT = "/home/allister/Projects/live-aligned-previews/square-garden-paths-2026-10-18/"
var main:Node3D
var player:CharacterBody3D
var garden:Node3D
var camera:Camera3D
var walks:int = 0
var samples:int = 0
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func ray(p:Vector3)->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*2.0,p-Vector3.UP*8.0)
 q.exclude = [player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func walk(points:Array,reverse:bool=false)->bool:
 var order:=range(points.size()-1,-1,-1) if reverse else range(points.size())
 var first:bool = true
 for i:int in order:
  var p:=vec(points[i])
  if first:
   var hit:=ray(p)
   if hit.is_empty():push_error("Missing garden ground "+str(p));return false
   player.position = Vector3(p.x,hit.position.y+.05,p.z)
   player.velocity = Vector3.ZERO
   await physics_frame
   first = false
  var steps:int = 0
  while Vector2(p.x-player.position.x,p.z-player.position.z).length()>.18 and steps<420:
   var toward:=Vector3(p.x-player.position.x,0,p.z-player.position.z).normalized()
   player.rotation.y = atan2(-toward.x,-toward.z)
   Input.action_press("move_forward")
   await physics_frame
   player._physics_process(1.0/60.0)
   steps += 1
  Input.action_release("move_forward")
  if steps>=420:
   for j:int in player.get_slide_collision_count():print("GARDEN_BLOCKER ",player.get_slide_collision(j).get_collider().get_path())
   push_error("Garden route blocked at "+str(p)+" player "+str(player.position));return false
  if player.position.y < p.y-.35:
   push_error("Garden fall at "+str(p)+" player "+str(player.position));return false
 walks += 1
 return true
func capture(label:String,point:Vector3,target:Vector3,phase:float=.25)->void:
 camera.position = point
 camera.look_at(target)
 main.get_node("DayNightCycle").set_phase(phase)
 var start:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<1200:await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUT+label+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 var headless:bool = DisplayServer.get_name()=="headless"
 var views_only:bool = "--views-only" in OS.get_cmdline_user_args()
 if headless:Engine.physics_ticks_per_second=240;Engine.time_scale=4.0
 root.size = Vector2i(1440,900)
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 player = main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.get_node("CanvasLayer").hide()
 player.walk_speed = 5.0
 player.capture_mouse(true)
 main.get_node("VisualLab").select_preset(0)
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 main.get_node("DayNightCycle").running = false
 main.get_node("DayNightCycle").set_phase(.25)
 garden = main.get_node("SouthGarden")
 await physics_frame
 if not views_only:
  for route:Array in garden.plan.routes:
   for i:int in range(route.size()-1):
    var a:=vec(route[i]);var b:=vec(route[i+1]);var side:Vector3 = Vector3(-(b-a).z,0,(b-a).x).normalized()
    for t:float in [.0,.25,.5,.75,1.0]:
     for lane:float in [-.45,0.0,.45]:
      var p:Vector3 = a.lerp(b,t)+side*lane
      var hit:=ray(p)
      assert(not hit.is_empty(),"Missing route support")
      assert(absf(hit.position.y-p.y)<.25,"Garden grade mismatch "+str(p)+" "+str(hit.position))
      samples += 1
   for reverse:bool in [false,true]:
    if not await walk(route,reverse):quit(1);return
  if garden.plan.has("square_sidewalk"):
   for offset:float in [-.45,.45]:
    var lane:Array = []
    for p:Vector2 in [Vector2(88+offset,26.5+offset),Vector2(118.5-offset,26.5+offset),Vector2(118.5-offset,41.5-offset),Vector2(88+offset,41.5-offset),Vector2(88+offset,26.5+offset)]:
     lane.append([p.x,4.735,p.y])
    for reverse:bool in [false,true]:
     if not await walk(lane,reverse):quit(1);return
  # Across the sand, onto the deck, and out of the excavated pond on each bank.
  for route:Array in [
   [[105.47,4.72,29.5],[111.47,4.72,29.5],[115.57,4.72,34.0],[115.57,4.72,38.5],[105.47,4.72,40.3]],
   [[88.1,4.72,33.3],[90.8,4.73,33.3],[90.8,4.73,34.1],[88.1,4.72,34.1]],
   [[96.0,3.3,34.0],[103.0,4.65,34.0]],
   [[96.0,3.3,34.0],[91.0,4.65,30.6],[92.0,4.72,28.5]],
   [[96.0,3.3,34.0],[96.0,4.65,28.5]],
   [[96.0,3.3,34.0],[96.0,4.65,41.0]]]:
   if not await walk(route):quit(1);return
  garden.set_process(false)
  var start_positions:Array[Vector3] = []
  var travelled:Array[float] = []
  var radius_min:Array[float] = []
  var radius_max:Array[float] = []
  var speed_min:Array[float] = []
  var speed_max:Array[float] = []
  var mesh_ids:Dictionary = {}
  for state:Dictionary in garden.fish:
   state.turns = 0
   state.pauses = 0
   start_positions.append(state.node.position)
   travelled.append(0.0)
   radius_min.append(1.0)
   radius_max.append(0.0)
   speed_min.append(1.0)
   speed_max.append(0.0)
   mesh_ids[state.node.mesh.get_instance_id()] = true
  var containment:int = 0
  for i:int in range(3600):
   var previous:Array[Vector3] = []
   for state:Dictionary in garden.fish:previous.append(state.node.position)
   garden.advance(1.0/60.0)
   for j:int in garden.fish.size():
    var state:Dictionary = garden.fish[j]
    var p:Vector3 = state.node.position
    travelled[j] += p.distance_to(previous[j])
    var r:float = Vector2((p.x-96.0)/5.6,(p.z-34.0)/4.0).length()
    radius_min[j] = minf(radius_min[j],r)
    radius_max[j] = maxf(radius_max[j],r)
    speed_min[j] = minf(speed_min[j],state.velocity.length())
    speed_max[j] = maxf(speed_max[j],state.velocity.length())
    assert(r<.75 and p.y<4.24 and p.y>3.65,"Koi left the safe water volume")
    var forward:Vector3 = state.node.basis.x.normalized()
    var direction:Vector3 = (garden._fish_point(state,.12)-p).normalized()
    if state.velocity.length()>.015:
     assert(forward.dot(direction)>.94,"Koi swimming backwards speed="+str(state.velocity.length())+" alignment="+str(forward.dot(direction)))
    containment += 1
  var course_changes:int = 0
  var glides:int = 0
  for j:int in travelled.size():
   assert(travelled[j]>4.0 and travelled[j]<38.0,"Unnatural koi travel distance "+str(travelled[j]))
   assert(radius_max[j]-radius_min[j]>.12,"Koi still following a fixed circle")
   assert(speed_max[j]-speed_min[j]>.09,"Koi speed is too uniform")
   course_changes += int(garden.fish[j].turns)
   glides += int(garden.fish[j].pauses)
  assert(course_changes>70 and glides>5,"Missing independent destination changes and glides")
  garden.set_process(true)
  assert(mesh_ids.size()==3 and garden.fish.size()==14)
  main.get_node("DayNightCycle").set_phase(.75)
  for light:OmniLight3D in garden.lights:assert(light.visible and light.light_energy>1.0 and not light.shadow_enabled)
  main.get_node("DayNightCycle").set_phase(.25)
  for light:OmniLight3D in garden.lights:assert(not light.visible)
  assert(main.get_node("RenderOptimization").tree_count==91)
  assert(main.get_node("AnimatedWater").materials.size()==13)
  var report:Dictionary = {"supported_route_samples":samples,"complete_walks":walks,"pond_exits":4,"koi":14,"shared_koi_meshes":mesh_ids.size(),"fish_checks_over_60_seconds":containment,"independent_course_changes":course_changes,"slow_glides":glides,"night_lanterns":garden.lights.size(),"preserved_trees":91,"preserved_existing_water_surfaces":13}
  FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
  print("SOUTH_GARDEN_CHECK_PASS ",JSON.stringify(report))
 if not headless:
  root.always_on_top = true
  root.grab_focus()
  Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
  player.position = Vector3(-3.5,1.2,12.0)
  camera = Camera3D.new()
  main.add_child(camera)
  camera.current = true
  camera.fov = 65
  await capture("square_arrival",Vector3(84.5,8.5,21.8),Vector3(100,4.7,34))
  await capture("square_far_end",Vector3(83.5,9.5,47.5),Vector3(101,4.7,34))
  await capture("square_plan",Vector3(102,39,34.05),Vector3(102,4.7,34))
  await capture("overview",Vector3(123,22,53),Vector3(101,4.5,33))
  await capture("pond",Vector3(98,7.4,38.6),Vector3(96,4.0,33.3))
  await capture("from_deck",Vector3(89.3,6.5,33.5),Vector3(98.3,4.5,34.0))
  await capture("zen_garden",Vector3(116.8,7.6,41.0),Vector3(111.5,4.7,34.0))
  await capture("path_join",Vector3(84.0,6.9,23.0),Vector3(89.2,4.8,28.0))
  await capture("deck_edge",Vector3(87.9,6.5,35.9),Vector3(91.1,4.7,33.1))
  await capture("stone_detail",Vector3(111.6,6.3,39.2),Vector3(113.5,5.2,36.3))
  await capture("bridge_arrival",Vector3(82,7.2,21.5),Vector3(96,4.7,32))
  await capture("night",Vector3(106,12.5,46.5),Vector3(101,4.6,34),.75)
  if "--capture-swim" in OS.get_cmdline_user_args():
   await capture("swim_still",Vector3(98,8.6,38.6),Vector3(96,4.0,33.3))
   DirAccess.make_dir_recursive_absolute(OUT+"swim_frames")
   garden.set_process(false)
   for frame:int in range(144):
    garden.advance(1.0/12.0)
    await process_frame
    RenderingServer.force_draw(false)
    root.get_texture().get_image().save_png(OUT+"swim_frames/%03d.png"%frame)
 quit()
