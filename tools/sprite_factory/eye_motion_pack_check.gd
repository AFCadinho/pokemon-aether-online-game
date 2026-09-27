extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_EYE_MOTION_REPORT")))
	var checked := 0
	for row: Dictionary in rows:
		var actor: Node3D = load(row.runtime_path).instantiate()
		root.add_child(actor)
		await process_frame
		var player: AnimationPlayer = actor.find_children("*","AnimationPlayer",true,false)[0]
		for clip in ["idle","sleep","physical_attack","faint_loop","idle"]:
			player.play(clip)
			player.seek(player.get_animation(clip).length*0.5,true)
			for spec: Dictionary in row.eye_motion.materials:
				for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
					for surface in mesh.mesh.get_surface_count():
						var mat := mesh.get_active_material(surface) as StandardMaterial3D
						if mat.resource_name != spec.material: continue
						var names := ["UVScaleOffset"]
						if spec.lids.size()==2: names.append_array(["UVScaleOffset3","UVScaleOffset4"])
						for parameter in names:
							assert(mat != null)
							var keys: Array = spec.clips[clip].parameters[parameter]
							# Constant hold/idle clips must seek and reset exactly.
							if keys.all(func(k): return k[1]==keys[0][1]):
								var uv: Array = keys[0][1]
								assert(mat.uv1_scale.is_equal_approx(Vector3(uv[0],uv[1],1)))
								assert(mat.uv1_offset.is_equal_approx(Vector3(uv[2],uv[3],0)))
								checked += 1
							mat = mat.next_pass as StandardMaterial3D
		var other: Node3D = load(row.runtime_path).instantiate()
		root.add_child(other)
		var other_player: AnimationPlayer = other.find_children("*","AnimationPlayer",true,false)[0]
		other_player.play("idle")
		other_player.advance(0)
		player.play("sleep")
		player.advance(0)
		await process_frame
		await process_frame
		for mesh: MeshInstance3D in actor.find_children("*","MeshInstance3D",true,false):
			var sibling: MeshInstance3D = other.get_node(actor.get_path_to(mesh))
			for surface in mesh.mesh.get_surface_count():
				var material := mesh.get_active_material(surface)
				if material.resource_name not in ["l_eye","r_eye"]: continue
				var peer := sibling.get_active_material(surface)
				while material != null:
					assert(peer != null and material != peer)
					checked += 1
					material = material.next_pass
					peer = peer.next_pass
		other.queue_free()
		actor.queue_free()
		await process_frame
		await process_frame
	print("EYE_MOTION_RELOAD_AND_SEEK_OK checks=",checked)
	quit(0)
