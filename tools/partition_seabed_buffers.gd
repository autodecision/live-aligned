extends "res://tools/compact_tree_buffers.gd"
## Keep potentially exposed shoals while omitting only guaranteed hidden floor.
const CUTOFF:float=-5.56 # Original sea trough -.16 plus four swells totaling .38.

func partition(source:Mesh,indices:PackedInt32Array,vertices:PackedVector3Array,label:String)->Dictionary:
 var surface:Dictionary=source.get("_surfaces")[0].duplicate(true)
 assert((surface.format&Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES)==0,"Preserve full-precision seabed positions")
 var bounds:=AABB(vertices[indices[0]],Vector3.ZERO)
 for i:int in indices:bounds=bounds.expand(vertices[i])
 surface.index_data=pack(indices,surface.vertex_count);surface.index_count=indices.size();surface.aabb=bounds
 var mesh:=ArrayMesh.new();mesh.resource_name=label;mesh.set("_surfaces",[surface])
 var path:String="res://assets/ocean_seabed_"+label+".res"
 assert(ResourceSaver.save(mesh,path,ResourceSaver.FLAG_COMPRESS)==OK)
 return compact(path)

func run()->void:
 var model:Node3D=load("res://assets/ocean_ground.glb").instantiate()
 var floor_mesh:MeshInstance3D=model.find_child("Ocean_Seabed",true,false)
 assert(floor_mesh.mesh.get_surface_count()==1)
 var arrays:Array=floor_mesh.mesh.surface_get_arrays(0)
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
 var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
 var deep:=PackedInt32Array();var shoals:=PackedInt32Array()
 for i:int in range(0,indices.size(),3):
  var top:float=maxf(vertices[indices[i]].y,maxf(vertices[indices[i+1]].y,vertices[indices[i+2]].y))
  var target:PackedInt32Array=shoals if top>=CUTOFF else deep
  target.append_array(indices.slice(i,i+3))
 assert(deep.size()+shoals.size()==indices.size())
 var report:Dictionary={"cutoff":CUTOFF,"original_triangles":indices.size()/3,"deep_triangles":deep.size()/3,"shoal_triangles":shoals.size()/3,
  "deep":partition(floor_mesh.mesh,deep,vertices,"deep"),"shoals":partition(floor_mesh.mesh,shoals,vertices,"shoals")}
 FileAccess.open("res://assets/seabed_buffer_partition.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 for name:String in ["deep","shoals"]:DirAccess.remove_absolute("res://assets/ocean_seabed_"+name+".res")
 print("SEABED_BUFFER_PARTITION_PASS ",JSON.stringify(report));model.free();quit()
