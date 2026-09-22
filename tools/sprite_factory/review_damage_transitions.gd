extends SceneTree
## Read-only diagnosis through the actual summary playback/reset path.
const Preview = preload("res://scripts/ui/summary_model_preview.gd")
const SPECIES = ["garchomp", "azumarill", "flareon", "gardevoir", "forretress", "gyarados"]

func _initialize() -> void:
	_run.call_deferred()

func _pose(preview, clip: String, fraction: float) -> PackedVector3Array:
	preview.play_clip(clip)
	preview.player.seek(preview.player.get_animation(clip).length * fraction, true)
	preview.player.advance(0)
	preview.player.pause()
	var result := PackedVector3Array()
	for skeleton in preview.actor.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	# Skinning data used by bake_mesh is synchronized by the renderer, not seek().
	await process_frame
	await RenderingServer.frame_post_draw
	for mesh: MeshInstance3D in preview.actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				result.append(mesh.global_transform * vertex)
	return result

func _delta(a: PackedVector3Array, b: PackedVector3Array) -> float:
	assert(a.size() == b.size() and not a.is_empty())
	var maximum := 0.0
	for i in a.size():
		maximum = maxf(maximum, a[i].distance_to(b[i]))
	return maximum

func _bounds(points: PackedVector3Array) -> AABB:
	var box := AABB(points[0], Vector3.ZERO)
	for point in points:
		box = box.expand(point)
	return box

func _run() -> void:
	var output := OS.get_environment("DAMAGE_REVIEW_OUTPUT")
	assert(output.is_absolute_path() and not DirAccess.dir_exists_absolute(output))
	assert(DirAccess.make_dir_recursive_absolute(output) == OK)
	var settings = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = OS.get_environment("SUMMARY_MODEL_CATALOG")
	settings._manual_model_catalog_this_session = true
	var report := {"scope": "summary preview standalone models; no asset or runtime changes", "entries": []}
	for species in SPECIES:
		var preview = Preview.new()
		preview.size = Vector2(480, 360)
		root.add_child(preview)
		assert(preview.show_species(species, false))
		var deadline := Time.get_ticks_msec() + 30000
		while preview.configured_player == null and Time.get_ticks_msec() < deadline:
			await process_frame
		assert(preview.configured_player != null)
		preview.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var idle := await _pose(preview, "idle", 0)
		var height := maxf(_bounds(idle).size.y, 0.00001)
		var reference := []
		for fraction in [0.0, 0.25, 0.5, 0.999]:
			reference.append(await _pose(preview, "damage", fraction))
		assert(_delta(reference[0], reference[2]) > 0.000001, "measurement must detect moving damage pose")
		var checks := []
		for cycle in 3:
			for previous in preview.player.get_animation_list():
				if previous == "RESET":
					continue
				for i in 4:
					await _pose(preview, previous, 0.73)
					var actual := await _pose(preview, "damage", [0.0, 0.25, 0.5, 0.999][i])
					checks.append({"cycle": cycle, "previous": previous, "sample": i, "max_vertex_delta": _delta(reference[i], actual)})
				assert(_delta(idle, await _pose(preview, "idle", 0)) < 0.000001, "idle reset differs")
		var max_history_delta := 0.0
		for check in checks:
			max_history_delta = maxf(max_history_delta, check.max_vertex_delta)
		var entry := {"species": species, "damage_length": preview.player.get_animation("damage").length,
			"history_checks": checks, "max_history_vertex_delta": max_history_delta,
			"entry_max_vertex_delta_per_idle_height": _delta(idle, reference[0]) / height,
			"exit_max_vertex_delta_per_idle_height": _delta(idle, reference[3]) / height,
			"damage_start_min_y_delta_per_idle_height": (_bounds(reference[0]).position.y - _bounds(idle).position.y) / height}
		report.entries.append(entry)
		var atlas := Image.create(480 * 6, 360, false, Image.FORMAT_RGBA8)
		for i in 6:
			await _pose(preview, "idle" if i == 0 or i == 5 else "damage", 0.0 if i == 0 or i == 5 else [0.0, 0.25, 0.5, 0.999][i - 1])
			for frame in 3:
				await process_frame
			await RenderingServer.frame_post_draw
			var screenshot: Image = preview.viewport.get_texture().get_image()
			screenshot.resize(480, 360)
			atlas.blit_rect(screenshot, Rect2i(0, 0, 480, 360), Vector2i(i * 480, 0))
		assert(atlas.save_png(output.path_join(species + ".png")) == OK)
		print("DAMAGE_REVIEW ", species, " history=", max_history_delta, " entry/height=", entry.entry_max_vertex_delta_per_idle_height, " exit/height=", entry.exit_max_vertex_delta_per_idle_height)
		preview.queue_free()
		await process_frame
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("DAMAGE_TRANSITION_REVIEW_COMPLETE")
	quit()
