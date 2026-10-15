extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func measure(label:String)->Dictionary:
 var start:=Time.get_ticks_usec()
 while Time.get_ticks_usec()-start<1200000:await process_frame
 var frames:=0;var previous:=Time.get_ticks_usec();var times:=[];start=previous
 while Time.get_ticks_usec()-start<3500000:
  await process_frame;frames+=1;var now:=Time.get_ticks_usec();times.append((now-previous)/1000.);previous=now
 times.sort();var row:={"case":label,"fps":frames*1000000./(Time.get_ticks_usec()-start),"p95_ms":times[int(times.size()*.95)]};print("LANDING_BENCH ",JSON.stringify(row));return row
func run()->void:
 root.size=Vector2i(1280,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 var clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=75
 var optim=main.get_node("RenderOptimization");var sun=main.get_node("MediterraneanSun");var rows:=[]
 for performance in [false,true]:
  optim.set_performance_mode(performance,false);var quality:String="performance" if performance else "balanced"
  camera.position=Vector3(50,7.05,19.7);camera.look_at(Vector3(0,3.7,15.7))
  rows.append(await measure(quality+"_corrected_midday_bridge"))
  sun.directional_shadow_mode=DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS;sun.directional_shadow_split_1=.1;sun.shadow_blur=1.;root.anisotropic_filtering_level=2
  for mesh in main.get_node("IslandBridges").find_children("*","MeshInstance3D",true,false):
   for i in mesh.mesh.get_surface_count():mesh.mesh.surface_get_material(i).texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
  rows.append(await measure(quality+"_previous_shadow_and_texture_settings"))
  optim.set_performance_mode(performance,false)
  for mesh in main.get_node("IslandBridges").find_children("*","MeshInstance3D",true,false):
   for i in mesh.mesh.get_surface_count():mesh.mesh.surface_get_material(i).texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  camera.fov=65;camera.position=Vector3(-17,12,29);camera.look_at(Vector3(-3,5,0))
  rows.append(await measure(quality+"_temple_view"));camera.fov=75
 FileAccess.open(OUT+"bridge_landing_repair_fps.json",FileAccess.WRITE).store_string(JSON.stringify({"resolution":[1280,900],"rows":rows},"  "));quit()
