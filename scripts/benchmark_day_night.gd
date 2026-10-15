extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func measure(label:String)->Dictionary:
 var start:=Time.get_ticks_usec()
 while Time.get_ticks_usec()-start<1200000:await process_frame
 var frames:=0;var times:=[];var previous:=Time.get_ticks_usec();start=previous
 while Time.get_ticks_usec()-start<3500000:
  await process_frame;frames+=1;var now:=Time.get_ticks_usec();times.append((now-previous)/1000.0);previous=now
 times.sort()
 var row:={"case":label,"fps":frames*1000000.0/(Time.get_ticks_usec()-start),"frame_ms_p95":times[int(times.size()*.95)]}
 print("CLOCK_BENCH ",JSON.stringify(row));return row
func run()->void:
 root.size=Vector2i(1280,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 main.get_node("RenderOptimization").set_performance_mode(true,false)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65;camera.global_position=Vector3(-17,12,29);camera.look_at(Vector3(-3,5,0))
 var cycle=main.get_node("DayNightCycle");var lamps=main.get_node("IslandLanterns");cycle.set_phase(.25);cycle.running=false;cycle.set_process(false)
 var rows:=[]
 lamps.hide();rows.append(await measure("day_without_lantern_geometry_or_local_lights"))
 lamps.show();rows.append(await measure("day_lanterns_cycle_paused"))
 cycle.running=true;cycle.set_process(true);rows.append(await measure("day_lanterns_cycle_running"))
 cycle.running=false;cycle.set_phase(.75);rows.append(await measure("night_lanterns_cycle_paused"))
 cycle.running=true;rows.append(await measure("night_lanterns_cycle_running"))
 cycle.running=false;cycle.set_phase(.75)
 for light in lamps.lights:light.hide()
 cycle.set_process(false);rows.append(await measure("night_bulbs_without_local_lights"))
 FileAccess.open(OUT+"day_night_fps.json",FileAccess.WRITE).store_string(JSON.stringify({"resolution":[1280,900],"quality":"Performance","rows":rows},"  "));quit()
