extends SceneTree
const OUT="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func run()->void:
 root.size=Vector2i(1280,900);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 main.get_node("RenderOptimization").set_performance_mode(false,false)
 var cycle=main.get_node("DayNightCycle");cycle.running=false;cycle.set_phase(.25)
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=75;camera.position=Vector3(50,6.75,19.7);camera.look_at(Vector3(0,3.7,15.7))
 var sun:DirectionalLight3D=main.get_node("MediterraneanSun");var rows:=[]
 for entry in [["baseline",1,.1],["two_rebalanced",1,.38],["four_splits",2,.20],["four_anisotropic",2,.20]]:
  sun.directional_shadow_mode=entry[1];sun.directional_shadow_split_1=entry[2];sun.directional_shadow_split_2=.45;sun.directional_shadow_split_3=.75
  if entry[0]=="four_anisotropic":
   for mesh in main.get_node("IslandBridges").find_children("*","MeshInstance3D",true,false):
    for i in mesh.mesh.get_surface_count():
     var mat=mesh.mesh.surface_get_material(i)
     if mat is StandardMaterial3D:mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
  var start:=Time.get_ticks_usec()
  while Time.get_ticks_usec()-start<1000000:await process_frame
  await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(OUT+"bridge_shadows_"+entry[0]+".png")
  var frames:=0;start=Time.get_ticks_usec()
  while Time.get_ticks_usec()-start<2500000:await process_frame;frames+=1
  var fps:float=frames*1000000./(Time.get_ticks_usec()-start);rows.append({"case":entry[0],"fps":fps});print("SHADOW_PROBE ",entry[0]," ",fps)
 FileAccess.open(OUT+"bridge_shadow_probe.json",FileAccess.WRITE).store_string(JSON.stringify(rows,"  "));quit()
