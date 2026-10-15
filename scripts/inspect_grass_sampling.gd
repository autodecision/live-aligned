extends SceneTree
func _initialize()->void:call_deferred("run")
func run()->void:
 var source=load("res://assets/original_grass.glb").instantiate()
 for mesh in source.find_children("*","MeshInstance3D",true,false):
  var surfaces:=[]
  for i in mesh.mesh.get_surface_count():
   var m:StandardMaterial3D=mesh.mesh.surface_get_material(i)
   var data:Dictionary=RenderingServer.mesh_get_surface(mesh.mesh.get_rid(),i)
   var levels:=[]
   for l in data.get("lods",[]):levels.append({"edge":l.edge_length,"bytes":l.index_data.size()})
   surfaces.append({"roughness":m.roughness,"specular":m.metallic_specular,"normal":m.normal_enabled,"normal_scale":m.normal_scale,"transparency":m.transparency,"alpha_coverage":m.alpha_antialiasing_mode,"vertices":data.vertex_count,"indices":data.index_count,"lods":levels})
  print("GRASS_SAMPLING ",mesh.name," ",JSON.stringify(surfaces))
 source.free();quit()
