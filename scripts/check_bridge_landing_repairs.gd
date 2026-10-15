extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
var main:Node3D
var player:CharacterBody3D
var camera:Camera3D
var clock:Node3D
var excluded:Array[RID]=[]
func _initialize()->void:call_deferred("run")
func vec(a:Array)->Vector3:return Vector3(a[0],a[1],a[2])
func ray(p:Vector3,up:float=1.,down:float=3.,exclude:Array[RID]=[])->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*up,p-Vector3.UP*down);q.exclude=exclude if not exclude.is_empty() else [player.get_rid()]
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func capture(label:String,point:Vector3,target:Vector3,phase:float=.25)->void:
 camera.position=point;camera.look_at(target);clock.set_phase(phase)
 var start:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<1100:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"landing_repair_"+label+".png")
func run()->void:
 if DisplayServer.get_name()=="headless":Engine.physics_ticks_per_second=240;Engine.time_scale=4.
 root.size=Vector2i(1280,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide();player.capture_mouse(true)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=75
 await physics_frame
 var plan:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_bridges.json"))
 excluded=[player.get_rid()]
 for body in main.get_node("IslandBridges").find_children("*","StaticBody3D",true,false):excluded.append(body.get_rid())
 for body in main.get_node("IslandLanterns").find_children("*","StaticBody3D",true,false):excluded.append(body.get_rid())
 var support:=[];var walks:=[]
 for bridge in plan.bridges:
  var a:=vec(bridge.start);var b:=vec(bridge.end);var d:=Vector3(b.x-a.x,0,b.z-a.z).normalized();var side:=Vector3(-d.z,0,d.x)
  # Check actual terrain underneath all five lanes at the threshold, excluding
  # the deck itself so a visually unsupported edge cannot pass this test.
  for s in [-.75,0.,.75]:
   for lane in [-2.15,-1.2,0.,1.2,2.15]:
    var p:Vector3=b+d*s+side*lane;var h:=ray(p,1.,4.,excluded)
    assert(not h.is_empty(),"Missing bank support "+bridge.name+" "+str(lane))
    assert(p.y-h.position.y<.24,"Unsupported landing edge "+bridge.name+" "+str(p.y-h.position.y))
    support.append({"bridge":bridge.name,"distance":s,"lane":lane,"gap":p.y-h.position.y})
  # Walk three lanes, both directions, through the entire island/deck seam.
  for lane in [-1.3,0.,1.3]:
   for reverse in [false,true]:
    var s0:float=3.5 if reverse else -5.5;var s1:float=-4. if reverse else 3.5;var dir:Vector3=-d if reverse else d
    var entry:Vector3=b+d*s0+side*lane;var h:=ray(entry,5.,12.);assert(not h.is_empty())
    player.position=Vector3(entry.x,h.position.y+.07,entry.z);player.velocity=Vector3.ZERO
    await physics_frame;Input.action_press("move_forward")
    var steps:=0;var progress:float=s0;var stagnant:=0;var previous:float=s0
    while (progress>s1 if reverse else progress<s1) and steps<400:
     # Correct normal sideways deflection on the sloped approach.
     var target:Vector3=b+d*(s1+(-1. if reverse else 1.))+side*lane
     var toward:Vector3=Vector3(target.x-player.position.x,0,target.z-player.position.z).normalized();player.rotation.y=atan2(-toward.x,-toward.z)
     await physics_frame;player._physics_process(1./60.);steps+=1
     progress=Vector3(player.position.x-b.x,0,player.position.z-b.z).dot(d)
     if absf(progress-previous)<.001:stagnant+=1
     else:stagnant=0
     previous=progress
     if stagnant>60:break
    Input.action_release("move_forward")
    print("LANDING_WALK ",bridge.name," lane=",lane," reverse=",reverse," progress=",progress," pos=",player.position)
    assert((progress<=s1 if reverse else progress>=s1),"Blocked full-width approach "+bridge.name+" lane="+str(lane)+" reverse="+str(reverse))
    walks.append({"bridge":bridge.name,"lane":lane,"reverse":reverse,"steps":steps,"progress":progress})
 var repairs=main.get_node("IslandSiteRepairs");assert(repairs.repaired_rocks.size()==11 and repairs.moved_trees.size()==2)
 for rock in repairs.repaired_rocks:
  var m:StandardMaterial3D=rock.material_override
  assert(m.albedo_texture!=null and m.normal_enabled and m.roughness>.85)
 var tree_exclude:Array[RID]=[player.get_rid()]
 for body in main.get_node("TempleMap").find_children("*","StaticBody3D",true,false):
  if "Olive" in String(body.get_path()):tree_exclude.append(body.get_rid())
 var tree_checks:=[]
 for tree in repairs.moved_trees:
  var vertices:=PackedVector3Array()
  for i in tree.mesh.get_surface_count():vertices.append_array(tree.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
  var bottom:float=100000.
  for p in vertices:bottom=minf(bottom,(tree.global_transform*p).y)
  var roots:=[]
  for p in vertices:
   var world:Vector3=tree.global_transform*p
   if world.y<bottom+.16:roots.append(world)
  var max_gap:float=-1000.;var count:=0
  for i in range(0,roots.size(),maxi(1,int(roots.size()/64))):
   var p:Vector3=roots[i];var h:=ray(p,.5,2.,tree_exclude);assert(not h.is_empty());max_gap=maxf(max_gap,p.y-h.position.y);count+=1
  assert(max_gap<.06,"Floating relocated tree "+tree.name)
  tree_checks.append({"name":tree.name,"samples":count,"maximum_gap":max_gap})
 var sun:DirectionalLight3D=main.get_node("MediterraneanSun")
 assert(sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and is_equal_approx(sun.directional_shadow_split_1,.38))
 for mesh in main.get_node("IslandBridges").find_children("*","MeshInstance3D",true,false):
  for i in mesh.mesh.get_surface_count():assert(mesh.mesh.surface_get_material(i).texture_filter==BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
 main.get_node("RenderOptimization").set_performance_mode(true,false);assert(sun.directional_shadow_mode==DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and is_equal_approx(sun.directional_shadow_split_1,.38));main.get_node("RenderOptimization").set_performance_mode(false,false)
 var result:={"full_width_terrain_samples":support,"three_lane_two_way_landing_walks":walks,"textured_rough_rocks":11,"relocated_grounded_trees":tree_checks,"balanced_rebalanced_two_cascades":true,"performance_rebalanced_two_cascades":true,"anisotropic_bridge_materials":true}
 FileAccess.open(OUT+"bridge_landing_repair_validation.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
 if DisplayServer.get_name()=="headless":print("LANDING_REPAIR_TEST_PASS");quit();return
 await capture_views(plan)
 print("LANDING_REPAIR_CAPTURE_PASS");quit()
func capture_views(plan:Variant)->void:
 player.position=Vector3(-3.5,1.,12)
 var north=plan.bridges[0];var end:=vec(north.end);var d:=Vector3(north.direction[0],0,-north.direction[1]);var side:=Vector3(-d.z,0,d.x)
 await capture("north_arrival",end-d*4.+Vector3.UP*1.7,end+d*4.+Vector3.UP*1.1)
 await capture("north_landing_side",Vector3(56,10,-33),Vector3(59,4.8,-40))
 await capture("south_connection",Vector3(84,8.2,16),Vector3(78.5,5.3,21.3))
 await capture("south_bank_side",Vector3(75,10,32),Vector3(81,4.9,21))
 await capture("north_south_connection",Vector3(92,8.5,21),Vector3(86.4,4.0,17))
 await capture("weathered_rocks",Vector3(62,10,-51),Vector3(53.3,9,-58))
 await capture("midday_deck",Vector3(50,7.05,19.7),Vector3(0,3.7,15.7))
 await capture("north_night",end-d*4.+Vector3.UP*1.7,end+d*4.+Vector3.UP*1.1,.75)
