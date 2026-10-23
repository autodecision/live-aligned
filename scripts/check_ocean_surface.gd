extends SceneTree
## Windowed validation of water animation, shared horizon shading and lighting.
const OUT := "/home/allister/Projects/live-aligned-previews/ocean-surface-2026-10-19/final/"
var main: Node3D
var camera: Camera3D
var water: Node3D
var changes := {}

func _initialize() -> void:
 call_deferred("run")

func shot(label: String, point: Vector3, target: Vector3, phase: float = .25, time: float = 12.0) -> Image:
 camera.position = point
 camera.look_at(target)
 main.get_node("DayNightCycle").set_phase(phase)
 water.set_water_time(time)
 for i in 25: await process_frame
 var horizon: ShaderMaterial = main.get_node("OceanGround").horizon_material
 assert(is_equal_approx(horizon.get_shader_parameter("water_time"), time), "Water/horizon phase differs")
 await RenderingServer.frame_post_draw
 var picture := root.get_texture().get_image()
 assert(picture.save_png(OUT + label + ".png") == OK)
 return picture

func changed_pixels(a: Image, b: Image) -> int:
 var changed := 0
 var first := a.get_data()
 var second := b.get_data()
 for i in range(0, first.size(), 4):
  if abs(int(first[i])-int(second[i]))+abs(int(first[i+1])-int(second[i+1]))+abs(int(first[i+2])-int(second[i+2])) > 18:
   changed += 1
 return changed

func run() -> void:
 assert(DisplayServer.get_name() != "headless", "This check needs the actual renderer")
 DirAccess.make_dir_recursive_absolute(OUT)
 root.size = Vector2i(1440,900)
 main = load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 var player = main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 player.visible = false
 player.get_node("CanvasLayer").hide()
 main.get_node("CharacterDialogue").hide()
 main.get_node("VisualLab").select_preset(0)
 main.get_node("VisualLab")._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 main.get_node("DayNightCycle").running = false
 main.get_node("DayNightCycle").set_phase(.25)
 for npc in main.get_node("IslandCharacters").get_children(): npc.set_physics_process(false)
 water = main.get_node("AnimatedWater")
 var start: float = water.elapsed
 for i in 12: await process_frame
 assert(water.elapsed > start, "Water clock stopped")
 water.set_process(false)
 assert(water.materials.size() == 13)
 var sea: ShaderMaterial = water.materials[water.water_mesh_names.find("Mediterranean_Sea")]
 var horizon: ShaderMaterial = main.get_node("OceanGround").horizon_material
 assert(sea.shader == horizon.shader, "Horizon must share all wave/shading equations")
 assert(sea.get_shader_parameter("contact_field") == horizon.get_shader_parameter("contact_field"))
 var texture: Texture2D = sea.get_shader_parameter("contact_field")
 var image := texture.get_image()
 assert(image.get_size() == Vector2i(1024,1024))
 var floor_samples := 0
 var solid_samples := 0
 for z in range(0,1024,4):
  for x in range(0,1024,4):
   var pixel := image.get_pixel(x,z)
   assert(pixel.r >= -20.0 and pixel.r <= -3.0 and pixel.g >= 0.0 and pixel.g <= 32.1,
    "Contact map lost signed height or metre distance")
   if pixel.r < -8.0: floor_samples += 1
   if pixel.g < .001: solid_samples += 1
 assert(floor_samples > 30000 and solid_samples > 1000)
 # Match all original sea boundary vertices to the independent horizon.
 var mesh: MeshInstance3D = main.get_node("OceanGround").find_child("Ocean_Horizon_Water",true,false)
 var points := {}
 for v: Vector3 in mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
  points[(mesh.global_transform*v).snapped(Vector3.ONE*.0001)] = true
 var matched := 0
 for edge: Array in JSON.parse_string(FileAccess.get_file_as_string("res://assets/ocean_horizon_edges.json")):
  for p: Array in edge:
   assert(points.has(Vector3(p[0],p[2],-p[1]).snapped(Vector3.ONE*.0001)))
   matched += 1
 # Keep the connected bowl, rill, waterfall and pool materials intact.
 for i in water.water_mesh_names.size():
  if water.water_mesh_names[i] == "Mediterranean_Sea": continue
  assert(water.materials[i].shader.resource_path in ["res://shaders/flowing_water.gdshader","res://shaders/outfall_volume.gdshader"])
 camera = Camera3D.new()
 main.add_child(camera)
 camera.current = true
 camera.fov = 70
 var views := [
  ["temple_shore",Vector3(18,1,17),Vector3(11,-4,7.5)],
  ["open_water",Vector3(36,3,5),Vector3(48,-5,23)],
  ["spectrum_rocks",Vector3(118,0,75),Vector3(130,-4.4,72)],
  ["horizon",Vector3(-48,-2,20),Vector3(-200,-5,20)],
  ["underwater",Vector3(63,-8,14),Vector3(60,-8.4,24)]
 ]
 for view in views:
  var first := await shot(view[0],view[1],view[2])
  if view[0] in ["temple_shore","open_water","spectrum_rocks"]:
   var second := await shot(view[0]+"_motion",view[1],view[2],.25,13.25)
   changes[view[0]] = changed_pixels(first,second)
   assert(changes[view[0]] > 5000,"Water must visibly animate: "+view[0])
 await shot("dusk",Vector3(36,3,5),Vector3(48,-5,23),.48)
 await shot("night",Vector3(36,3,5),Vector3(48,-5,23),.75)
 await shot("underwater_night",Vector3(63,-8,14),Vector3(60,-8.4,24),.75)
 main.get_node("RenderOptimization").set_performance_mode(true,false)
 await shot("performance",Vector3(36,3,5),Vector3(48,-5,23))
 var report := {"water_surfaces":13,"shared_ocean_shader":true,"horizon_edge_vertices":matched,
  "signed_depth_samples":floor_samples,"solid_contact_samples":solid_samples,"animated_pixels":changes,
  "lighting_views":["day","dusk","night","underwater_day","underwater_night"],"graphics_modes":["Balanced","Performance"]}
 FileAccess.open(OUT+"validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("OCEAN_SURFACE_PASS ",JSON.stringify(report))
 quit()
