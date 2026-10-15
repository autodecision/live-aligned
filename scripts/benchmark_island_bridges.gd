extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func measure(label:String)->Dictionary:
 var start:=Time.get_ticks_usec()
 while Time.get_ticks_usec()-start<1200000:await process_frame
 var frames:=0;var times:=[];var previous:=Time.get_ticks_usec();start=previous
 while Time.get_ticks_usec()-start<3500000:
  await process_frame;frames+=1;var now:=Time.get_ticks_usec();times.append((now-previous)/1000.);previous=now
 times.sort()
 var row:={"case":label,"fps":frames*1000000./(Time.get_ticks_usec()-start),"frame_ms_p95":times[int(times.size()*.95)]}
 print("BRIDGE_BENCH ",JSON.stringify(row));return row
func run()->void:
 root.size=Vector2i(1280,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 main.get_node("RenderOptimization").set_performance_mode(true,false)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
 var clock=main.get_node("DayNightCycle");clock.running=false
 var bridges=main.get_node("IslandBridges");var lamps=main.get_node("IslandLanterns");var rows:=[]
 camera.position=Vector3(-17,12,29);camera.look_at(Vector3(-3,5,0));clock.set_phase(.25)
 rows.append(await measure("temple_view_day_with_bridges"))
 camera.position=Vector3(24,8,-30);camera.look_at(Vector3(55,6,-39));clock.set_phase(.25)
 rows.append(await measure("bridge_view_day_with_bridges"))
 clock.set_phase(.75);rows.append(await measure("bridge_view_night_with_bridges_and_lights"))
 bridges.hide()
 for lamp in lamps.lamps:
  if "Bridge_" in String(lamp.name):lamp.hide()
 rows.append(await measure("same_night_view_without_bridge_visuals_or_lights"))
 FileAccess.open(OUT+"island_bridges_fps.json",FileAccess.WRITE).store_string(JSON.stringify({"resolution":[1280,900],"quality":"Performance","samples_seconds":3.5,"rows":rows},"  "));quit()
