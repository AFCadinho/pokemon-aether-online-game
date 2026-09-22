extends "res://tools/sprite_factory/review_damage_transitions.gd"
const Summary = preload("res://scripts/ui/summary_model_preview.gd")
const Stage = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func vertices(actor: Node) -> PackedVector3Array:
	for skeleton in actor.find_children("*", "Skeleton3D", true, false):
		skeleton.force_update_all_bone_transforms()
	await process_frame
	await RenderingServer.frame_post_draw
	var points := PackedVector3Array()
	for mesh: MeshInstance3D in actor.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var posed: Mesh = mesh.bake_mesh_from_current_skeleton_pose() if mesh.skin != null else mesh.mesh
		for surface in posed.get_surface_count():
			for vertex: Vector3 in posed.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				points.append(mesh.global_transform * vertex)
	return points

func _run() -> void:
	var report: Array = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("CANDIDATE_REPORT")))
	assert(report.size() == 1)
	var entry: Dictionary = report[0]
	assert(entry.species == "garchomp" and not entry.runtime_approved)
	assert(FileAccess.get_sha256(entry.runtime_path) == entry.runtime_sha256)
	var preview := Summary.new()
	preview.size = Vector2(640, 480)
	root.add_child(preview)
	# Explicit test-only injection; no production admission/registry changes.
	preview.profile = {"placement": {"scale": 1.0}}
	assert(preview._request_model(entry.runtime_path))
	var deadline := Time.get_ticks_msec() + 30000
	while preview.configured_player == null and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(preview.configured_player != null)
	preview.player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var idle := await _pose(preview, "idle", 0)
	var height := _bounds(idle).size.y
	var damage := await _pose(preview, "damage", 0.5)
	assert(_delta(idle, damage) / height > 0.1)
	var damage_end := await _pose(preview, "damage", 0.999)
	assert(_delta(idle, damage_end) / height < 0.002)
	var attack_start := await _pose(preview, "physical_attack", 0)
	assert(_delta(idle, attack_start) / height < 0.002)
	var faint_start := await _pose(preview, "faint_start", 0)
	assert(_delta(idle, faint_start) / height < 0.002)
	assert(is_equal_approx(preview.player.get_animation("faint_start").length, 100.0 / 60.0))
	var comparisons := 0
	for cycle in 3:
		for previous in preview.player.get_animation_list():
			if previous == "RESET":
				continue
			await _pose(preview, previous, 0.73)
			assert(_delta(damage, await _pose(preview, "damage", 0.5)) / height < 0.00001)
			comparisons += 1
	var stage := Stage.new()
	root.add_child(stage)
	stage.setup()
	stage.set_process(false)
	stage.active = true
	stage.entries["garchomp"] = entry
	stage.combatants[0] = {"species": "garchomp", "shiny": false}
	stage.identities[0] = "garchomp"
	stage.actors[0] = preview.actor
	stage.players[0] = preview.player
	for cycle in 3:
		for previous in preview.player.get_animation_list():
			# In battle faint is terminal until replacement; summary permits scrubbing.
			if previous in ["RESET", "faint_start", "faint_loop"]:
				continue
			stage.lifecycle[0] = "idle"
			stage._action("reset", 0)
			stage.start_action("p1a", previous)
			preview.player.seek(preview.player.get_animation(previous).length * 0.73, true)
			preview.player.advance(0)
			stage.start_action("p1a", "damage")
			preview.player.seek(preview.player.get_animation("damage").length * 0.5, true)
			preview.player.advance(0)
			var difference := _delta(damage, await vertices(preview.actor)) / height
			if difference >= 0.00001:
				printerr("BATTLE_HISTORY_DIFFERENCE previous=", previous, " cycle=", cycle, " delta/height=", difference)
				quit(1)
				return
			comparisons += 1
	stage.play_action("p1a", "faint_start")
	for frame in 120:
		preview.player.advance(1.0 / 60.0)
		await process_frame
		if stage.current_actions[0] == "faint_loop":
			break
	assert(stage.current_actions[0] == "faint_loop" and stage.lifecycle[0] == "fainted")
	assert(preview.actor.visible)
	stage.start_action("p1a", "damage")
	assert(stage.current_actions[0] == "faint_loop", "faint loop must persist until replacement")
	# The real stage replaces actors with a fresh instance; it does not revive
	# a partially evaluated faint pose. Keep the summary actor for the capture.
	stage.actors[0] = null
	stage.players[0] = null
	for cycle in 3:
		var replacement: Node3D = load(entry.runtime_path).instantiate()
		preview.world.add_child(replacement)
		stage.actors[0] = replacement
		stage.players[0] = replacement.find_children("*", "AnimationPlayer", true, false)[0]
		stage.players[0].callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		stage.identities[0] = "garchomp"
		stage.lifecycle[0] = "idle"
		stage._action("reset", 0)
		stage.players[0].advance(0)
		stage.start_action("p1a", "damage")
		stage.players[0].seek(stage.players[0].get_animation("damage").length * 0.5, true)
		stage.players[0].advance(0)
		assert(_delta(damage, await vertices(replacement)) / height < 0.00001)
		stage._clear_actors()
		await process_frame
	stage.active = false
	stage.queue_free()
	preview.play_clip("idle")
	var capture := OS.get_environment("CANDIDATE_CAPTURE")
	if not capture.is_empty():
		var atlas := Image.create(640 * 4, 480, false, Image.FORMAT_RGBA8)
		for i in 4:
			await _pose(preview, "idle" if i == 0 else "damage", [0.0, 0.0, 0.5, 0.999][i])
			await RenderingServer.frame_post_draw
			var frame := preview.viewport.get_texture().get_image()
			frame.resize(640, 480)
			atlas.blit_rect(frame, Rect2i(0, 0, 640, 480), Vector2i(i * 640, 0))
		assert(atlas.save_png(capture) == OK)
	print("GARCHOMP_CANDIDATE_OK summary+battle comparisons=", comparisons, " damage_end/height=", _delta(idle, damage_end) / height, " faint=100/60s; persistent loop; 3 fresh replacements")
	preview.queue_free()
	await process_frame
	quit()
