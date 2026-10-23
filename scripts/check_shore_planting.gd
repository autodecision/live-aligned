extends "res://scripts/check_south_garden.gd"
## Verify actual final terrain, shared meadow transforms and relocated rock footprints.
const SHORE_OUT="/home/allister/Projects/live-aligned-previews/shore-planting-2026-10-18/"
var terrain_exclude:Array[RID]=[]
func soil(p:Vector3)->Dictionary:
 var q:=PhysicsRayQueryParameters3D.create(Vector3(p.x,35,p.z),Vector3(p.x,-25,p.z))
 q.exclude=terrain_exclude
 return main.get_world_3d().direct_space_state.intersect_ray(q)
func shot(label:String,point:Vector3,target:Vector3)->void:
 camera.position=point
 camera.look_at(target)
 var start:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-start<1000:await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(SHORE_OUT+label+".png")
func run()->void:
 DirAccess.make_dir_recursive_absolute(SHORE_OUT)
 var headless:bool=DisplayServer.get_name()=="headless"
 if headless:Engine.physics_ticks_per_second=240;Engine.time_scale=4.0
 root.size=Vector2i(1440,900)
 main=load('res://scenes/main.tscn').instantiate();root.add_child(main)
 player=main.get_node('Player');player.set_physics_process(false);player.set_process_unhandled_input(false)
 player.get_node('CanvasLayer').hide();main.get_node('CharacterDialogue').hide()
 main.get_node('VisualLab').select_preset(0);main.get_node('VisualLab')._launcher.hide()
 main.get_node('RenderOptimization').set_performance_mode(false,false)
 main.get_node('DayNightCycle').running=false;main.get_node('DayNightCycle').set_phase(.25)
 for npc in main.get_node('IslandCharacters').get_children():npc.set_physics_process(false);npc.position=Vector3(0,-100,0)
 await physics_frame
 terrain_exclude.append(player.get_rid())
 for body:StaticBody3D in main.find_children('*','StaticBody3D',true,false):
  var path:String=body.get_path()
  if not ('Cliff_Terrain' in path or 'Distant_Islands' in path or 'Pagoda_Meadow_Ground' in path or 'Landing_Bank' in path):terrain_exclude.append(body.get_rid())
 var min_ground:float=100
 for x:float in [117.5,118.0,118.5,119.0,119.5]:
  for z:float in [40.5,41.0,41.5,42.0,42.5]:
   var hit:=soil(Vector3(x,4.735,z));assert(not hit.is_empty())
   min_ground=minf(min_ground,hit.position.y)
   assert(absf(hit.position.y-4.65)<.006,'Unsupported paved corner '+str(hit.position))
 var rows:Array=JSON.parse_string(FileAccess.get_file_as_string('res://assets/gscatter_ground_cover_instances.json'))
 rows.append_array(JSON.parse_string(FileAccess.get_file_as_string('res://assets/north_pagoda_cover.json')))
 var new_roots:int=0
 for row:Dictionary in rows:
  if not row.has('shore_planting'):continue
  var p:=vec(row.origin);var hit:=soil(p)
  assert(not hit.is_empty() and absf(p.y-hit.position.y+.028)<.012,'Floating new grass '+str(p)+' hit '+str(hit))
  assert(p.y> -1.7,'Grass in lower beach')
  new_roots+=1
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/temple_clearance.json'))
 var rock_samples:int=0
 for label:String in plan.offshore_relocation:
  var stone:MeshInstance3D=main.get_node('TempleMap').get_node(NodePath(label))
  assert(stone.position.distance_to(vec(plan.positions[label]))<.001)
  for surface:int in stone.mesh.get_surface_count():
   var points:PackedVector3Array=stone.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for local:Vector3 in points:
    var p:Vector3=stone.global_transform*local
    if p.y< -5.0:continue
    var hit:=soil(p)
    assert(hit.is_empty() or hit.position.y< -5.3,'Colored rock still on beach '+label+' '+str(p)+' soil '+str(hit))
    rock_samples+=1
 # Actual player walking along both paving edges and onto the raised shoulder.
 for route:Array in [
  [[117.9,4.735,38.5],[117.9,4.735,41.8],[114.5,4.735,41.8]],
  [[119.05,4.735,38.5],[119.05,4.735,42.1],[116.5,4.735,42.1]],
  [[119.0,4.735,41.7],[120.2,4.65,43.2],[122.5,3.7,45.0]]]:
  for point:Array in route:
   if point[0]>119.5 or point[2]>42.5:
    var hit:=soil(vec(point));assert(not hit.is_empty());point[1]=hit.position.y
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 var report:Dictionary={'corner_ground_min':min_ground,'grass_roots':new_roots,'relocated_rocks':plan.offshore_relocation.size(),'wet_rock_vertex_checks':rock_samples,'corner_and_shoulder_walks':walks}
 FileAccess.open(SHORE_OUT+'validation.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
 print('SHORE_PLANTING_PASS ',JSON.stringify(report))
 if not headless:
  player.visible=false
  camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=60
  await shot('supported_corner',Vector3(124,6.8,46),Vector3(117.9,4.3,41.7))
  await shot('south_grass',Vector3(132,7.5,54),Vector3(117,2.8,44))
  await shot('south_offshore',Vector3(137,10,82),Vector3(115,-1,65))
  await shot('north_grass',Vector3(134,9,-78),Vector3(116,2,-65))
  await shot('main_grass',Vector3(-19,5,39),Vector3(-8,1,32))
  await shot('north_offshore',Vector3(15,10,-103),Vector3(43,-1,-81))
 quit()
