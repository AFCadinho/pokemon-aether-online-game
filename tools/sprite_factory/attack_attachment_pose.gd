extends RefCounted
## Sample from the start so discrete mesh visibility matches forward playback.
## Seeking backwards can apply the wrong side of a discrete visibility key.
static func sample(player: AnimationPlayer, action: String, seconds: float) -> void:
	player.stop()
	player.play(action)
	player.seek(0.0, true)
	player.advance(seconds)
	player.pause()

static func meshes(actor: Node3D) -> Dictionary:
	var result := {}
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		var blends := []
		if mesh.mesh != null:
			for index in mesh.mesh.get_blend_shape_count(): blends.append(mesh.get_blend_shape_value(index))
		result[str(actor.get_path_to(mesh))] = {"visible":mesh.is_visible_in_tree(), "blend_shapes":blends}
	return result
