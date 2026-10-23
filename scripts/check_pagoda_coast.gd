extends "res://scripts/check_south_garden.gd"
## Check the repaired ridge, bridge-side ravine, meadow roots and submerged edge.
const COAST_OUT="/home/allister/Projects/live-aligned-previews/pagoda-coast-2026-10-20/final/"
var ground_exclude:Array[RID]=[]
var bed_exclude:Array[RID]=[]
var coast_samples:int=0
var boundary_samples:int=0
var root_samples:int=0
var rock_samples:int=0
var maximum_step:float=0.0
var maximum_dry_step:float=0.0

func require(ok:bool,message:String)->bool:
 if not ok:push_error(message);quit(1)
 return ok

func ground(x:float,z:float)->Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(x,30,z),Vector3(x,-20,z))
 query.exclude=ground_exclude
 return main.get_world_3d().direct_space_state.intersect_ray(query)

func bed(point:Vector3)->Dictionary:
 var query:=PhysicsRayQueryParameters3D.create(Vector3(point.x,-5.25,point.z),Vector3(point.x,-20,point.z))
 query.exclude=bed_exclude
 return main.get_world_3d().direct_space_state.intersect_ray(query)

func coast_walk(points:Array)->bool:
 var route:Array=[]
 for row:Array in points:
  var hit:=ground(float(row[0]),float(row[1]))
  if not require(not hit.is_empty(),"Missing hillside support "+str(row)):return false
  route.append([row[0],hit.position.y,row[1]])
 for reverse:bool in [false,true]:
  if not await walk(route,reverse):return false
 return true

func coast_view(label:String,point:Vector3,target:Vector3)->void:
 camera.position=point;camera.look_at(target)
 for i:int in range(20):await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(COAST_OUT+label+".png")

func run()->void:
 DirAccess.make_dir_recursive_absolute(COAST_OUT)
 var headless:bool=DisplayServer.get_name()=="headless"
 var views_only:bool="--views-only" in OS.get_cmdline_user_args()
 if headless:Engine.physics_ticks_per_second=240;Engine.time_scale=4.0
 root.size=Vector2i(1440,900)
 if not headless:root.always_on_top=true;root.grab_focus()
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.visible=false
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 player.walk_speed=5.0;player.get_node("CanvasLayer").hide()
 player.is_mouse_captured=true
 main.get_node("CharacterDialogue").hide()
 main.get_node("VisualLab").select_preset(0);main.get_node("VisualLab")._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 main.get_node("DayNightCycle").running=false;main.get_node("DayNightCycle").set_phase(.25)
 main.get_node("AnimatedWater").set_process(false);main.get_node("AnimatedWater").set_water_time(12.0)
 for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false);npc.position=Vector3(0,-100,0)
 await physics_frame
 var mesh:MeshInstance3D=main.get_node("NorthPagoda").find_child("North_Pagoda_Pagoda_Meadow_Ground",true,false)
 ground_exclude.append(player.get_rid());bed_exclude.append(player.get_rid())
 for body:StaticBody3D in main.find_children("*","StaticBody3D",true,false):
  if body.name!="NorthIslandGround":ground_exclude.append(body.get_rid())
  if not "Ocean_Seabed" in str(body.get_path()):bed_exclude.append(body.get_rid())
 if not views_only:
  var former:MeshInstance3D=main.get_node("TempleMap/Distant_Islands")
  for p:Vector3 in former.mesh.get_faces():
   if not require((former.global_transform*p).z>0,"Obsolete northern cliff still present"):return
  var bank:MeshInstance3D=main.get_node("IslandSiteRepairs").find_child("Landing_Bank_Main_North",true,false)
  if not require(not bank.visible,"Duplicate landing bank remains visible"):return
  for shape:CollisionShape3D in bank.find_children("*","CollisionShape3D",true,false):
   if not require(shape.disabled,"Obsolete bank collision remains active"):return
  # Every outer edge is embedded in the existing seabed, including underwater
  # sides that can be hidden from an above-water screenshot.
  var seen:Dictionary={}
  for surface:int in mesh.mesh.get_surface_count():
   var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for local:Vector3 in vertices:
    var p:Vector3=mesh.global_transform*local
    if minf(minf(absf(p.x-16),absf(p.x-148)),minf(absf(p.z+8),absf(p.z+108)))>.001:continue
    var key:Vector3=p.snapped(Vector3.ONE*.0001)
    if seen.has(key):continue
    seen[key]=true
    var hit:=bed(p)
    if not require(not hit.is_empty() and hit.position.y-p.y>.20,"Exposed coastal perimeter "+str(p)):return
    boundary_samples+=1
  if not require(boundary_samples>900,"Missing coastal boundary samples"):return
  # Closely spaced physics samples traverse both the former white strips and
  # the bridge-side holes. No vertical faces or gaps may remain in these grades.
  var previous_row:Array=[]
  for ix:int in range(109):
   var row:Array=[]
   for iy:int in range(111):
    var x:float=30+ix*.5;var z:float=-25-iy*.5
    var hit:=ground(x,z)
    if not require(not hit.is_empty(),"Hole in north coastal ground "+str(Vector2(x,z))):return
    var height:float=hit.position.y;row.append(height)
    if iy>0:
     maximum_step=maxf(maximum_step,absf(height-float(row[iy-1])))
     if maxf(height,float(row[iy-1]))>0:maximum_dry_step=maxf(maximum_dry_step,absf(height-float(row[iy-1])))
    if ix>0:
     maximum_step=maxf(maximum_step,absf(height-float(previous_row[iy])))
     if maxf(height,float(previous_row[iy]))>0:maximum_dry_step=maxf(maximum_dry_step,absf(height-float(previous_row[iy])))
    coast_samples+=1
   previous_row=row
  # Lower beach coves preserve clearance around the offshore rocks. The dry
  # grassy hillside above zero has a tighter limit than those coastal grades.
  if not require(maximum_step<1.2 and maximum_dry_step<.7,"Abrupt hillside grade "+str([maximum_step,maximum_dry_step])):return
  for file:String in ["gscatter_ground_cover_instances.json","north_pagoda_cover.json"]:
   var rows:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/"+file))
   for row:Dictionary in rows:
    if not row.has("pagoda_coast"):continue
    var p:Vector3=vec(row.origin)
    var hit:=ground(p.x,p.z)
    if not require(not hit.is_empty() and absf(hit.position.y-p.y-.028)<.015,"Unseated coastal grass "+str(p)):return
    if not require(p.y>-.85,"Submerged coastal grass"):return
    root_samples+=1
  if not require(root_samples>2000,"Missing slope planting"):return
  # Check the active runtime rock geometry, which can differ from older source
  # copies. Preserve a submerged gap around every emergent footprint sample.
  for label:String in ["East_Headland_Stack","East_Reef","North_Reef","North_Satellite"]:
   var rock:MeshInstance3D=main.get_node("TempleMap/"+label)
   for s:int in rock.mesh.get_surface_count():
    var vertices:PackedVector3Array=rock.mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX]
    for i:int in range(0,vertices.size(),13):
     var p:Vector3=rock.global_transform*vertices[i]
     if p.y< -5.2:continue
     var hit:=ground(p.x,p.z)
     if hit.is_empty():continue
     if not require(hit.position.y< -5.65,"Coast encroaches on offshore rock "+label+" "+str(p)):return
     rock_samples+=1
  for route:Array in [
   [[38,-54],[41,-54],[44,-54],[47,-54],[49,-54]],
   [[43,-66],[44,-63],[45,-60],[46,-57],[47,-54]],
   [[43,-37],[46,-37],[49,-37],[52,-37]],
   [[54,-33],[57,-33],[60,-33],[63,-33],[66,-33]],
   [[60,-30],[63,-31],[66,-32],[69,-33]],
   [[76,-34],[79,-34],[82,-34],[85,-34]]]:
   if not await coast_walk(route):quit(1);return
  if not require(main.get_node("RenderOptimization").tree_count==91,"Tree count changed"):return
  if not require(main.get_node("AnimatedWater").materials.size()==13,"Water surface count changed"):return
  var report:Dictionary={"coastal_ground_samples":coast_samples,"buried_boundary_vertices":boundary_samples,
   "grass_root_samples":root_samples,"offshore_rock_samples":rock_samples,"maximum_half_meter_step":maximum_step,
   "maximum_dry_half_meter_step":maximum_dry_step,"walks":walks}
  FileAccess.open(COAST_OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
  print("PAGODA_COAST_PASS ",JSON.stringify(report))
 if not headless:
  camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=70
  await coast_view("western_ridge",Vector3(41,2,-60),Vector3(53,4,-56))
  await coast_view("western_shoulder",Vector3(39,1.5,-51),Vector3(57,2,-47))
  await coast_view("bridge_slope",Vector3(46,0,-35),Vector3(57,2,-43))
  await coast_view("under_bridge",Vector3(51,2.5,-33),Vector3(60,1,-39))
  await coast_view("connector",Vector3(69,2.5,-32),Vector3(70,3,-44))
  await coast_view("overview",Vector3(28,26,-23),Vector3(64,1,-53))
  await coast_view("western_sea",Vector3(23,-3.6,-52),Vector3(57,0,-55))
  await coast_view("submerged_join",Vector3(24,-7,-52),Vector3(38,-7,-52))
 quit()
