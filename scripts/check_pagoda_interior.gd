extends 'res://scripts/check_south_garden.gd'
## Physical approach lanes, cushion support, and the bowl's shared flow seam.
func local_point(x:float,y:float,z:float)->Vector3:
 var c:float=cos(-.88);var s:float=sin(-.88)
 return Vector3(92+c*x-s*y,5.5+z,-64-s*x-c*y)
func edge_points(mesh:MeshInstance3D)->Array[Vector3]:
 var result:Array[Vector3]=[]
 for i:int in mesh.mesh.get_surface_count():
  var vertices:PackedVector3Array=mesh.mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX]
  for v:Vector3 in vertices:
   var p:Vector3=mesh.global_transform*v
   if absf(p.z+2.23)<.00001:result.append(p)
 return result
func run()->void:
 Engine.physics_ticks_per_second=240
 Engine.time_scale=4.0
 main=load('res://scenes/main.tscn').instantiate()
 root.add_child(main)
 player=main.get_node('Player')
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 for npc in main.get_node('IslandCharacters').get_children():
  npc.set_physics_process(false)
  npc.position=Vector3(0,-100,0)
 await physics_frame
 var map:Node3D=main.get_node('TempleMap')
 for label:String in ['Lab_Sofa_Ivory_Pillow','Lab_Sofa_Ochre_Pillow']:
  var pillow:MeshInstance3D=map.get_node(label)
  var bounds:AABB=pillow.global_transform*pillow.get_aabb()
  assert(bounds.size.y>.55 and bounds.size.x>.25,'Cushions are still flat blocks')
  var lowest:float=INF
  for surface:int in pillow.mesh.get_surface_count():
   var vertices:PackedVector3Array=pillow.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
   for v:Vector3 in vertices:lowest=minf(lowest,(pillow.global_transform*v).y)
  assert(absf(lowest-5.137)<.002,'Cushion does not rest on seat')
  var has_cloth:=false
  for i:int in pillow.mesh.get_surface_count():
   var mat:StandardMaterial3D=pillow.mesh.surface_get_material(i)
   has_cloth=has_cloth or mat.albedo_texture!=null
  assert(has_cloth,'Missing woven fabric')
  for shape:CollisionShape3D in pillow.find_children('*','CollisionShape3D',true,false):assert(shape.disabled)
 var outlet:MeshInstance3D=map.get_node('Bowl_Overflow_Surface')
 var fall:MeshInstance3D=map.get_node('Bowl_Overflow_Stream')
 var top:Array[Vector3]=edge_points(outlet)
 var bottom:Array[Vector3]=edge_points(fall)
 assert(top.size()>=40 and bottom.size()>=40,'Missing shared outlet ring')
 # Godot quantizes each imported surface within its own bounds (~12 microns).
 var seam_gap:float=0.0
 for p:Vector3 in top:
  var distance:float=INF
  for q:Vector3 in bottom:distance=minf(distance,p.distance_to(q))
  seam_gap=maxf(seam_gap,distance)
 assert(seam_gap<.00003,'Water seam is disconnected')
 var aw:Node=main.get_node('AnimatedWater')
 assert(aw.materials.size()==13)
 for name:String in ['Bowl_Overflow_Surface','Bowl_Overflow_Stream']:
  var mat:ShaderMaterial=aw.materials[aw.water_mesh_names.find(name)]
  assert(mat.shader.resource_path=='res://shaders/outfall_volume.gdshader')
  assert(is_equal_approx(mat.get_shader_parameter('fold_amplitude'),.12))
  aw.set_water_time(2.35)
  assert(is_equal_approx(mat.get_shader_parameter('water_time'),2.35))
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string('res://assets/pagoda_interior.json'))
 var interior:Node3D=main.get_node('NorthPagoda/InteriorFurnishings')
 assert(interior.find_children('*','MeshInstance3D',true,false).size()==3)
 assert(interior.get_node('FurnitureCollision').get_child_count()==data.colliders.size())
 # The main aisle and the lane approaching each furnishing remain walkable.
 for floor_z:float in [1.0,5.4,9.8]:
  var route:Array=[]
  for p:Vector2 in [Vector2(3.2,-3.25),Vector2(3.2,3.25),Vector2(-3.2,3.25),Vector2(-3.2,-3.25)]:
   var v:Vector3=local_point(p.x,p.y,floor_z)
   route.append([v.x,v.y,v.z])
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 for route:Array in [
  [[-3.05,4.53,-6.6],[-3.05,4.53,-8],[-3.05,4.53,-9.4]],
  [[3.45,3.55,-5.5],[3.45,3.55,-7.0],[3.45,3.55,-8.0]]]:
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 print('PAGODA_INTERIOR_PASS ',JSON.stringify({'furnished_floors':3,'physical_walks':walks,'cushions_seated':2,'outlet_seam_samples':top.size(),'seam_quantization_m':seam_gap,'water_surfaces':13}))
 quit()
