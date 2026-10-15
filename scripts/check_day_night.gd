extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
var main:Node3D
var cycle:Node3D
var camera:Camera3D
func _initialize()->void:call_deferred("run")
func settle(seconds:float=1.2)->void:
 var start:=Time.get_ticks_usec()
 while (Time.get_ticks_usec()-start)<seconds*1000000.0:await process_frame
func capture(label:String,point:Vector3,target:Vector3,phase:float)->void:
 camera.global_position=point;camera.look_at(target);cycle.set_phase(phase)
 await settle();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"island_lantern_"+label+".png")
func run()->void:
 root.size=Vector2i(1280,900)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(true,false)
 cycle=main.get_node("DayNightCycle");cycle.running=false
 var lamps=main.get_node("IslandLanterns")
 assert(lamps.lamps.size()==43 and cycle.cycle_seconds==600.0)
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
 await physics_frame
 var excluded:Array[RID]=[player.get_rid()]
 for lamp in lamps.lamps:excluded.append(lamp.get_node("PoleCollision").get_rid())
 var contacts:=[];var groups:={"Main":0,"North":0,"South":0,"Bridge":0}
 var rows:Variant=JSON.parse_string(FileAccess.get_file_as_string("res://assets/island_lantern_positions.json"))
 for i in lamps.lamps.size():
  var lamp:Node3D=lamps.lamps[i];var max_gap:float=-1000.0;var min_gap:float=1000.0
  for j in range(32):
   var p:Vector3=lamp.position+Vector3(cos(j*TAU/32.0)*.245,0,sin(j*TAU/32.0)*.245)
   var query:=PhysicsRayQueryParameters3D.create(p+Vector3(0,.35,0),p-Vector3(0,1,0));query.exclude=excluded
   var hit:Dictionary=main.get_world_3d().direct_space_state.intersect_ray(query)
   assert(not hit.is_empty(),"Missing support: "+lamp.name)
   var gap:float=p.y-hit.position.y;max_gap=maxf(max_gap,gap);min_gap=minf(min_gap,gap)
  assert(max_gap<.005,"Floating lamp: "+lamp.name+" "+str(max_gap))
  contacts.append({"name":lamp.name,"maximum_gap":max_gap,"minimum_gap":min_gap,"samples":32})
  groups[rows[i].island]+=1
 for group in groups:assert(groups[group]>0)
 var min_day:=1.0;var max_day:=0.0;var max_light_step:=0.0;var last_energy:float=0.0;var above:=0;var below:=0
 # Exercise a complete 600-second loop including both horizon crossings.
 for i in range(6001):
  cycle.set_phase(float(i)/6000.0)
  var solar:float=sin(cycle.phase*TAU)
  if i<6000:
   if solar>=0.0:above+=1
   else:below+=1
  min_day=minf(min_day,cycle.daylight);max_day=maxf(max_day,cycle.daylight)
  var energy:float=main.get_node("MediterraneanSun").light_energy
  if i>0:max_light_step=maxf(max_light_step,absf(energy-last_energy))
  last_energy=energy
 assert(min_day==0.0 and max_day==1.0 and abs(above-below)<=2)
 assert(max_light_step<.02)
 cycle.set_phase(.9999999);var before:Color=cycle._sky.sky_top_color;var energy_before:float=cycle._sun.light_energy
 cycle.set_phase(0.0);assert(before.is_equal_approx(cycle._sky.sky_top_color));assert(absf(energy_before-cycle._sun.light_energy)<.0001)
 cycle.set_phase(.75);assert(lamps.night_strength>.99 and lamps.lights[0].light_energy>2.)
 var night_energy:float=cycle._moon.light_energy;lab._on_value_changed(2.8,"sun_strength")
 assert(is_equal_approx(cycle._moon.light_energy,night_energy*2.0))
 lab.set_compare(true);assert(is_equal_approx(cycle._moon.light_energy,night_energy));lab.set_compare(false)
 lab.select_preset(0);assert(cycle.phase==.75 and not cycle.running)
 assert(cycle.clock_reference().day_seconds==300.0)
 var old_phase:float=cycle.phase;cycle._process(1.0);assert(cycle.phase==old_phase)
 cycle.running=true;cycle._process(60.0);assert(is_equal_approx(cycle.phase,.85));cycle.running=false;cycle.set_phase(.75)
 cycle._clock_slider.value=.25;assert(is_equal_approx(cycle.phase,.25));cycle._pause.button_pressed=false;assert(cycle.running);cycle._pause.button_pressed=true;assert(not cycle.running)
 for light in lamps.lights:assert(not light.shadow_enabled and light.distance_fade_enabled)
 var report:={"lantern_count":43,"islands":groups,"cycle_seconds":600,"day_seconds":300,"night_seconds":300,"continuous_loop":true,"continuous_dawn_dusk":true,"maximum_sun_energy_step_per_0_1_second":max_light_step,"visual_lab_composition_and_comparison":true,"existing_tree_count":main.get_node("RenderOptimization").tree_count,"shadow_free_distance_faded_lights":true,"ground_contacts":contacts}
 FileAccess.open(OUT+"day_night_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 if DisplayServer.get_name()=="headless":print("DAY_NIGHT_TEST_PASS ",JSON.stringify(groups));quit();return
 await capture("day",Vector3(-17,12,29),Vector3(-3,5,0),.25)
 await capture("dusk",Vector3(-17,12,29),Vector3(-3,5,0),.50)
 await capture("night",Vector3(-17,12,29),Vector3(-3,5,0),.75)
 await capture("detail_day",Vector3(-3.5,1.72,10.2),Vector3(-5.95,1.7,11.3),.25)
 await capture("detail_night",Vector3(-3.5,1.72,10.2),Vector3(-5.95,1.7,11.3),.75)
 await capture("north_night",Vector3(64,18,-30),Vector3(61,6,-48),.75)
 await capture("south_night",Vector3(92,14,42),Vector3(90,4,25),.75)
 camera.global_position=Vector3(-17,12,29);camera.look_at(Vector3(-3,5,0))
 lab.set_panel_open(true);lab._tabs.current_tab=1
 await settle(.5);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"day_night_controls.png")
 print("DAY_NIGHT_CAPTURE_PASS");quit()
