extends SceneTree
var main:Node3D
var camera:Camera3D
var out:String
func _initialize()->void:call_deferred('run')
func shot(label:String,point:Vector3,target:Vector3,phase:float=.25)->void:
 camera.position=point
 camera.look_at(target)
 main.get_node('DayNightCycle').set_phase(phase)
 var t:=Time.get_ticks_msec()
 while Time.get_ticks_msec()-t<1000:await process_frame
 RenderingServer.force_draw(false)
 root.get_texture().get_image().save_png(out+label+'.png')
func run()->void:
 out='/home/allister/Projects/live-aligned-previews/temple-clearance-2026-10-18/'+('before/' if '--before' in OS.get_cmdline_user_args() else 'after/')
 DirAccess.make_dir_recursive_absolute(out)
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
 camera=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=58
 await shot('pool_fern',Vector3(7.6,.62,8.9),Vector3(6.8,.12,8.2))
 await shot('stair_plant',Vector3(-6.5,1.5,11.0),Vector3(-5.96,.35,9.86))
 await shot('side_urn',Vector3(6.65,4.8,-1.3),Vector3(5.7,3.95,-.2))
 await shot('urn_terrace',Vector3(6.05,4.95,-8.2),Vector3(5.6,3.9,-5.9))
 await shot('guardrail',Vector3(11,3.5,14),Vector3(8.8,.7,10.8))
 await shot('sea_rocks_day',Vector3(-53,1,-12),Vector3(-44,-1,-18))
 await shot('sea_rocks_night',Vector3(-53,1,-12),Vector3(-44,-1,-18),.75)
 quit()
