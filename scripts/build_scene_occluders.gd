extends SceneTree
# Build exact opaque occlusion geometry once, outside gameplay startup.
func _initialize() -> void: call_deferred("build")
func build() -> void:
	var source=load("res://assets/mediterranean_temple.glb").instantiate()
	root.add_child(source)
	var output:=Node3D.new();output.name="StaticOcclusion"
	var count:=0;var triangles:=0
	for mesh in source.find_children("*","MeshInstance3D",true,false):
		var name:=String(mesh.name)
		if not (name.begins_with("Cliff_Terrain") or name.begins_with("Distant_Islands") or name.begins_with("Temple_Cella_")): continue
		var vertices:=PackedVector3Array();var indices:=PackedInt32Array()
		for surface in mesh.mesh.get_surface_count():
			var arrays=mesh.mesh.surface_get_arrays(surface)
			var offset:=vertices.size()
			vertices.append_array(arrays[Mesh.ARRAY_VERTEX])
			var surface_indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
			if surface_indices.is_empty():
				for i in arrays[Mesh.ARRAY_VERTEX].size():indices.append(offset+i)
			else:
				for index in surface_indices:indices.append(offset+index)
		var shape:=ArrayOccluder3D.new();shape.set_arrays(vertices,indices)
		var instance:=OccluderInstance3D.new();instance.name=name+"_Occluder";instance.occluder=shape
		output.add_child(instance);instance.owner=output;instance.transform=mesh.global_transform
		count+=1;triangles+=indices.size()/3
	var packed:=PackedScene.new();assert(packed.pack(output)==OK)
	assert(ResourceSaver.save(packed,"res://assets/temple_static_occlusion.scn")==OK)
	print("OCCLUDERS_SAVED ",count," meshes, ",triangles," triangles")
	output.free();source.free();quit()
