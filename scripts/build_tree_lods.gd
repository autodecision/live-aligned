extends SceneTree
func _initialize() -> void: call_deferred("build")
func decode_indices(bytes: PackedByteArray, vertex_count: int) -> PackedInt32Array:
	if vertex_count>65536: return bytes.to_int32_array()
	var indices:=PackedInt32Array();indices.resize(bytes.size()/2)
	for i in indices.size():indices[i]=bytes.decode_u16(i*2)
	return indices
func build() -> void:
	var source=load("res://assets/mediterranean_temple.glb").instantiate()
	var original: ArrayMesh
	for node in source.find_children("*","MeshInstance3D",true,false):
		if "Olive" in node.name: original=node.mesh;break
	assert(original!=null)
	var render_mesh:=ArrayMesh.new();var shadow_mesh:=ArrayMesh.new()
	var original_triangles:=0;var render_triangles:=0;var shadow_triangles:=0
	for i in original.get_surface_count():
		var data:Dictionary=RenderingServer.mesh_get_surface(original.get_rid(),i)
		var arrays=original.surface_get_arrays(i)
		original_triangles+=data.index_count/3
		var levels:Array=data.lods
		assert(levels.size()>=2)
		# Retain the first simplified foliage silhouette; trunks/branches need
		# fewer triangles than alpha-cutout leaf silhouettes at the same distance.
		var base_level:=0
		if i==2: base_level=1
		arrays[Mesh.ARRAY_INDEX]=decode_indices(levels[base_level].index_data,data.vertex_count)
		render_triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
		var lods:Dictionary={}
		# A fixed canopy preserves the leaf cards at every distance. Collapsing
		# those cards makes entire clusters appear as the camera approaches.
		if original.surface_get_material(i).resource_name != "island_tree_01_leaves":
			for j in range(base_level+1,levels.size()):
				lods[levels[j].edge_length]=decode_indices(levels[j].index_data,data.vertex_count)
		render_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],lods)
		render_mesh.surface_set_material(i,original.surface_get_material(i))
		arrays[Mesh.ARRAY_INDEX]=decode_indices(levels[1].index_data,data.vertex_count)
		shadow_triangles+=arrays[Mesh.ARRAY_INDEX].size()/3
		shadow_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		shadow_mesh.surface_set_material(i,original.surface_get_material(i))
	assert(ResourceSaver.save(render_mesh,"res://assets/olive_tree_render_lod.res")==OK)
	assert(ResourceSaver.save(shadow_mesh,"res://assets/olive_tree_shadow_lod.res")==OK)
	var report={"original_triangles_per_tree":original_triangles,"render_base_triangles_per_tree":render_triangles,"shadow_triangles_per_tree":shadow_triangles,"instances":91,"canopy":"fixed leaf geometry at every distance; native LODs on wood only"}
	FileAccess.open("/home/allister/Projects/mcp-for-blender/output/mediterranean_temple/improvements/tree_lod_optimization.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("TREE_LODS_SAVED ",JSON.stringify(report))
	source.free();quit()
