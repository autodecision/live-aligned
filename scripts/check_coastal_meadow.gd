extends "res://scripts/check_shore_planting.gd"
const DETAIL_OUT="/home/allister/Projects/live-aligned-previews/coastal-meadow-2026-10-18/"
func view(label:String,p:Vector3,target:Vector3)->void:
 camera.position=p;camera.look_at(target)
 for i in range(35):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(DETAIL_OUT+label+'.png')
func run()->void:
 DirAccess.make_dir_recursive_absolute(DETAIL_OUT)
 var headless:bool=DisplayServer.get_name()=='headless'
 if headless:Engine.physics_ticks_per_second=240;Engine.time_scale=4.0
 root.size=Vector2i(1440,900)
 main=load('res://scenes/main.tscn').instantiate();root.add_child(main)
 player=main.get_node('Player');player.set_physics_process(false);player.set_process_unhandled_input(false);player.visible=false
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
 var rows:Array=JSON.parse_string(FileAccess.get_file_as_string('res://assets/gscatter_ground_cover_instances.json'))
 rows.append_array(JSON.parse_string(FileAccess.get_file_as_string('res://assets/north_pagoda_cover.json')))
 var roots:int=0
 for row:Dictionary in rows:
  if not row.has('coastal_meadow'):continue
  var p:=vec(row.origin);var hit:=soil(p)
  if hit.is_empty() or absf(p.y-hit.position.y+.028)>.012:
   push_error('Coastal grass root mismatch '+str(p)+' '+str(hit));quit(1);return
  roots+=1
 var plan:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/coastal_meadow.json'))
 assert(roots==int(plan.grass.added_total) and rows.size()==int(plan.grass.runtime_total))
 for route:Array in [
  [[-11,0,30],[-6,0,30],[-2,0,30],[3,0,30]],
  [[-7,0,28],[-4,0,32],[0,0,36]],
  [[-6,0,29],[-6,0,34],[-6,0,39]]]:
  for p:Array in route:
   var hit:=soil(vec(p));assert(not hit.is_empty());p[1]=hit.position.y
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 var shoulder_walks:int=walks
 var bridges:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/island_bridges.json'))
 for bridge:Dictionary in bridges.bridges:
  if bridge.name!='Main_South':continue
  var a:=vec(bridge.start);var d:=Vector3(bridge.direction[0],0,-bridge.direction[1]);var side:=Vector3(-d.z,0,d.x)
  var routes:Array=[]
  for lane:float in [-1.2,0.0,1.2]:
   var p:Vector3=a-d*4+side*lane;var q:Vector3=a+d*7+side*lane
   routes.append([[p.x,p.y,p.z],[q.x,q.y,q.z]])
  var full:Array=[]
  var start:Vector3=a-d*3;full.append([start.x,start.y,start.z])
  for j:int in range(0,bridge.sections.size(),8):full.append(bridge.sections[j].position.duplicate())
  var end:Vector3=vec(bridge.end)+d*3;full.append([end.x,end.y,end.z]);routes.append(full)
  for route:Array in routes:
   for point:Array in route:
    var p:=vec(point)
    var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*8,p-Vector3.UP*15);query.exclude=[player.get_rid()]
    var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query)
    assert(not hit.is_empty());point[1]=hit.position.y
   for reverse:bool in [false,true]:
    if not await walk(route,reverse):quit(1);return
 var report:Dictionary={'new_roots_verified':roots,'total_grass':rows.size(),'shoulder_walks':shoulder_walks,'bridge_walks':walks-shoulder_walks}
 FileAccess.open(DETAIL_OUT+'validation.json',FileAccess.WRITE).store_string(JSON.stringify(report,'  '))
 print('COASTAL_MEADOW_PASS ',JSON.stringify(report))
 if not headless:
  camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=66
  await view('after_south',Vector3(6,6,25),Vector3(-9,0,30))
  await view('after_garden',Vector3(119,6.5,42),Vector3(112,4.5,28))
  await view('after_garden_shoulder',Vector3(117.6,6.6,43),Vector3(122.5,4.2,28))
  await view('after_north_meadow',Vector3(123,5.5,-72),Vector3(112,4,-63))
 quit()
