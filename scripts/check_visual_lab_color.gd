extends SceneTree
const OUT:="/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/"
func _initialize()->void:call_deferred("run")
func snap(label:String)->void:
 for i in range(10):await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"lab_color_"+label+".png")
func run()->void:
 root.size=Vector2i(1280,900)
 var main=load("res://scenes/main.tscn").instantiate();root.add_child(main)
 var player=main.get_node("Player");player.set_physics_process(false);player.set_process_unhandled_input(false);player.get_node("CanvasLayer").hide()
 var water=main.get_node("AnimatedWater");water.set_process(false);water.set_water_time(0.)
 var lab=main.get_node("VisualLab");lab.select_preset(0);lab._launcher.hide()
 var camera:=Camera3D.new();main.add_child(camera);camera.current=true;camera.fov=65.;camera.global_position=Vector3(-3.5,7,17);camera.look_at(Vector3(-3.5,7.5,0))
 await snap("off")
 lab._post.show();await snap("full_identity")
 var shader:=Shader.new();shader.code="shader_type canvas_item; render_mode unshaded; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear; void fragment(){COLOR=textureLod(screen_texture,SCREEN_UV,0.0);}"
 var mat:=ShaderMaterial.new();mat.shader=shader;lab._post.material=mat
 await snap("copy")
 for key in lab.Profiles.POST_KEYS:print("LAB_UNIFORM ",key," ",lab._material.get_shader_parameter(key))
 quit()
