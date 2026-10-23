extends "res://scripts/check_south_garden.gd"
const OCEAN_OUT="/home/allister/Projects/live-aligned-previews/natural-ocean-2026-10-19/"
var floor_exclude:Array[RID]=[]
func seabed_ray(p:Vector3)->Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(p.x,-5.3,p.z),Vector3(p.x,-20,p.z))
 query.exclude=floor_exclude
 return main.get_world_3d().direct_space_state.intersect_ray(query)
func require(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1)
 return ok
func ocean_view(label:String,p:Vector3,target:Vector3)->void:
 camera.position=p;camera.look_at(target)
 for i:int in range(35):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OCEAN_OUT+label+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute(OCEAN_OUT)
 var headless:bool=DisplayServer.get_name()=="headless"
 if headless:Engine.physics_ticks_per_second=240;Engine.time_scale=4.0
 root.size=Vector2i(1440,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.visible=false
 player.get_node("CanvasLayer").hide();main.get_node("CharacterDialogue").hide()
 main.get_node("VisualLab").select_preset(0);main.get_node("VisualLab")._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 main.get_node("DayNightCycle").running=false;main.get_node("DayNightCycle").set_phase(.25)
 for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false);npc.position=Vector3(0,-100,0)
 await physics_frame
 floor_exclude.append(player.get_rid())
 for body:StaticBody3D in main.find_children("*","StaticBody3D",true,false):
  if not 'Ocean_Seabed' in str(body.get_path()):floor_exclude.append(body.get_rid())
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ocean_ground.json"))
 var floor_samples:int=0
 for x:int in range(-56,162,4):
  for z:int in range(-100,112,4):
   var hit:=seabed_ray(Vector3(x,0,z))
   if not require(not hit.is_empty(),"Missing ocean floor "+str(Vector2(x,z))):return
   if not require(hit.position.y< float(plan.floor_height_range[1])+.03 and hit.position.y> float(plan.floor_height_range[0])-.03,"Unexpected seabed grade "+str(hit.position)):return
   floor_samples+=1
 var footing_samples:int=0
 for footing:Dictionary in plan.footings:
  for a:Array in footing.bottom:
   var p:=vec(a);var hit:=seabed_ray(p)
   if not require(not hit.is_empty() and hit.position.y-p.y>.24,"Bridge footing above ground "+str(p)):return
   footing_samples+=1
  # Confirm every extension physically overlaps the actual imported pier sleeve.
  var source:MeshInstance3D=main.get_node('IslandBridges').find_child(footing.bridge,true,false)
  if not require(source!=null,"Missing original bridge sleeve "+str(footing.bridge)):return
  var old_points:PackedVector3Array=source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for a:Array in footing.top:
   var p:=vec(a);var matched:bool=false
   for v:Vector3 in old_points:
    var q:Vector3=source.global_transform*v
    if Vector2(p.x-q.x,p.z-q.z).length()<.002 and absf(p.y-q.y-.025)<.002:matched=true;break
   if not require(matched,"Footing misses original sleeve "+str(p)):return
 var closure_samples:int=0
 for closure:Dictionary in plan.terrain_closures:
  for a:Array in closure.contact_samples:
   var p:=vec(a)
   if p.y> -6.0:continue # The remaining high seams are buried in overlapping land.
   var hit:=seabed_ray(p)
   if not require(not hit.is_empty() and hit.position.y-p.y>.08,"Island edge exposed above apron "+str(p)+" "+str(hit)):return
   closure_samples+=1
 for node:Node in main.get_node('OceanGround').find_children('*','MeshInstance3D',true,false):
  if not require(not String(node.name).begins_with('Ocean_Toe_'),'A vertical island skirt remains'):return
 var horizon:MeshInstance3D=main.get_node('OceanGround').find_child('Ocean_Horizon_Water',true,false)
 if not require(horizon!=null and horizon.get_child_count()==0,'Horizon should add only water, without collision'):return
 var horizon_points:Dictionary={}
 for v:Vector3 in horizon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  horizon_points[(horizon.global_transform*v).snapped(Vector3.ONE*.0001)]=true
 var horizon_edge_samples:int=0
 var edges:Array=JSON.parse_string(FileAccess.get_file_as_string('res://assets/ocean_horizon_edges.json'))
 for edge:Array in edges:
  for a:Array in edge:
   var p:=Vector3(a[0],a[2],-a[1])
   if not require(horizon_points.has(p.snapped(Vector3.ONE*.0001)),'Horizon lost exact seam vertex '+str(p)):return
   horizon_edge_samples+=1

 var rock_samples:int=0
 for rock:Dictionary in plan.rocks:
  var source:MeshInstance3D=main.get_node('TempleMap').get_node(NodePath(rock.name))
  var points:PackedVector3Array=source.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for a:Array in rock.base_samples:
   var p:=vec(a)
   var matched:bool=false
   for v:Vector3 in points:
    if (source.global_transform*v).distance_to(p)<.003:matched=true;break
   if not require(matched,"Saved rock differs from runtime "+rock.name+str(p)):return
   rock_samples+=1
  for a:Array in rock.lower_samples:
   var p:=vec(a);var hit:=seabed_ray(p)
   if not require(not hit.is_empty() and hit.position.y-p.y>.24,"Rock foundation above seabed "+rock.name):return
 # The remaining submerged masonry is already buried in the main island.
 var terrain_exclude:Array[RID]=[player.get_rid()]
 for body:StaticBody3D in main.find_children('*','StaticBody3D',true,false):
  var path:String=str(body.get_path())
  if not ('Cliff_Terrain' in path and not 'Ocean_Toe' in path):terrain_exclude.append(body.get_rid())
 var masonry:MeshInstance3D=main.get_node('TempleMap/Terrace_Retaining_Walls')
 var masonry_samples:Dictionary={}
 for surface:int in masonry.mesh.get_surface_count():
  for v:Vector3 in masonry.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
   var p:Vector3=masonry.global_transform*v
   if p.y> -6.49:continue
   var key:String=str(p)
   if masonry_samples.has(key):continue
   var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,35,p.z),Vector3(p.x,-20,p.z));q.exclude=terrain_exclude
   var hit:=main.get_world_3d().direct_space_state.intersect_ray(q)
   if not require(not hit.is_empty() and hit.position.y>p.y+.4,'Retaining wall lacks ground '+str(p)):return
   masonry_samples[key]=true
 # Actual capsule walking across new underwater ground and unchanged bridge decks.
 for route:Array in [
  [[-15,0,65],[-2,0,65]],[[59,0,21.7],[66,0,21.7]],[[77.6,0,-6],[79.6,0,1]],
  [[-35,0,55],[-35,0,65]],[[55,0,32],[60,0,32]],[[145,0,25],[145,0,35]]]:
  for a:Array in route:a[1]=seabed_ray(vec(a)).position.y
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 var seabed_walks:int=walks
 var bridges:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/island_bridges.json'))
 for bridge:Dictionary in bridges.bridges:
  var points:Array=bridge.sections
  var mid:int=points.size()/2
  var route:Array=[points[mid-3].position.duplicate(),points[mid+3].position.duplicate()]
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 var report:Dictionary={'seabed_rays':floor_samples,'footings':plan.footings.size(),'footing_corners':footing_samples,
  'rounded_apron_contacts':closure_samples,'offshore_rocks':plan.rocks.size(),'rock_base_samples':rock_samples,
  'seabed_walks':seabed_walks,'horizon_edge_vertices':horizon_edge_samples,'bridge_deck_walks':walks-seabed_walks,'buried_retaining_wall_corners':masonry_samples.size()}
 FileAccess.open(OCEAN_OUT+'validation.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
 print('OCEAN_GROUND_PASS ',JSON.stringify(report))
 if not headless:
  camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=70
  await ocean_view('bridge_underwater',Vector3(63,-8.0,14),Vector3(60,-8.4,24))
  await ocean_view('rock_underwater',Vector3(118,-8.2,75),Vector3(131,-8.8,72))
  await ocean_view('island_toe',Vector3(-32,-8.0,64),Vector3(-15,-8.5,44))
  await ocean_view('bridges_above',Vector3(43,10,10),Vector3(43,3.5,24))
  await ocean_view('underwater_west_edge',Vector3(-48,-8,20),Vector3(-100,-8.0,20))
  await ocean_view('underwater_east_edge',Vector3(153,-8,20),Vector3(210,-8.0,20))
  await ocean_view('ocean_horizon_above',Vector3(-48,-2,20),Vector3(-200,-5.0,20))
  main.get_node('DayNightCycle').set_phase(.75)
  await ocean_view('underwater_night',Vector3(63,-8.0,14),Vector3(60,-8.4,24))
 quit()
