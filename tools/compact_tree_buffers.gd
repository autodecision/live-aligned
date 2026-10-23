extends SceneTree
## Repack unused imported vertices without changing a rendered triangle or LOD.
const OUTPUT="res://assets/"
func _initialize()->void:call_deferred("run")

func unpack(bytes:PackedByteArray,count:int)->PackedInt32Array:
 var result:=PackedInt32Array();result.resize(bytes.size()/(2 if count<=65536 else 4))
 for i:int in result.size():result[i]=bytes.decode_u16(i*2) if count<=65536 else bytes.decode_u32(i*4)
 return result

func pack(indices:PackedInt32Array,count:int)->PackedByteArray:
 var result:=PackedByteArray();result.resize(indices.size()*(2 if count<=65536 else 4))
 for i:int in indices.size():
  if count<=65536:result.encode_u16(i*2,indices[i])
  else:result.encode_u32(i*4,indices[i])
 return result

func copy_stream(bytes:PackedByteArray,offset:int,stride:int,used:PackedInt32Array)->PackedByteArray:
 var result:=PackedByteArray();result.resize(used.size()*stride)
 for i:int in used.size():
  for b:int in stride:result[i*stride+b]=bytes[offset+used[i]*stride+b]
 return result

func compact(path:String)->Dictionary:
 var original:ArrayMesh=load(path)
 var surfaces:Array=original.get("_surfaces")
 var reports:Array=[]
 for s:int in surfaces.size():
  var surface:Dictionary=surfaces[s].duplicate(true)
  var count:int=surface.vertex_count
  var indices:PackedInt32Array=unpack(surface.index_data,count)
  var lods:Array=surface.get("lods",[])
  var used_flags:=PackedByteArray();used_flags.resize(count)
  for index:int in indices:used_flags[index]=1
  for l:int in range(1,lods.size(),2):
   for index:int in unpack(lods[l],count):used_flags[index]=1
  var used:=PackedInt32Array()
  var remap:=PackedInt32Array();remap.resize(count)
  for i:int in count:
   if used_flags[i]:remap[i]=used.size();used.append(i)
  var vertex_stride:int=RenderingServer.mesh_surface_get_format_vertex_stride(surface.format,count)
  var normal_stride:int=RenderingServer.mesh_surface_get_format_normal_tangent_stride(surface.format,count)
  var attribute_stride:int=RenderingServer.mesh_surface_get_format_attribute_stride(surface.format,count)
  assert(surface.vertex_data.size()==count*(vertex_stride+normal_stride),"Unexpected packed vertex layout")
  var data:PackedByteArray=copy_stream(surface.vertex_data,0,vertex_stride,used)
  data.append_array(copy_stream(surface.vertex_data,count*vertex_stride,normal_stride,used))
  surface.vertex_data=data
  if surface.has("attribute_data"):
   assert(surface.attribute_data.size()==count*attribute_stride)
   surface.attribute_data=copy_stream(surface.attribute_data,0,attribute_stride,used)
  var new_indices:=PackedInt32Array();new_indices.resize(indices.size())
  for i:int in indices.size():new_indices[i]=remap[indices[i]]
  surface.index_data=pack(new_indices,used.size())
  for l:int in range(1,lods.size(),2):
   var old_lod:PackedInt32Array=unpack(lods[l],count)
   var next:=PackedInt32Array();next.resize(old_lod.size())
   for i:int in old_lod.size():next[i]=remap[old_lod[i]]
   lods[l]=pack(next,used.size())
  if not lods.is_empty():surface.lods=lods
  surface.vertex_count=used.size()
  surfaces[s]=surface
  reports.append({"surface":s,"old_vertices":count,"new_vertices":used.size(),"triangles":indices.size()/3,"lods":lods.size()/2,"position_stride":vertex_stride,"normal_stride":normal_stride})
 var result:=ArrayMesh.new();result.resource_name=original.resource_name
 result.set("_surfaces",surfaces)
 result.custom_aabb=original.custom_aabb
 # Decoded attributes at every corner must be bit-identical after repacking.
 for s:int in result.get_surface_count():
  var before:Array=original.surface_get_arrays(s);var after:Array=result.surface_get_arrays(s)
  var before_indices:PackedInt32Array=before[Mesh.ARRAY_INDEX]
  var after_indices:PackedInt32Array=after[Mesh.ARRAY_INDEX]
  assert(before_indices.size()==after_indices.size())
  for attribute:int in [Mesh.ARRAY_VERTEX,Mesh.ARRAY_NORMAL,Mesh.ARRAY_COLOR,Mesh.ARRAY_TEX_UV,Mesh.ARRAY_TEX_UV2]:
   if before[attribute]==null or before[attribute].is_empty():continue
   for i:int in before_indices.size():assert(before[attribute][before_indices[i]]==after[attribute][after_indices[i]],"Changed vertex attribute")
 var output:String=path.trim_suffix(".res")+"_compact.res"
 assert(ResourceSaver.save(result,output,ResourceSaver.FLAG_COMPRESS)==OK)
 return {"source":path,"output":output,"surfaces":reports,"identical_triangle_attributes":true}

func run()->void:
 var report:Array=[]
 for file:String in ["olive_tree_render_lod.res","olive_tree_shadow_lod.res"]:report.append(compact(OUTPUT+file))
 FileAccess.open(OUTPUT+"tree_buffer_compaction.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("TREE_BUFFER_COMPACTION_PASS ",JSON.stringify(report));quit()
