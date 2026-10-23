extends "res://scripts/check_south_garden.gd"
## Check delivered overrides and actual walking clearance behind the temple.
func run()->void:
 Engine.physics_ticks_per_second=240
 Engine.time_scale=4.
 main=load("res://scenes/main.tscn").instantiate()
 root.add_child(main)
 player=main.get_node("Player")
 player.set_physics_process(false)
 player.set_process_unhandled_input(false)
 for npc in main.get_node("IslandCharacters").get_children():
  npc.set_physics_process(false)
  npc.position=Vector3(0,-100,0)
 await physics_frame
 var map:Node3D=main.get_node("TempleMap")
 var terrain:MeshInstance3D=map.get_node("Distant_Islands")
 var flat_sea_level_triangles:int=0
 for surface:int in terrain.mesh.get_surface_count():
  var arrays:=terrain.mesh.surface_get_arrays(surface)
  var verts:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  for i:int in range(0,indices.size(),3):
   var low:float=1000.
   var high:float=-1000.
   for j:int in 3:
    var p:Vector3=terrain.global_transform*verts[indices[i+j]]
    low=minf(low,p.y)
    high=maxf(high,p.y)
   if high-low<.02 and low> -5.30 and high< -4.7:flat_sea_level_triangles+=1
 assert(flat_sea_level_triangles==0,"Exposed flat shoreline apron")
 var water:Node3D=main.get_node("AnimatedWater")
 assert(water.materials.size()==13)
 var fall:MeshInstance3D=map.get_node("Sea_Connected_Fall")
 var material:ShaderMaterial=fall.get_surface_override_material(0)
 assert(material.shader.resource_path=="res://shaders/outfall_volume.gdshader")
 assert(water.get_node("OutfallImpactSpray").emitting)
 var lamp:Node3D=main.get_node("IslandLanterns/Coastal_Lantern_Main_05")
 assert(lamp.position.z< -18.,"Rear lamp still at plaza edge")
 for i:int in 24:
  var angle:float=float(i)*TAU/24.
  var p:Vector3=lamp.position+Vector3(cos(angle)*.245,0,sin(angle)*.245)
  var hit:=ray(p)
  assert(not hit.is_empty() and "Cliff_Terrain" in String(hit.collider.get_path()),"Lamp base is off the grass")
  assert(hit.position.y>=lamp.position.y-.01 and hit.position.y<lamp.position.y+.28,"Lamp base is floating or deeply buried")
 for z:float in [-15.8,-16.1]:
  var route:Array=[]
  for x:float in [-7.,-4.,-1.,1.]:
   var hit:=ray(Vector3(x,4.,z))
   assert(not hit.is_empty())
   route.append([x,hit.position.y,z])
  for reverse:bool in [false,true]:
   if not await walk(route,reverse):quit(1);return
 var report:={"rear_plaza_walks":walks,"flat_sea_level_triangles":flat_sea_level_triangles,"animated_water_surfaces":water.materials.size(),"lamp_grass_support_samples":24,"rounded_outflow_and_spray":true}
 FileAccess.open("/home/allister/Projects/live-aligned-previews/coast-outflow-2026-10-18/runtime_validation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("COAST_OUTFLOW_PASS ",JSON.stringify(report))
 quit()
