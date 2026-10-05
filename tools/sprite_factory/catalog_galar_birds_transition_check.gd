extends SceneTree
## Candidate-only: check clip switches without resetting the previous pose.

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _pose(actor: Node) -> Array:
	var result := []
	for skeleton: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
		for index in skeleton.get_bone_count():
			result.append(skeleton.get_bone_pose(index))
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		result.append(mesh.visible)
		for surface in mesh.mesh.get_surface_count():
			var material: Material = mesh.get_active_material(surface)
			while material != null:
				if material is StandardMaterial3D:
					result.append(material.uv1_scale)
					result.append(material.uv1_offset)
				material = material.next_pass
	return result

func _equal(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for i in a.size():
		if a[i] is bool:
			if a[i] != b[i]: return false
		elif not a[i].is_equal_approx(b[i]):
			return false
	return true

func _run() -> void:
	var report_path := OS.get_environment("POKEAETHER_GALAR_RUNTIME")
	var output := OS.get_environment("POKEAETHER_GALAR_TRANSITIONS")
	var rows: Array = JSON.parse_string(FileAccess.get_file_as_string(report_path))
	assert(rows.size() == 6 and output.is_absolute_path())
	var checked := []
	for entry: Dictionary in rows:
		assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
		var scene := load(entry.runtime_path) as PackedScene
		assert(scene != null and ResourceLoader.get_dependencies(entry.runtime_path).is_empty())
		var actor := scene.instantiate()
		root.add_child(actor)
		await process_frame
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var reference := {}
		for action: String in entry.animations:
			player.stop()
			for skeleton: Skeleton3D in actor.find_children("*", "Skeleton3D", true, false):
				skeleton.reset_bone_poses()
			player.play(action)
			player.seek(player.get_animation(action).length * 0.5, true)
			player.pause()
			reference[action] = _pose(actor)
		var switches := 0
		for previous: String in entry.animations:
			for following: String in entry.animations:
				player.play(previous)
				player.seek(player.get_animation(previous).length * 0.8, true)
				player.play(following, 0.0)
				player.seek(player.get_animation(following).length * 0.5, true)
				player.pause()
				if not _equal(reference[following], _pose(actor)):
					failures.append(entry.species + ": " + previous + " -> " + following)
				switches += 1
		# The actual idle/sleep blend must converge to the same endpoint without
		# resetting bones or material UVs between flight and grounded rest.
		for pair: Array in [["idle", "sleep"], ["sleep", "idle"]]:
			player.play(pair[0], 0.0)
			player.advance(0.1)
			player.play(pair[1], 0.2)
			for frame in 30:
				player.advance(1.0 / 60.0)
			player.seek(player.get_animation(pair[1]).length * 0.5, true)
			player.pause()
			if not _equal(reference[pair[1]], _pose(actor)):
				failures.append(entry.species + ": blended " + str(pair))
		checked.append({"species": entry.species, "runtime_sha256": entry.runtime_sha256,
			"switches": switches, "flight_sleep_blends": 2})
		# Flush visibility before releasing animated material passes. Otherwise
		# Compatibility may still process their queued render dependencies.
		actor.visible = false
		await process_frame
		RenderingServer.force_draw(false)
		actor.queue_free()
		await process_frame
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"runtime_approved": false, "entries": checked,
		"failures": failures, "scope": "pose and material state; battle floor calibration remains separate"}, "  "))
	print("GALAR_TRANSITIONS_CHECK ", checked.size(), " models; failures=", failures)
	quit(0 if failures.is_empty() else 1)
