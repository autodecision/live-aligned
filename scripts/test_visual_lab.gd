extends SceneTree
const OUT:="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
const PROFILE_NAME:="QA Temporary Roundtrip"
func _initialize()->void:call_deferred("run")
func key(code:int,pressed:bool=true)->void:
 var event:=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=pressed;Input.parse_input_event(event);Input.flush_buffered_events()
func run()->void:
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var lab=main.get_node("VisualLab");var player=main.get_node("Player")
 var clock=main.get_node("DayNightCycle");clock.running=false;clock.set_phase(.25)
 var phase:=OS.get_environment("LAB_TEST_PHASE")
 var path:String=lab.profiles_dir.path_join("qa_temporary_roundtrip.json")
 if phase=="restart":
  assert(lab.current_path==path,"Saved look must load in a new game process")
  assert(is_equal_approx(lab.values.exposure,.37))
  assert(is_equal_approx(lab.values.fog_density,.0048))
  assert(player.global_position.distance_to(Vector3(-3.5,1.2,12.))<.01,"Loading a look must not teleport without permission")
  lab._restore_view.button_pressed=true;assert(lab.load_profile(path))
  assert(player.global_position.distance_to(Vector3(4.,5.,-7.))<.01)
  FileAccess.open(OUT+"visual_lab_restart_validation.json",FileAccess.WRITE).store_string(JSON.stringify({"new_process_restored_saved_parameters":true,"viewpoint_optional":true,"explicit_viewpoint_restore":true},"  "))
  print("VISUAL_LAB_RESTART_PASS");quit();return
 lab.select_preset(0)
 # Original adds no full-screen pass or changes to the grass quality settings.
 assert(not lab._post.visible)
 var quality=main.get_node("RenderOptimization");var old_msaa:=root.msaa_3d
 for i in range(15):await process_frame
 key(KEY_F7);await process_frame
 assert(lab._panel.visible and not player.is_physics_processing() and not player.is_processing_unhandled_input())
 assert(Input.mouse_mode==Input.MOUSE_MODE_VISIBLE)
 var p:Vector3=player.global_position;var r:Vector3=player.rotation
 lab._name_edit.grab_focus();key(KEY_W)
 var motion:=InputEventMouseMotion.new();motion.relative=Vector2(50,25);Input.parse_input_event(motion)
 for i in range(3):await physics_frame
 key(KEY_W,false)
 assert(player.global_position.is_equal_approx(p) and player.rotation.is_equal_approx(r))
 lab.select_preset(2)
 lab._widgets.exposure.slider.value=.37
 lab._widgets.fog_density.spin.value=.0048
 assert(is_equal_approx(lab.values.exposure,.37) and lab._post.visible and lab._copy_button.disabled)
 var current_sun:float=lab._sun.light_energy
 key(KEY_F9);await process_frame
 assert(lab.comparing and not lab._post.visible)
 assert(is_equal_approx(lab._sun.light_energy,lab._base.sun_energy))
 key(KEY_F9,false);await process_frame
 assert(not lab.comparing and lab._post.visible and is_equal_approx(lab._sun.light_energy,current_sun))
 key(KEY_ESCAPE);await process_frame
 assert(not lab._panel.visible and player.is_physics_processing() and player.is_processing_unhandled_input())
 assert(Input.mouse_mode==Input.MOUSE_MODE_CAPTURED)
 player.set_physics_process(false);player.global_position=Vector3(4.,5.,-7.)
 player.rotation=Vector3(0,.3,0);player.get_node("Head").rotation=Vector3(.1,0,0)
 lab._name_edit.text=PROFILE_NAME
 # Use the same button signal as an actual click.
 lab._panel.find_child("SaveLook",true,false).emit_signal("pressed")
 assert(lab.current_path==path and FileAccess.file_exists(path) and not lab.dirty and not lab._copy_button.disabled)
 var saved:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 assert(saved.parameters.size()==lab.Profiles.CONTROLS.size() and saved.schema_version==1)
 assert(saved.viewpoint.player_position==[4.,5.,-7.])
 FileAccess.open(OUT+"visual_lab_example_profile.json",FileAccess.WRITE).store_string(JSON.stringify(saved,"  "))
 lab.select_preset(4);assert(not is_equal_approx(lab.values.exposure,.37))
 assert(lab.load_profile(path));assert(is_equal_approx(lab.values.exposure,.37))
 var malformed:={"schema_version":1,"profile_name":"Invalid","parameters":{"contrast":"bad"}}
 assert(not lab.Profiles.validate(malformed).ok)
 var previous:Dictionary=lab.values.duplicate(true)
 var invalid_path:String=lab.profiles_dir.path_join("qa_invalid.json")
 FileAccess.open(invalid_path,FileAccess.WRITE).store_string(JSON.stringify(malformed))
 assert(not lab.load_profile(invalid_path));assert(lab.values==previous)
 var bounds:Dictionary=lab.Profiles.validate({"schema_version":1,"profile_name":"Clamp","parameters":{"contrast":100.}})
 assert(bounds.ok and bounds.values.contrast==1.6)
 assert(not "/" in lab.Profiles.file_slug("../../My coastal: look"))
 # Overwrite the same named file and ensure the file remains complete JSON.
 lab._name_edit.text=PROFILE_NAME;assert(lab.save_profile(PROFILE_NAME)==path)
 assert(lab.Profiles.validate(JSON.parse_string(FileAccess.get_file_as_string(path))).ok)
 assert(root.msaa_3d==old_msaa and quality.tree_count==91)
 var report:={"parameter_dimensions":lab.Profiles.CONTROLS.size(),"game_inspired_presets":lab.Profiles.PRESETS.size()-1,"f7_and_escape":true,"f9_comparison":true,"no_movement_while_editing":true,"named_json_roundtrip":true,"atomic_overwrite":true,"invalid_file_preserves_look":true,"range_validation":true,"existing_graphics_and_trees_preserved":true}
 FileAccess.open(OUT+"visual_lab_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("VISUAL_LAB_TEST_PASS ",JSON.stringify(report));quit()
