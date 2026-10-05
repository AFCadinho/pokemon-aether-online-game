extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for path in ["res://assets/models/battle/substitute/substitute_doll.fbx", "res://assets/models/battle/pokeball/openable_pokeball.fbx"]:
		print("FILE=",path)
		var node := (load(path) as PackedScene).instantiate()
		root.add_child(node)
		for child in node.find_children("*", "", true, false):
			print(child.get_path(), " type=",child.get_class())
			if child is MeshInstance3D:
				print("bounds=",child.global_transform * child.get_aabb())
				for surface in child.mesh.get_surface_count():
					var mat = child.mesh.surface_get_material(surface)
					print("material=",mat.resource_name, " color=",mat.albedo_color," tex=", mat.albedo_texture.resource_path if mat is StandardMaterial3D and mat.albedo_texture else "missing")
			if child is AnimationPlayer:
				for key in child.get_animation_list():
					var anim: Animation = child.get_animation(key)
					print("ANIMATION=",key," seconds=",anim.length)
					for i in anim.get_track_count():
						if str(anim.track_get_path(i)) == "Skeleton3D:JOIN":
							for k in anim.track_get_key_count(i): print(anim.track_get_key_time(i,k), " -> ", anim.track_get_key_value(i,k))
		node.free()
	quit()
