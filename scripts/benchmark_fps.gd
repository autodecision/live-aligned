extends SceneTree
## Native fixed-view measurements and reversible rendering-cost isolation.
const OUTPUT="/home/allister/Projects/live-aligned-previews/fps-2026-10-20/"
const VIEWS=[
 ["meadow",Vector3(-12,4,12),Vector3(-18,2,3)],
 ["temple",Vector3(-17,12,29),Vector3(-3,5,0)],
 ["laboratory",Vector3(-4.15,7.1,-7.35),Vector3(-3.02,5.65,-10.9)],
 ["water",Vector3(18,1,17),Vector3(11,-3,7.5)],
 ["pagoda_coast",Vector3(28,26,-23),Vector3(64,1,-53)],
 ["garden",Vector3(101,7,46),Vector3(100,4.7,32)],
 ["pagoda_arrival",Vector3(78,8,-48),Vector3(91,8,-65)]
]
var main:Node3D
var camera:Camera3D
var rendered:SubViewport
var rows:Array=[]
var tag:String="baseline"
var seconds:float=2.5

func _initialize()->void:call_deferred("run")

func draw_frame()->void:
 await process_frame
 RenderingServer.force_draw(false)

func measure(label:String)->Dictionary:
 var start:int=Time.get_ticks_usec()
 while Time.get_ticks_usec()-start<1000000:await draw_frame()
 var times:Array[float]=[]
 var sums:Dictionary={"process_ms":0.0,"physics_ms":0.0,"render_cpu_ms":0.0,"gpu_ms":0.0,"draw_calls":0.0,"primitives":0.0,"objects":0.0}
 start=Time.get_ticks_usec()
 var previous:int=start
 while Time.get_ticks_usec()-start<seconds*1000000:
  await draw_frame()
  var now:int=Time.get_ticks_usec()
  times.append((now-previous)/1000.0);previous=now
  sums.process_ms+=Performance.get_monitor(Performance.TIME_PROCESS)*1000
  sums.physics_ms+=Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000
  sums.render_cpu_ms+=RenderingServer.viewport_get_measured_render_time_cpu(rendered.get_viewport_rid())
  sums.gpu_ms+=RenderingServer.viewport_get_measured_render_time_gpu(rendered.get_viewport_rid())
  sums.draw_calls+=Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
  sums.primitives+=Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
  sums.objects+=Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
 times.sort()
 var row:Dictionary={"case":label,"fps":times.size()*1000000.0/(previous-start),"median_ms":times[times.size()/2],"p95_ms":times[int(times.size()*.95)],"frames":times.size()}
 for key:String in sums:row[key]=sums[key]/times.size()
 rows.append(row)
 print("FPS_BENCH ",JSON.stringify(row))
 return row

func capture(label:String)->void:
 # Fixed water/lighting and paused character poses make before/after views useful.
 for i:int in 4:await draw_frame()
 RenderingServer.force_draw(false)
 rendered.get_texture().get_image().save_png(OUTPUT+tag+"/"+label+".png")

func set_view(index:int)->void:
 camera.position=VIEWS[index][1];camera.look_at(VIEWS[index][2])

func ablation()->void:
 var trees:Array=main.get_node("RenderOptimization").trees
 var rocks:Array=[]
 for label:String in ["East_Headland_Stack","East_Reef","North_Reef","North_Satellite","South_Cove_Rock","South_Reef","South_Satellite","Southwest_Skerry","West_Sea_Stack"]:
  rocks.append(main.get_node("TempleMap/"+label))
 var sea:MeshInstance3D=main.get_node("TempleMap/Mediterranean_Sea")
 var ring:MeshInstance3D=main.get_node("OceanGround").find_child("Ocean_Horizon_Water",true,false)
 var flat:=StandardMaterial3D.new();flat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;flat.albedo_color=Color(.03,.18,.24)
 for view:int in [0,4,3]:
  set_view(view)
  var prefix:String=VIEWS[view][0]+"/"
  await measure(prefix+"full")
  main.get_node("IslandGroundCover").hide();await measure(prefix+"no_grass");main.get_node("IslandGroundCover").show()
  for tree:Node3D in trees:tree.hide()
  await measure(prefix+"no_trees")
  for tree:Node3D in trees:tree.show()
  for rock:Node3D in rocks:rock.hide()
  await measure(prefix+"no_offshore")
  for rock:Node3D in rocks:rock.show()
  main.get_node("MediterraneanSun").shadow_enabled=false
  await measure(prefix+"no_shadows")
  main.get_node("MediterraneanSun").shadow_enabled=true
  var original:Material=sea.get_surface_override_material(0)
  sea.set_surface_override_material(0,flat)
  var ring_material:Material=ring.material_override;ring.material_override=flat
  await measure(prefix+"flat_ocean")
  sea.set_surface_override_material(0,original);ring.material_override=ring_material

func paired(quality_only:bool=false)->void:
 var render=main.get_node("RenderOptimization")
 var ocean=main.get_node("OceanGround")
 var floor_node:MeshInstance3D=ocean.find_child("Ocean_Seabed",true,false)
 var shoals:MeshInstance3D=ocean.find_child("Ocean_Seabed_Shoals",true,false)
 var model:Node3D=load("res://assets/ocean_ground.glb").instantiate()
 var original_floor:Mesh=model.find_child("Ocean_Seabed",true,false).mesh
 model.free()
 var old_tree:Mesh=load("res://assets/olive_tree_render_lod.res")
 var old_shadow:Mesh=load("res://assets/olive_tree_shadow_lod.res")
 var next_tree:Mesh=load("res://assets/olive_tree_render_lod_compact.res")
 var next_shadow:Mesh=load("res://assets/olive_tree_shadow_lod_compact.res")
 var apply_variant:Callable=func(optimized:bool)->void:
  for tree:MeshInstance3D in render.trees:
   tree.mesh=next_tree if optimized else old_tree
   tree.get_node("Olive_Shadow_Proxy").mesh=next_shadow if optimized else old_shadow
  # Update fog and water time for BOTH variants, including underwater cameras.
  ocean._process(0.0)
  ocean.set_process(optimized)
  floor_node.mesh=ocean.DEEP_FLOOR if optimized else original_floor
  shoals.visible=optimized
  for mesh:MeshInstance3D in ocean.submerged_visuals:mesh.show()
  ocean.submerged_visible=true
  if optimized:ocean._process(0.0)
 for performance:bool in [false,true]:
  render.set_performance_mode(performance,false)
  for view:int in VIEWS.size():
   set_view(view)
   for optimized:bool in ([false,true] if view%2==0 else [true,false]):
    apply_variant.call(optimized)
    var mode:String="performance" if performance else "balanced"
    var label:String=mode+"/"+VIEWS[view][0]+("/after" if optimized else "/before")
    if not quality_only:await measure(label)
    if quality_only or not performance:await capture((mode+"_" if quality_only else "")+VIEWS[view][0]+("_after" if optimized else "_before"))
 if quality_only:
  render.set_performance_mode(false,false)
  for phase:float in [.47,.75]:
   main.get_node("DayNightCycle").set_phase(phase)
   for view:int in [0,2,4]:
    set_view(view)
    for optimized:bool in [false,true]:
     apply_variant.call(optimized)
     await capture("phase_"+str(phase)+"_"+VIEWS[view][0]+("_after" if optimized else "_before"))
  main.get_node("DayNightCycle").set_phase(.25)
 for water_time:float in ([0.,12.,40.,96.] if quality_only else [12.]):
  main.get_node("AnimatedWater").set_water_time(water_time)
  for point:Vector3 in [Vector3(24,-4.3,-52),Vector3(24,-5.1,-52),Vector3(24,-7,-52)]:
   camera.position=point;camera.look_at(Vector3(38,-7,-52))
   for optimized:bool in [false,true]:
    apply_variant.call(optimized)
    await capture("waterline_"+str(water_time)+"_"+str(point.y)+("_after" if optimized else "_before"))

func run()->void:
 if DisplayServer.get_name()=="headless":push_error("Native rendering required");quit(2);return
 var args:PackedStringArray=OS.get_cmdline_user_args()
 if args.size()>0:tag=args[0]
 if args.size()>1:seconds=float(args[1])
 DirAccess.make_dir_recursive_absolute(OUTPUT+tag)
 root.size=Vector2i(1280,720);root.always_on_top=true;root.grab_focus()
 DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 Engine.max_fps=0
 # One explicit submission per frame also works when the native window is
 # hidden by the desktop. Never time CPU ticks while the GPU is asleep.
 RenderingServer.set_render_loop_enabled(false)
 # Window occlusion must not stop GPU submission while CPU frames keep ticking.
 # This native offscreen target renders at the same fixed size in every run.
 rendered=SubViewport.new();rendered.size=Vector2i(1280,720)
 rendered.own_world_3d=true;rendered.render_target_update_mode=SubViewport.UPDATE_ALWAYS
 root.add_child(rendered)
 var preview:=TextureRect.new();preview.texture=rendered.get_texture();preview.size=Vector2(1280,720)
 root.add_child(preview)
 main=load("res://scenes/main.tscn").instantiate()
 # Map the native preview before the player's normal startup cursor capture.
 # An offscreen target alone does not make an X11 window eligible for a grab.
 await process_frame
 RenderingServer.force_draw(true)
 await process_frame
 root.grab_focus()
 rendered.add_child(main)
 var player:CharacterBody3D=main.get_node("Player")
 player.set_physics_process(false);player.set_process_unhandled_input(false);player.visible=false;player.get_node("CanvasLayer").hide()
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 main.get_node("CharacterDialogue").hide()
 main.get_node("VisualLab").select_preset(0);main.get_node("VisualLab")._launcher.hide()
 main.get_node("DayNightCycle").running=false;main.get_node("DayNightCycle").set_phase(.25)
 main.get_node("AnimatedWater").set_process(false);main.get_node("AnimatedWater").set_water_time(12.0)
 for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false)
 main.get_node("SouthGarden").set_process(false)
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
 RenderingServer.viewport_set_measure_render_time(rendered.get_viewport_rid(),true)
 await draw_frame()
 if tag in ["ablation","paired","quality"]:
  main.get_node("RenderOptimization").set_performance_mode(false,false)
  if tag=="ablation":await ablation()
  else:await paired(tag=="quality")
 else:
  for performance:bool in [false,true]:
   main.get_node("RenderOptimization").set_performance_mode(performance,false)
   for view:int in VIEWS.size():
    set_view(view)
    var label:String=("performance/" if performance else "balanced/")+VIEWS[view][0]
    await measure(label)
    if not performance:await capture(VIEWS[view][0])
   main.get_node("DayNightCycle").set_phase(.75)
   set_view(0);await measure(("performance/" if performance else "balanced/")+"meadow_night")
   main.get_node("DayNightCycle").set_phase(.25)
 var report:Dictionary={"tag":tag,"actual_resolution":[rendered.size.x,rendered.size.y],"window_resolution":[root.size.x,root.size.y],"always_rendered":true,"explicit_render_submission":true,"actors_and_water_frozen":true,"vsync":false,"view_fov":camera.fov,"gpu":RenderingServer.get_video_adapter_name(),"rows":rows}
 FileAccess.open(OUTPUT+tag+"/report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("FPS_BENCH_COMPLETE ",tag)
 quit()
