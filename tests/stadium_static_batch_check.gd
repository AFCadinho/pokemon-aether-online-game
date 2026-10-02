extends SceneTree
const Stadium = preload("res://scripts/battle/arenas/generic/stadium_arena.gd")
class Unbatched extends Stadium:
	func _batch_stand_boxes(_stand: Node3D) -> void:
		pass
func _init() -> void:
	var world := Node3D.new()
	var original := Unbatched.new(world).build()
	var batched := Stadium.new(world).build()
	var box_count := 0
	var batch_count := 0
	for side in 4:
		var before: Node3D = original.get_child(side + 1)
		var after: Node3D = batched.get_child(side + 1)
		assert(before.transform==after.transform)
		var expected: Array = []
		for node in before.get_children():
			if node is MeshInstance3D and node.mesh is BoxMesh:
				expected.append({"transform":node.transform,"color":node.material_override.albedo_color,"glow":node.material_override.emission_energy_multiplier,"mesh_size":node.mesh.size})
		for node in after.get_children():
			assert(not (node is MeshInstance3D and node.mesh is BoxMesh))
			if node is MultiMeshInstance3D:
				batch_count+=1
				assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
				for index in node.multimesh.instance_count:
					var actual := {"transform":node.multimesh.get_instance_transform(index),"color":node.material_override.albedo_color,"glow":node.material_override.emission_energy_multiplier,"mesh_size":node.multimesh.mesh.size}
					var match_index := -1
					for candidate_index in expected.size():
						var candidate: Dictionary = expected[candidate_index]
						if candidate.transform.is_equal_approx(actual.transform) and candidate.color==actual.color and candidate.glow==actual.glow and candidate.mesh_size==actual.mesh_size:
							match_index=candidate_index
							break
					assert(match_index>=0,"Batched box differs from original geometry/material")
					expected.remove_at(match_index)
					box_count+=1
		assert(expected.is_empty())
	assert(batch_count==16 and box_count>600)
	assert(original.get_node("StadiumAudience").get_child_count()==320)
	assert(batched.get_node("StadiumAudience").get_child_count()==320)
	original.free()
	batched.free()
	world.free()
	print("STADIUM_STATIC_BATCH_OK boxes=",box_count," batches=",batch_count," geometry_and_materials_preserved=true rigged_spectators=320")
	quit()
