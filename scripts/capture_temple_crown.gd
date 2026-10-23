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
 out='/home/allister/Projects/live-aligned-previews/temple-crown-2026-10-18/'+('before/' if '--before' in OS.get_cmdline_user_args() else 'after/')
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
 if '--urn-only' in OS.get_cmdline_user_args():
  await shot('fountain_urn',Vector3(5.9,5.25,-8.5),Vector3(3.4,4.2,-5.4))
  quit()
  return
 await shot('temple_front',Vector3(14,12,21),Vector3(-3.5,10,-4))
 await shot('temple_crown',Vector3(8,15,15),Vector3(-3.5,12.9,-3))
 await shot('temple_roof',Vector3(13,21,-14),Vector3(-3.5,12.8,-6))
 await shot('fountain_urn',Vector3(5.9,5.25,-8.5),Vector3(3.4,4.2,-5.4))
 await shot('rear_grove',Vector3(7.8,5.3,-10.8),Vector3(6.8,5.7,-17.3))
 await shot('sea_rocks_day',Vector3(-53,1,-12),Vector3(-44,-1,-18))
 await shot('sea_rocks_coast',Vector3(-29,2,-7),Vector3(-43,-1,-18))
 await shot('sea_rocks_night',Vector3(-53,1,-12),Vector3(-44,-1,-18),.75)
 quit()
