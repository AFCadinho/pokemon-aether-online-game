extends SceneTree
const Stadium = preload("res://scripts/battle/arenas/generic/stadium_arena.gd")
class Unbatched extends Stadium:
	func _batch_stand_boxes(_stand: Node3D) -> void:
		pass
	func _add_crowd_batches(parent: Node3D, source: MultiMesh, material: Material) -> void:
		var node := MultiMeshInstance3D.new()
		node.multimesh=source
		node.material_override=material
		node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(node)
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
	var crowd_nodes: Array = []
	for child in batched.get_children():
		if child is MultiMeshInstance3D:
			crowd_nodes.append(child)
	assert(crowd_nodes.size()==8)
	for kind in 2:
		var source: MultiMesh = original.get_child(original.get_child_count()-2+kind).multimesh
		for side in 4:
			var batch: MultiMesh = crowd_nodes[kind*4+side].multimesh
			assert(batch.instance_count==585)
			for index in 585:
				var previous := side*585+index
				assert(batch.get_instance_transform(index).is_equal_approx(source.get_instance_transform(previous)))
				assert(batch.get_instance_color(index)==source.get_instance_color(previous))
				assert(batch.get_instance_custom_data(index)==source.get_instance_custom_data(previous))
				var instance_bounds: AABB = batch.get_instance_transform(index)*batch.mesh.get_aabb()
				assert(batch.custom_aabb.encloses(instance_bounds.grow(0.5)))
	original.free()
	batched.free()
	world.free()
	print("STADIUM_STATIC_BATCH_OK boxes=",box_count," batches=",batch_count," geometry_and_materials_preserved=true crowd_instances=4680")
	quit()
