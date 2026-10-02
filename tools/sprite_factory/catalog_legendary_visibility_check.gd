extends SceneTree
## Verify the source visibility keys in the reloaded standalone scenes.
func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var directory := OS.get_environment("POKEAETHER_LEGENDARY_WORK")
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(directory.path_join("runtime-v2/report.json")))
	var checks := 0
	for row: Dictionary in rows:
		assert(FileAccess.get_sha256(row.runtime_path) == row.runtime_sha256)
		var actor: Node = load(row.runtime_path).instantiate()
		root.add_child(actor)
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var meshes := {}
		for mesh in actor.find_children("*", "MeshInstance3D", true, false):
			meshes[str(mesh.name)] = mesh
		var actions: Array = row.visibility.clips.keys()
		actions.reverse()
		for action: String in actions:
			var clip: Dictionary = row.visibility.clips[action]
			var times := [0.0, float(clip.duration) * .5, float(clip.duration)]
			for track: Dictionary in clip.tracks:
				for key: Array in track.keys:
					times.append(minf(float(clip.duration), float(key[0]) + .0001))
			for time: float in times:
				player.stop()
				player.play(action)
				player.pause()
				player.seek(time, true)
				await process_frame
				for track: Dictionary in clip.tracks:
					var expected: bool = track.keys[0][1]
					for key: Array in track.keys:
						if float(key[0]) <= time:
							expected = key[1]
					assert(meshes[track.mesh].visible == expected, row.species + "/" + action + "/" + track.mesh)
					checks += 1
		actor.free()
	var report := {"models": rows.size(), "checks": checks, "errors": [], "policy": "reverse clip order; source key boundaries and endpoints"}
	var file := FileAccess.open(directory.path_join("visibility-check.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("LEGENDARY_VISIBILITY_OK models=", rows.size(), " checks=", checks)
	quit()
