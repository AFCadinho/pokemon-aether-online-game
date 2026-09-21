extends "res://tools/sprite_factory/measure_model_grounding.gd"
## Before/after diagnostics only. Per-clip constant lift is NOT runtime policy.
func _run() -> void:
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	var catalog: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_3D_STAGE_REPORT")))
	var measured: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("POKEAETHER_GROUNDING_REVIEW_INPUT")))
	var output := OS.get_environment("POKEAETHER_POSE_REVIEW_OUTPUT")
	if not catalog is Array or not measured is Dictionary or not output.is_absolute_path() or DirAccess.dir_exists_absolute(output) or FileAccess.file_exists(output):
		printerr("Provide catalog, grounding review, and NEW output directory")
		quit(2)
		return
	if DirAccess.make_dir_recursive_absolute(output) != OK:
		quit(2)
		return
	var world := Node3D.new()
	root.add_child(world)
	review_camera = Camera3D.new()
	world.add_child(review_camera)
	review_camera.current = true
	preload("res://scripts/battle/battle_ui/material_response.gd").apply_neutral_lighting(world)
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(30, 30)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.35, 0.35, 0.35)
	floor_mesh.material_override = material
	world.add_child(floor_mesh)
	var notes := []
	for entry in catalog:
		var measurement: Dictionary = measured.get("entries", {}).get(entry.species, {})
		if measurement.is_empty() or measurement.get("sha256", "") != FileAccess.get_sha256(entry.runtime_path):
			failures.append(str(entry.species) + ": missing/stale measurement")
			continue
		var actor := (load(entry.runtime_path) as PackedScene).instantiate() as Node3D
		world.add_child(actor)
		actor.scale = Vector3.ONE * float(measurement.scale)
		actor.rotation.y = deg_to_rad(float(measurement.yaw_degrees))
		var player: AnimationPlayer = actor.find_children("*", "AnimationPlayer", true, false)[0]
		var skeletons := actor.find_children("*", "Skeleton3D", true, false)
		var meshes := actor.find_children("*", "MeshInstance3D", true, false)
		for action in measurement.clips:
			var clip: Dictionary = measurement.clips[action]
			if float(clip.clearance_with_idle_lift) >= 0.0 and action != "sleep":
				continue
			player.play(action)
			player.pause()
			actor.position.y = 0.0
			await _pose(player, skeletons, float(clip.minimum_time))
			var actual := _minimum(meshes)
			if absf(actual - float(clip.minimum_y)) > 0.002:
				failures.append(str(entry.species) + "/" + action + ": pose minimum does not reproduce")
				continue
			var candidate := maxf(0.0, 0.025 - actual)
			notes.append({"species": entry.species, "action": action, "time": clip.minimum_time,
				"idle_lift": measurement.candidate_lift, "diagnostic_clip_lift": candidate,
				"delta": candidate - float(measurement.candidate_lift)})
			for corrected in [false, true]:
				actor.position.y = candidate if corrected else float(measurement.candidate_lift)
				for angle in [0, 90, 180]:
					review_camera.position = Vector3(0, 2.5, 6).rotated(Vector3.UP, deg_to_rad(angle))
					review_camera.look_at(Vector3(0, 1.0, 0))
					await RenderingServer.frame_post_draw
					var name := str(entry.species).validate_filename() + "-" + str(action).validate_filename() + "-" + str(angle) + ("-candidate.png" if corrected else "-current.png")
					if root.get_texture().get_image().save_png(output.path_join(name)) != OK:
						failures.append("Could not save " + name)
		actor.free()
	var file := FileAccess.open(output.path_join("review.json"), FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify({"diagnostic_only": true, "poses": notes, "errors": failures}, "\t"))
	file.close()
	world.free()
	print("POSE_REVIEW_OK poses=", notes.size(), " errors=", failures.size())
	quit(0 if failures.is_empty() else 1)
