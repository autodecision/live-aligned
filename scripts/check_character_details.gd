extends SceneTree
## Front/profile clothing checks and a real HUD reset-button interaction.
const OUT="/home/allister/Projects/live-aligned-previews/envoy-trousers-2026-10-15/"
var main:Node3D
func _initialize()->void:call_deferred("run")
func run()->void:
 DirAccess.make_dir_recursive_absolute(OUT)
 main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player:CharacterBody3D=main.get_node("Player");player.set_physics_process(false)
 for npc in main.get_node("IslandCharacters").get_children():npc.set_physics_process(false)
 await physics_frame
 # Release the cursor through the player's actual input handler.
 var escape:=InputEventAction.new();escape.action="toggle_mouse";escape.pressed=true
 player._unhandled_input(escape)
 var button:Button=player.get_node("CanvasLayer/HUD/ResetPosition")
 assert(button.visible and not player.is_mouse_captured)
 player.position=Vector3(-8,-12,22);player.velocity=Vector3(4,-3,2);player.rotation.y+=1.;player.head.rotation.x=.65
 var click:=InputEventMouseButton.new();click.position=button.get_global_rect().get_center();click.global_position=click.position;click.button_index=MOUSE_BUTTON_LEFT;click.pressed=true;click.button_mask=MOUSE_BUTTON_MASK_LEFT
 Input.parse_input_event(click);await process_frame
 click=click.duplicate();click.pressed=false;click.button_mask=0;Input.parse_input_event(click);await process_frame
 assert(player.position.distance_to(player.spawn_point)<.001,"Reset button did not return the stuck player")
 assert(player.velocity==Vector3.ZERO,"Reset retained movement momentum")
 assert(player.rotation.distance_to(player.spawn_rotation)<.001 and player.head.rotation==player.spawn_head_rotation)
 assert(not player.is_mouse_captured,"Button click was incorrectly captured by world input")
 player.capture_mouse(true);assert(not button.visible)
 player.position.y=-30;player.velocity=Vector3(2,-9,1);player._physics_process(1./60.)
 assert(player.position.distance_to(player.spawn_point)<.001 and player.velocity==Vector3.ZERO,"Automatic fall reset failed")
 print("POSITION_RESET_PASS button_mouse_click=true pose_and_velocity_reset=true automatic_fall=true")
 if "--capture" in OS.get_cmdline_user_args():await capture_views()
 main.free();quit()
func photograph(label:String)->void:
 for frame in 8:await process_frame
 RenderingServer.force_draw(false);root.get_texture().get_image().save_png(OUT+label+".png")
func capture_views()->void:
 root.size=Vector2i(1200,900);root.grab_focus()
 var player=main.get_node("Player");player.get_node("CanvasLayer").hide();player.position=Vector3(-20,4,0)
 main.get_node("DayNightCycle").running=false;main.get_node("DayNightCycle").set_phase(.25);main.get_node("VisualLab").select_preset(0)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 for npc in main.get_node("IslandCharacters").get_children():npc.hide()
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=44.
 var doctor:PS3CharacterNPC=main.get_node("IslandCharacters/Scientist")
 doctor.position=Vector3(-3.5,2.1,6.);doctor.rotation.y=0.;doctor.current_activity="travel";doctor.current_state=PS3CharacterNPC.State.WALK;doctor._motion_weight=1.;doctor._phase=0.;doctor._animate(0,1.55);doctor.show()
 camera.position=doctor.position+Vector3(.25,2.3,-2.45);camera.look_at(doctor.position+Vector3(0,.98,0));await photograph("doctor_stairs_front")
 camera.position=doctor.position+Vector3(2.1,1.2,-.9);camera.look_at(doctor.position+Vector3(0,.95,0));await photograph("doctor_stairs_profile")
 doctor.position=Vector3(-1.5,.06,10.5);doctor._motion_weight=0.;doctor._animate(0.,0.)
 camera.fov=38.;camera.position=doctor.position+Vector3(.25,1.5,-1.6);camera.look_at(doctor.position+Vector3(0,1.25,0));await photograph("doctor_front_details")
 doctor.hide()
 var envoy:PS3CharacterNPC=main.get_node("IslandCharacters/Envoy")
 envoy.position=Vector3(-3.5,.06,12.);envoy.rotation.y=0.;envoy.current_activity="travel";envoy.current_state=PS3CharacterNPC.State.WALK;envoy._motion_weight=1.;envoy.show()
 camera.fov=48.
 for frame in 90:
  envoy._phase=fposmod(float(frame)/45.,1.);envoy._animate(0.,1.35)
  camera.position=envoy.position+Vector3(.9,.82,-1.8);camera.look_at(envoy.position+Vector3(0,.60,0))
  await process_frame;RenderingServer.force_draw(false)
  root.get_texture().get_image().save_png(OUT+"envoy_walk_%03d.png"%frame)
 envoy.hide();camera.current=false;player.get_node("CanvasLayer").show();player.capture_mouse(false);player.reset_position()
 await photograph("reset_button")
