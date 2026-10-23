extends CanvasLayer
# The screen pass sits below the HUD; the lab itself is above both.
const Profiles = preload("res://scripts/visual_lab_profiles.gd")
const UIThemes = preload("res://scripts/ui_themes.gd")
const ACTIVE_FILE := "user://visual_lab_active.json"
const ACCENT := Color("efbd78")
const MUTED := Color("9daeb9")
const POST_DRIVERS := ["exposure","contrast","saturation","vibrance","temperature","tint","shadow_tone","highlight_warmth","gamma","shadow_lift","highlight_rolloff","bloom","sharpness","vignette","chromatic","film_grain","lens_distortion","letterbox","posterize","outlines","scanlines","bleach"]
var values:Dictionary = Profiles.defaults()
var look_enabled := true
var comparing := false
var dirty := false
var current_path := ""
var profiles_dir := ""
var source_preset := "original"
var _player:CharacterBody3D
var _environment:Environment
var _sky:ProceduralSkyMaterial
var _sun:DirectionalLight3D
var _base:Dictionary
var _panel:PanelContainer
var _launcher:Button
var _post:ColorRect
var _effect_layer:CanvasLayer
var _material:ShaderMaterial
var _widgets:Dictionary = {}
var _preset_menu:OptionButton
var _description:Label
var _enabled_toggle:CheckButton
var _compare:Button
var _copy_button:Button
var _name_edit:LineEdit
var _saved_menu:OptionButton
var _path_edit:LineEdit
var _status:Label
var _stats:Label
var _restore_view:CheckBox
var _tabs:TabContainer
var _root_ui:Control
var _theme_picker:OptionButton
var _theme_desc:Label
var _lab_title_accent:Label
var _keep_look_accent:Label
var _theme_title_accent:Label
var _syncing := false
var _prior_physics := true
var _prior_input := true
var _prior_capture := true
var _timer := 0.
var _last_document:Dictionary = {}
var _last_lighting:Array = []

func _ready()->void:
 layer=20
 _player=get_parent().get_node("Player")
 _sun=get_parent().get_node("MediterraneanSun")
 var world:WorldEnvironment=get_parent().get_node("WorldEnvironment")
 world.environment=world.environment.duplicate(true)
 _environment=world.environment
 _sky=_environment.sky.sky_material
 _base={"sun_energy":_sun.light_energy,"sun_color":_sun.light_color,"sun_rotation":_sun.rotation,"ambient":_environment.ambient_light_energy,"fog_density":_environment.fog_density,"fog_color":_environment.fog_light_color,"fog_height":_environment.fog_height,"fog_height_density":_environment.fog_height_density,"sky_top":_sky.sky_top_color,"sky_horizon":_sky.sky_horizon_color,"sky_energy":_sky.sky_energy_multiplier,"fov":_player.get_node("Head/Camera3D").fov}
 _make_screen_pass()
 profiles_dir=ProjectSettings.globalize_path("res://shader_profiles")
 if DirAccess.make_dir_recursive_absolute(profiles_dir)!=OK:
  profiles_dir=OS.get_user_data_dir().path_join("shader_profiles")
  DirAccess.make_dir_recursive_absolute(profiles_dir)
 _build_ui()
 UIThemes.add_theme_listener(_on_theme_changed)
 _refresh_saved_list()
 if FileAccess.file_exists(ACTIVE_FILE):
  var active:Variant=JSON.parse_string(FileAccess.get_file_as_string(ACTIVE_FILE))
  if active is Dictionary and active.get("path") is String and FileAccess.file_exists(active.path):load_profile(active.path,false)
 _refresh_controls()
 apply_values()
 get_window().focus_exited.connect(func():set_compare(false))
 set_process(true)

func _make_screen_pass()->void:
 _effect_layer=CanvasLayer.new();_effect_layer.name="VisualLabScreenPass";_effect_layer.layer=0
 add_child(_effect_layer)
 _post=ColorRect.new();_post.name="ScreenTreatment";_post.mouse_filter=Control.MOUSE_FILTER_IGNORE
 _post.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 _material=ShaderMaterial.new();_material.shader=preload("res://shaders/visual_lab.gdshader")
 _post.material=_material;_effect_layer.add_child(_post)

func _style(color:Color,border:Color=Color.TRANSPARENT,radius:int=8)->StyleBoxFlat:
 var box:=StyleBoxFlat.new();box.bg_color=color;box.border_color=border
 box.set_border_width_all(1);box.set_corner_radius_all(radius)
 box.content_margin_left=12;box.content_margin_right=12;box.content_margin_top=7;box.content_margin_bottom=7
 return box

func _theme()->Theme:
 return UIThemes.make_visual_lab_theme()

func _label(text:String,size:int=14,color:Color=Color("e9eef0"))->Label:
 var label:=Label.new();label.text=text;label.add_theme_font_size_override("font_size",size);label.add_theme_color_override("font_color",color)
 return label

func _button(text:String,callback:Callable)->Button:
 var button:=Button.new();button.text=text;button.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 button.pressed.connect(callback);return button

func _row()->HBoxContainer:
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);return row

func _build_ui()->void:
 var root_ui:=Control.new();root_ui.name="LabUI";root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);root_ui.mouse_filter=Control.MOUSE_FILTER_IGNORE;root_ui.theme=_theme();add_child(root_ui)
 _root_ui=root_ui
 # Keep the control for existing preview scripts; F7 is the visible HUD shortcut.
 _launcher=_button("Visual Lab   F7",func():set_panel_open(true));_launcher.name="OpenVisualLab"
 _launcher.hide()
 root_ui.add_child(_launcher);_launcher.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT);_launcher.position=Vector2(-188,-64);_launcher.size=Vector2(168,42)
 _panel=PanelContainer.new();_panel.name="VisualLabPanel";root_ui.add_child(_panel)
 _panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT);_panel.anchor_bottom=1.;_panel.offset_left=-530;_panel.offset_right=-20;_panel.offset_top=20;_panel.offset_bottom=-20
 var margin:=MarginContainer.new();margin.add_theme_constant_override("margin_left",7);margin.add_theme_constant_override("margin_right",7);margin.add_theme_constant_override("margin_top",5);margin.add_theme_constant_override("margin_bottom",5);_panel.add_child(margin)
 var body:=VBoxContainer.new();body.add_theme_constant_override("separation",9);margin.add_child(body)
 var heading:=_row();body.add_child(heading)
 var titles:=VBoxContainer.new();titles.size_flags_horizontal=Control.SIZE_EXPAND_FILL;heading.add_child(titles)
 _lab_title_accent=_label("VISUAL LAB",11,ACCENT);titles.add_child(_lab_title_accent);titles.add_child(_label("Shape the scene",25))
 _stats=_label("LIVE",12,MUTED);heading.add_child(_stats)
 var close_button:=_button("×",func():set_panel_open(false));close_button.name="CloseVisualLab";close_button.tooltip_text="Close • F7 or Esc";heading.add_child(close_button)
 _preset_menu=OptionButton.new();_preset_menu.name="StartingLook";_preset_menu.fit_to_longest_item=false;_preset_menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 for preset in Profiles.PRESETS:_preset_menu.add_item(preset.name if preset.id=="original" else preset.inspiration+" · "+preset.name)
 _preset_menu.item_selected.connect(select_preset);body.add_child(_preset_menu)
 _description=_label("",12,MUTED);_description.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_description.custom_minimum_size.y=44;body.add_child(_description)
 var actions:=_row();body.add_child(actions)
 _enabled_toggle=CheckButton.new();_enabled_toggle.text="Look enabled";_enabled_toggle.button_pressed=true;_enabled_toggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 _enabled_toggle.toggled.connect(func(enabled:bool):look_enabled=enabled;dirty=true;apply_values();_update_status());actions.add_child(_enabled_toggle)
 _compare=Button.new();_compare.name="CompareOriginal";_compare.text="Hold original · F9";_compare.tooltip_text="Hold this button or F9 to compare the original scene, including lighting and fog."
 _compare.button_down.connect(func():set_compare(true));_compare.button_up.connect(func():set_compare(false));actions.add_child(_compare)
 var reset:=_button("Reset",func():select_preset(0));reset.name="ResetLook";reset.tooltip_text="Reset every dimension to the original scene.";actions.add_child(reset)
 _tabs=TabContainer.new();_tabs.name="Dimensions";_tabs.size_flags_vertical=Control.SIZE_EXPAND_FILL;_tabs.custom_minimum_size.y=130;body.add_child(_tabs)
 for group in Profiles.GROUPS:
  var scroll:=ScrollContainer.new();scroll.name=group;scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;_tabs.add_child(scroll)
  var column:=VBoxContainer.new();column.size_flags_horizontal=Control.SIZE_EXPAND_FILL;column.add_theme_constant_override("separation",10);scroll.add_child(column)
  for control in Profiles.CONTROLS:
   if control[2]==group:_add_control(column,control)
 _build_theme_ui()
 _keep_look_accent=_label("KEEP THIS LOOK",11,ACCENT);body.add_child(_keep_look_accent)
 var save_row:=_row();body.add_child(save_row)
 _name_edit=LineEdit.new();_name_edit.name="ProfileName";_name_edit.placeholder_text="Name your look";_name_edit.text="Coastal study";_name_edit.max_length=80;_name_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL;save_row.add_child(_name_edit)
 var save:=_button("Save look",func():save_profile(_name_edit.text));save.name="SaveLook";save.tooltip_text="Write a named JSON file and restore this saved look on the next launch.";save_row.add_child(save)
 var load_row:=_row();body.add_child(load_row)
 _saved_menu=OptionButton.new();_saved_menu.name="SavedLooks";_saved_menu.fit_to_longest_item=false;_saved_menu.size_flags_horizontal=Control.SIZE_EXPAND_FILL;load_row.add_child(_saved_menu)
 var load_button:=_button("Load",_load_selected);load_button.name="LoadLook";load_row.add_child(load_button)
 _restore_view=CheckBox.new();_restore_view.text="Also restore the saved viewpoint";_restore_view.add_theme_font_size_override("font_size",12);_restore_view.tooltip_text="Optional: move back to the camera position stored with a saved look.";body.add_child(_restore_view)
 _path_edit=LineEdit.new();_path_edit.name="SavedPath";_path_edit.editable=false;_path_edit.placeholder_text="Save a look to get a shareable file path";_path_edit.add_theme_font_size_override("font_size",11);body.add_child(_path_edit)
 var path_actions:=_row();body.add_child(path_actions)
 _copy_button=_button("Copy path",func():
  if not current_path.is_empty():DisplayServer.clipboard_set(current_path);_set_status("Path copied. Send it to me when you find your look.")
 );_copy_button.name="CopyProfilePath";path_actions.add_child(_copy_button)
 path_actions.add_child(_button("Open folder",func():OS.shell_open(profiles_dir)))
 var shortcut:=_label("F7 panel  ·  Hold F9 original",11,MUTED);shortcut.size_flags_horizontal=Control.SIZE_EXPAND_FILL;shortcut.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;path_actions.add_child(shortcut)
 _status=_label("",12,MUTED);_status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;_status.custom_minimum_size.y=32;body.add_child(_status)
 _panel.hide();_resize_panel();get_viewport().size_changed.connect(_resize_panel)

func _add_control(parent:VBoxContainer,definition:Array)->void:
 var key:String=definition[0]
 var item:=VBoxContainer.new();item.add_theme_constant_override("separation",2);parent.add_child(item)
 var top:=_row();item.add_child(top)
 var title:=_label(definition[1],13);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;title.tooltip_text=definition[7];top.add_child(title)
 var spin:=SpinBox.new();spin.name=key+"_value";spin.min_value=definition[4];spin.max_value=definition[5];spin.step=definition[6];spin.value=definition[3];spin.custom_minimum_size.x=88;spin.tooltip_text=definition[7];spin.value_changed.connect(_on_value_changed.bind(key));top.add_child(spin)
 var reset:=_button("↺",_reset_dimension.bind(key));reset.tooltip_text="Reset "+definition[1];top.add_child(reset)
 var slider:=HSlider.new();slider.name=key+"_slider";slider.min_value=definition[4];slider.max_value=definition[5];slider.step=definition[6];slider.value=definition[3];slider.tooltip_text=definition[7];slider.custom_minimum_size.y=19;slider.value_changed.connect(_on_value_changed.bind(key));item.add_child(slider)
 _widgets[key]={"slider":slider,"spin":spin}

func _resize_panel()->void:
 if not is_instance_valid(_panel):return
 var width:=minf(510.,get_viewport().get_visible_rect().size.x-28.)
 _panel.offset_left=-width-16.;_panel.offset_right=-16.

func _on_value_changed(value:float,key:String)->void:
 if _syncing:return
 values[key]=value;dirty=true
 _widgets[key].slider.set_value_no_signal(value);_widgets[key].spin.set_value_no_signal(value)
 _update_dependencies();apply_values();_update_status()

func _reset_dimension(key:String)->void:
 _on_value_changed(Profiles.defaults()[key],key)

func select_preset(index:int)->void:
 if index<0 or index>=Profiles.PRESETS.size():return
 values=Profiles.preset_values(index);look_enabled=true;source_preset=Profiles.PRESETS[index].id;dirty=true
 _preset_menu.select(index);_name_edit.text=Profiles.PRESETS[index].name
 _refresh_controls();apply_values()

func _refresh_controls()->void:
 _syncing=true
 for key in _widgets:
  _widgets[key].slider.set_value_no_signal(values[key]);_widgets[key].spin.set_value_no_signal(values[key])
 _enabled_toggle.set_pressed_no_signal(look_enabled)
 var index:=0
 for i in Profiles.PRESETS.size():
  if Profiles.PRESETS[i].id==source_preset:index=i;break
 _preset_menu.select(index)
 var preset:Dictionary=Profiles.PRESETS[index]
 _description.text=("Inspired by "+preset.inspiration+" · " if index>0 else "")+preset.description
 _syncing=false;_update_dependencies();_update_status()

func _update_dependencies()->void:
 var dependencies:={"bloom_radius":"bloom","bloom_threshold":"bloom","vignette_softness":"vignette","color_levels":"posterize","outline_width":"outlines","fog_height":"height_haze"}
 for key in dependencies:
  var active:bool=values[dependencies[key]]>.001
  _widgets[key].slider.editable=active
  _widgets[key].spin.editable=active

func _tint_color(base:Color,warmth:float)->Color:
 return base.lerp(Color(1.,.72,.4) if warmth>0. else Color(.4,.7,1.),absf(warmth)*.45)

func apply_values()->void:
 if not is_instance_valid(_post):return
 var v:Dictionary=Profiles.defaults() if comparing or not look_enabled else values
 var lighting:Array=[v.sun_strength,v.sun_warmth,v.sun_elevation,v.sun_azimuth,v.ambient_fill,v.fog_density,v.fog_warmth,v.fog_height,v.height_haze,v.sky_warmth,v.sky_brightness,v.fov]
 if lighting!=_last_lighting:
  _apply_lighting(v)
  _last_lighting=lighting
 for key in Profiles.POST_KEYS:_material.set_shader_parameter(key,v[key])
 var defaults:=Profiles.defaults();var changed:=false
 for key in POST_DRIVERS:
  if not is_equal_approx(float(v[key]),float(defaults[key])):changed=true;break
 _post.visible=changed and look_enabled and not comparing

func _apply_lighting(v:Dictionary)->void:
 var clock=get_parent().get_node_or_null("DayNightCycle")
 if clock:
  clock.set_look(v)
  _player.get_node("Head/Camera3D").fov=_base.fov+v.fov-75.
  return
 _sun.light_energy=_base.sun_energy*v.sun_strength/1.4
 _sun.light_color=_tint_color(_base.sun_color,v.sun_warmth)
 _sun.rotation=_base.sun_rotation+Vector3(deg_to_rad(35.-v.sun_elevation),deg_to_rad(v.sun_azimuth-30.),0.)
 _environment.ambient_light_energy=_base.ambient*v.ambient_fill/.6
 _environment.fog_density=maxf(0.,_base.fog_density+v.fog_density-.001)
 _environment.fog_light_color=_tint_color(_base.fog_color,v.fog_warmth)
 _environment.fog_height=_base.fog_height+v.fog_height-2.
 _environment.fog_height_density=_base.fog_height_density+v.height_haze
 _sky.sky_top_color=_tint_color(_base.sky_top,v.sky_warmth)
 _sky.sky_horizon_color=_tint_color(_base.sky_horizon,v.sky_warmth)
 _sky.sky_energy_multiplier=_base.sky_energy*v.sky_brightness
 _player.get_node("Head/Camera3D").fov=_base.fov+v.fov-75.

func set_compare(enabled:bool)->void:
 comparing=enabled;apply_values();_update_status()

func set_panel_open(open:bool)->void:
 if _panel.visible==open:return
 set_compare(false)
 if open:
  _refresh_saved_list()
  _prior_physics=_player.is_physics_processing();_prior_input=_player.is_processing_unhandled_input();_prior_capture=_player.is_mouse_captured
  _player.set_physics_process(false);_player.set_process_unhandled_input(false);_player.capture_mouse(false)
  _player.velocity=Vector3.ZERO;_panel.show();_launcher.hide()
 else:
  _panel.hide();_launcher.hide();_player.set_physics_process(_prior_physics);_player.set_process_unhandled_input(_prior_input);_player.capture_mouse(_prior_capture)
  get_viewport().gui_release_focus()

func _input(event:InputEvent)->void:
 if not event is InputEventKey:return
 var key:int=event.physical_keycode if event.physical_keycode else event.keycode
 if key==KEY_F7 and event.pressed and not event.echo:
  set_panel_open(not _panel.visible);get_viewport().set_input_as_handled()
 elif key==KEY_F9 and not event.echo:
  set_compare(event.pressed);get_viewport().set_input_as_handled()
 elif key==KEY_F10 and event.pressed and not event.echo:
  UIThemes.cycle_theme(1);get_viewport().set_input_as_handled()
 elif key==KEY_ESCAPE and event.pressed and _panel.visible:
  set_panel_open(false);get_viewport().set_input_as_handled()

func _process(delta:float)->void:
 _timer+=delta
 if _timer<.5:return
 _timer=0.
 if is_instance_valid(_stats) and _panel.visible:
  var mode:String="Performance" if get_parent().get_node("RenderOptimization").performance_mode else "Balanced"
  _stats.text="%d FPS\n%s"%[Engine.get_frames_per_second(),mode]

func _set_status(message:String,error:bool=false)->void:
 _status.text=message;_status.add_theme_color_override("font_color",Color("ffac9b") if error else MUTED)

func _update_status()->void:
 if not is_instance_valid(_status):return
 _path_edit.text=current_path;_path_edit.tooltip_text=current_path;_path_edit.caret_column=current_path.length()
 _copy_button.disabled=current_path.is_empty() or dirty
 _copy_button.tooltip_text="Save the current preview before copying its path." if dirty else "Copy the full saved JSON path."
 if comparing:_set_status("ORIGINAL VIEW · release to return to your look.")
 elif dirty:_set_status("Unsaved preview · Save look to keep it after restart.")
 elif not current_path.is_empty():_set_status("Saved look active · Copy its path to share this configuration.")
 else:_set_status("Pick a starting look or adjust any dimension.")

func _refresh_saved_list()->void:
 _saved_menu.clear()
 for filename in DirAccess.get_files_at(profiles_dir):
  if filename.ends_with(".json"):
   _saved_menu.add_item(filename.get_basename().replace("_"," "))
   _saved_menu.set_item_metadata(_saved_menu.item_count-1,profiles_dir.path_join(filename))
 if _saved_menu.item_count==0:_saved_menu.add_item("No saved looks yet");_saved_menu.set_item_disabled(0,true)
 else:
  for i in _saved_menu.item_count:
   if _saved_menu.get_item_metadata(i)==current_path:_saved_menu.select(i);break

func _load_selected()->void:
 var index:=_saved_menu.selected
 if index<0 or _saved_menu.is_item_disabled(index):return
 load_profile(_saved_menu.get_item_metadata(index),true)

func _write_json(path:String,document:Dictionary)->Error:
 var file:=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file==null:return FileAccess.get_open_error()
 file.store_string(JSON.stringify(document,"  ")+"\n");file.close()
 return DirAccess.rename_absolute(path+".tmp",path)

func _remember_active()->bool:
 var err:=_write_json(ProjectSettings.globalize_path(ACTIVE_FILE),{"schema_version":1,"path":current_path})
 if err!=OK:_set_status("Look saved; could not update startup preference: "+error_string(err),true)
 return err==OK

func _viewpoint()->Dictionary:
 var p:=_player.global_position;var r:=_player.rotation;var h:Vector3=_player.get_node("Head").rotation
 return {"player_position":[p.x,p.y,p.z],"player_rotation_radians":[r.x,r.y,r.z],"head_rotation_radians":[h.x,h.y,h.z],"fov_degrees":_player.get_node("Head/Camera3D").fov}

func save_profile(profile_name:String)->String:
 var label:=profile_name.strip_edges()
 if label.is_empty():_set_status("Give this look a name before saving.",true);return ""
 var path:=profiles_dir.path_join(Profiles.file_slug(label)+".json")
 var mode=get_parent().get_node("RenderOptimization")
 var inspiration:="Original scene"
 for preset in Profiles.PRESETS:
  if preset.id==source_preset:inspiration=preset.inspiration;break
 var document:={"schema_version":Profiles.SCHEMA_VERSION,"shader_revision":1,"application":"Live Aligned","profile_name":label,"source_preset":source_preset,"inspiration":inspiration,"saved_at_utc":Time.get_datetime_string_from_system(true),"effects_enabled":look_enabled,"parameters":values.duplicate(true),"viewpoint":_viewpoint(),"graphics_reference":{"render_method":"mobile","performance_mode":mode.performance_mode,"internal_resolution_scale":get_viewport().scaling_3d_scale,"msaa_enum":get_viewport().msaa_3d}}
 var clock=get_parent().get_node_or_null("DayNightCycle")
 if clock:document["world_clock_reference"]=clock.clock_reference()
 var err:=_write_json(path,document)
 if err!=OK:_set_status("Could not save this look: "+error_string(err),true);return ""
 current_path=path;dirty=false;_last_document=document;_refresh_saved_list();_update_status();_remember_active()
 return path

func load_profile(path:String,remember:bool=true)->bool:
 if not FileAccess.file_exists(path):_set_status("That saved look could not be found.",true);return false
 var document:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
 var checked:Dictionary=Profiles.validate(document)
 if not checked.ok:_set_status(checked.error,true);return false
 values=checked.values;look_enabled=checked.enabled;source_preset=str(document.get("source_preset","original"));current_path=path;dirty=false;_last_document=document
 _name_edit.text=document.profile_name
 if _restore_view.button_pressed and document.get("viewpoint") is Dictionary:_apply_viewpoint(document.viewpoint)
 _refresh_controls();apply_values();_refresh_saved_list()
 if remember:_remember_active()
 return true

func _apply_viewpoint(viewpoint:Dictionary)->void:
 var fields:=["player_position","player_rotation_radians","head_rotation_radians"]
 for key in fields:
  if not viewpoint.get(key) is Array or viewpoint[key].size()!=3:return
  for number in viewpoint[key]:
   if typeof(number) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)) or absf(float(number))>10000.:return
 var p:Array=viewpoint.player_position;var r:Array=viewpoint.player_rotation_radians;var h:Array=viewpoint.head_rotation_radians
 _player.global_position=Vector3(p[0],p[1],p[2]);_player.rotation=Vector3(r[0],r[1],r[2]);_player.get_node("Head").rotation=Vector3(h[0],h[1],h[2]);_player.velocity=Vector3.ZERO

func _exit_tree()->void:
 UIThemes.remove_theme_listener(_on_theme_changed)

func _on_theme_changed(_id:String,theme_data:Dictionary)->void:
 if is_instance_valid(_root_ui):
  _root_ui.theme=UIThemes.make_visual_lab_theme(theme_data)
 if is_instance_valid(_theme_picker):
  for i in _theme_picker.item_count:
   if str(_theme_picker.get_item_metadata(i))==theme_data.id:
    _theme_picker.select(i)
    break
 if is_instance_valid(_theme_desc):
  _theme_desc.text=theme_data.description
  _theme_desc.add_theme_color_override("font_color",theme_data.muted)
 if is_instance_valid(_lab_title_accent):
  _lab_title_accent.add_theme_color_override("font_color",theme_data.accent)
 if is_instance_valid(_keep_look_accent):
  _keep_look_accent.add_theme_color_override("font_color",theme_data.accent)
 if is_instance_valid(_theme_title_accent):
  _theme_title_accent.add_theme_color_override("font_color",theme_data.accent)
 if is_instance_valid(_panel):
  _panel.add_theme_stylebox_override("panel",UIThemes.flat_box(theme_data.bg_panel,theme_data.panel_border,14,12))

func _build_theme_ui()->void:
 if _tabs.get_child_count()<=4:return
 var column:VBoxContainer=_tabs.get_child(4).get_child(0)
 var box:=VBoxContainer.new();box.name="UIThemeSection";box.add_theme_constant_override("separation",6)
 column.add_child(box);column.move_child(box,0)
 var cur_theme:=UIThemes.get_current()
 _theme_title_accent=_label("UI COLOR THEME · 12 THEMES",11,cur_theme.accent);box.add_child(_theme_title_accent)
 var row:=_row();box.add_child(row)
 _theme_picker=OptionButton.new();_theme_picker.name="UIThemePicker";_theme_picker.size_flags_horizontal=Control.SIZE_EXPAND_FILL
 var all_themes:=UIThemes.get_all_themes()
 var current_id:=UIThemes.get_current_id()
 var selected_idx:=0
 for i in all_themes.size():
  var t:Dictionary=all_themes[i]
  var tag:String="["+t.roygbiv_letter+"] " if t.category=="ROYGBIV" else "★ "
  _theme_picker.add_item("%s%s"%[tag,t.name])
  _theme_picker.set_item_metadata(i,t.id)
  if t.id==current_id:selected_idx=i
 _theme_picker.select(selected_idx)
 _theme_picker.item_selected.connect(func(index:int):
  var tid:String=str(_theme_picker.get_item_metadata(index))
  UIThemes.set_theme(tid)
 )
 row.add_child(_theme_picker)
 var prev_btn:=_button("◀",func():UIThemes.cycle_theme(-1))
 prev_btn.tooltip_text="Previous UI Theme (F10)"
 var next_btn:=_button("▶",func():UIThemes.cycle_theme(1))
 next_btn.tooltip_text="Next UI Theme (F10)"
 row.add_child(prev_btn);row.add_child(next_btn)
 _theme_desc=_label(cur_theme.description,12,cur_theme.muted)
 _theme_desc.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
 box.add_child(_theme_desc)
 var hint:=_label("Shortcut: F10 cycles themes anywhere in-game.",11,cur_theme.muted)
 box.add_child(hint)
 var separator:=HSeparator.new();box.add_child(separator)
