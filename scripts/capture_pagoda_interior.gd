extends SceneTree
var main:Node3D
var camera:Camera3D
const OUT='/home/allister/Projects/live-aligned-previews/pagoda-interior-2026-10-18/'
func _initialize()->void:call_deferred('run')
func local_point(x:float,y:float,z:float)->Vector3:
 var c:float=cos(-.88);var s:float=sin(-.88)
 return Vector3(92+c*x-s*y,5.5+z,-64-s*x-c*y)
func shot(label:String,p:Vector3,target:Vector3,phase:float=.25)->void:
 camera.position=p
 camera.look_at(target)
 main.get_node('DayNightCycle').set_phase(phase)
 var t:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-t<1000:await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(OUT+label+'.png')
func run()->void:
 root.size=Vector2i(1280,900)
 main=load('res://scenes/main.tscn').instantiate()
 main.get_node('Player').dialogue_locked=true
 root.add_child(main)
 main.get_node('Player').set_physics_process(false)
 main.get_node('Player/CanvasLayer').hide()
 main.get_node('CharacterDialogue').hide()
 main.get_node('VisualLab').select_preset(0)
 main.get_node('RenderOptimization').set_performance_mode(false,false)
 main.get_node('DayNightCycle').running=false
 for npc in main.get_node('IslandCharacters').get_children():npc.set_physics_process(false)
 await physics_frame
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65
 if '--water-only' not in OS.get_cmdline_user_args():
  await shot('couch_pillows',Vector3(-4.1,6.8,-7.8),Vector3(-1.65,5.2,-8.02))
  await shot('couch_overhead',Vector3(-2.65,7.5,-7.9),Vector3(-1.80,5.2,-8.03))
  await shot('pagoda_tea',local_point(3.4,-.2,2.7),local_point(-.4,4.3,1.6))
  await shot('pagoda_reading',local_point(3.1,.5,7.0),local_point(-.3,4.5,6.1))
  await shot('pagoda_library',local_point(.6,-2.3,7.0),local_point(-3.5,-4.5,6.2))
  await shot('pagoda_gallery',local_point(2.5,.0,11.5),local_point(-.5,4.0,10.8))
  await shot('pagoda_gallery_night',local_point(2.5,.0,11.5),local_point(-.5,4.0,10.8),.75)
 camera.fov=52
 main.get_node('AnimatedWater').set_process(false)
 for i:int in range(3):
  main.get_node('AnimatedWater').set_water_time(float(i)*.36)
  await shot('bowl_outlet_'+str(i),Vector3(3.0,6.3,-1.7),Vector3(3.4,4.25,-2.55))
 quit()
