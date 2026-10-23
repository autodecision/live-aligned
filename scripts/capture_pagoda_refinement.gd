extends SceneTree
var main:Node3D
var camera:Camera3D
const OUT='/home/allister/Projects/live-aligned-previews/pagoda-books-2026-10-18/'
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
 await shot('second_floor_books',local_point(-3.55,-2.65,6.78),local_point(-3.55,-4.55,6.10))
 await shot('second_floor_books_angle',local_point(-2.2,-2.5,6.9),local_point(-3.55,-4.55,6.12))
 await shot('first_floor_books',local_point(-4.6,2.9,2.25),local_point(-4.6,4.85,1.63))
 await shot('first_floor_books_angle',local_point(-2.7,3.1,2.25),local_point(-4.6,4.85,1.68))
 await shot('bonsai_right',local_point(2.65,2.5,11.15),local_point(3.75,3.75,10.82))
 await shot('bonsai_left',local_point(-2.65,2.5,11.15),local_point(-3.75,3.75,10.82))
 await shot('books_night',local_point(-3.55,-2.65,6.78),local_point(-3.55,-4.55,6.10),.75)
 quit()
