extends Node3D
## One 600-second solar orbit: 300 seconds above and 300 below the horizon.
## Visual Lab values are composed with this clock instead of overwriting it.
const Profiles=preload("res://scripts/visual_lab_profiles.gd")
@export var cycle_seconds:float=600.0
@export_range(0.0,1.0) var phase:float=0.0
@export var running:bool=true
var look:Dictionary=Profiles.defaults()
var daylight:float=1.0
var lantern_strength:float=0.0
var _sun:DirectionalLight3D
var _moon:DirectionalLight3D
var _environment:Environment
var _sky:ProceduralSkyMaterial
var _base:Dictionary
var _clock_label:Label
var _clock_slider:HSlider
var _pause:CheckButton
var _accumulator:float=0.0
var _initialized:bool=false

func _ready()->void:
 var lab=get_parent().get_node("VisualLab")
 _sun=get_parent().get_node("MediterraneanSun")
 _environment=get_parent().get_node("WorldEnvironment").environment
 _sky=_environment.sky.sky_material
 _base=lab._base
 # Fast sky filtering avoids repeatedly rebuilding a 512px
 # importance-sampled reflection map as the sun moves.
 _environment.sky.process_mode=Sky.PROCESS_MODE_REALTIME
 _environment.sky.radiance_size=Sky.RADIANCE_SIZE_256
 _environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
 _environment.ambient_light_sky_contribution=0.0
 _moon=DirectionalLight3D.new();_moon.name="Moonlight"
 _moon.light_color=Color(.64,.75,1.0);_moon.shadow_enabled=false
 _moon.sky_mode=DirectionalLight3D.SKY_MODE_LIGHT_ONLY
 add_child(_moon)
 _build_clock_ui(lab)
 _initialized=true
 _apply_clock()

func set_look(values:Dictionary)->void:
 look=values.duplicate()
 if _initialized:_apply_clock()

func set_phase(value:float)->void:
 phase=fposmod(value,1.0)
 if _initialized:_apply_clock()

func clock_reference()->Dictionary:
 return {"phase":phase,"running":running,"cycle_seconds":cycle_seconds,"day_seconds":cycle_seconds*.5,"night_seconds":cycle_seconds*.5}

func _process(delta:float)->void:
 if not running:return
 phase=fposmod(phase+delta/maxf(cycle_seconds,1.0),1.0)
 _accumulator+=delta
 # A solar orbit takes ten minutes, so 10 Hz is visually continuous while
 # keeping sky/reflection updates and light-property traffic bounded.
 if _accumulator<.1:return
 _accumulator=fmod(_accumulator,.1)
 _apply_clock()

func _warm(color:Color,amount:float)->Color:
 return color.lerp(Color(1.0,.72,.4) if amount>0.0 else Color(.4,.7,1.0),absf(amount)*.45)

func _apply_clock()->void:
 var solar:float=sin(phase*TAU)
 daylight=smoothstep(-.1,.18,solar)
 lantern_strength=1.0-smoothstep(-.12,.22,solar)
 var dusk:float=(1.0-smoothstep(.05,.45,absf(solar)))*daylight
 var sun_factor:float=smoothstep(-.025,.2,solar)*(.25+.75*sqrt(maxf(0.0,solar)))
 _sun.rotation=Vector3(deg_to_rad(-look.sun_elevation*solar),deg_to_rad(look.sun_azimuth+(phase-.25)*360.0),0.0)
 _sun.light_energy=_base.sun_energy*look.sun_strength/1.4*sun_factor
 _sun.visible=_sun.light_energy>.0001
 _sun.light_color=_warm(_base.sun_color,look.sun_warmth).lerp(Color(1.0,.48,.20),dusk*.65)
 _moon.rotation=Vector3(deg_to_rad(-38.0*maxf(.12,-solar)),deg_to_rad(look.sun_azimuth+150.0),0.0)
 _moon.light_energy=.30*(1.0-smoothstep(-.1,.08,solar))*smoothstep(0.0,.35,-solar)*look.sun_strength/1.4
 _moon.visible=_moon.light_energy>.0001
 _environment.ambient_light_color=Color(.55,.64,.80).lerp(Color(.85,.92,1.0),daylight)
 _environment.ambient_light_energy=_base.ambient*look.ambient_fill/.6*lerpf(.34,1.0,daylight)
 _environment.fog_density=maxf(0.0,_base.fog_density+look.fog_density-.001)
 var fog_color:Color=Color(.035,.055,.095).lerp(_base.fog_color,daylight).lerp(Color(.65,.36,.24),dusk*.3)
 _environment.fog_light_color=_warm(fog_color,look.fog_warmth)
 _environment.fog_height=_base.fog_height+look.fog_height-2.0
 _environment.fog_height_density=_base.fog_height_density+look.height_haze
 var top:Color=Color(.006,.012,.034).lerp(_base.sky_top,daylight)
 var horizon:Color=Color(.035,.055,.105).lerp(_base.sky_horizon,daylight).lerp(Color(.84,.43,.26),dusk*.65)
 _sky.sky_top_color=_warm(top,look.sky_warmth)
 _sky.sky_horizon_color=_warm(horizon,look.sky_warmth)
 _sky.ground_bottom_color=Color(.012,.018,.028).lerp(Color(.12,.22,.32),daylight)
 _sky.ground_horizon_color=_sky.sky_horizon_color
 _sky.sky_energy_multiplier=_base.sky_energy*look.sky_brightness
 var lamps=get_parent().get_node_or_null("IslandLanterns")
 if lamps:lamps.set_night_strength(lantern_strength)
 var pagoda=get_parent().get_node_or_null("NorthPagoda")
 if pagoda:pagoda.set_night_strength(lantern_strength)
 var garden=get_parent().get_node_or_null("SouthGarden")
 if garden:garden.set_night_strength(lantern_strength)
 if is_instance_valid(_clock_label):
  var period:String="Day" if phase<.5 else "Night"
  if absf(solar)<.20:period="Dawn" if phase<.25 or phase>.75 else "Dusk"
  var seconds:int=int(phase*cycle_seconds)
  _clock_label.text="%s  ·  %02d:%02d / 10:00"%[period,seconds/60,seconds%60]
  _clock_slider.set_value_no_signal(phase)
  _pause.set_pressed_no_signal(not running)

func _build_clock_ui(lab:CanvasLayer)->void:
 var column:VBoxContainer=lab._tabs.get_child(1).get_child(0)
 var box:=VBoxContainer.new();box.name="WorldClock";box.add_theme_constant_override("separation",6)
 column.add_child(box);column.move_child(box,0)
 box.add_child(lab._label("WORLD CLOCK · 5 MIN DAY / 5 MIN NIGHT",11,lab.ACCENT))
 _clock_label=lab._label("",13);box.add_child(_clock_label)
 _clock_slider=HSlider.new();_clock_slider.name="TimeOfDay";_clock_slider.max_value=1.0;_clock_slider.step=.001
 _clock_slider.tooltip_text="Preview any time of day. The cycle continues unless paused."
 _clock_slider.value_changed.connect(set_phase);box.add_child(_clock_slider)
 var row:HBoxContainer=lab._row();box.add_child(row)
 for entry in [["Dawn",0.0],["Day",.25],["Dusk",.5],["Night",.75]]:
  row.add_child(lab._button(entry[0],set_phase.bind(entry[1])))
 _pause=CheckButton.new();_pause.name="PauseWorldClock";_pause.text="Pause";_pause.toggled.connect(func(value:bool):running=not value);row.add_child(_pause)
 var separator:=HSeparator.new();box.add_child(separator)
