extends "res://tests/battle_dialogue_preview.gd"
## Offline review: --moves --capture-move-cameras [--arena=sea] [--caster=Blastoise]
## Narrow the review with --camera-moves=FlashCannon,HyperBeam (normalized names).
const CAMERA_MOVES := ["Moonblast", "Hyper Beam", "Solar Beam", "Focus Blast", "Shadow Ball", "Flash Cannon", "Electro Shot", "Pyro Ball", "Blizzard", "Hurricane", "Tera Starstorm"]

func _start() -> void:
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--caster="): left_species = argument.trim_prefix("--caster=")
	await super._start()
	if not move_preview: return
	root.title = "PokeAether — cinematic move camera preview"
	if "--capture-move-cameras" in OS.get_cmdline_user_args():
		await _capture_cameras()

func _load_preview() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--arena="):
			var index := ARENAS.find(argument.trim_prefix("--arena="))
			assert(index >= 0, "Choose stadium, forest, cave or sea")
			arena.select(index)
	await super._load_preview()

func _capture_cameras() -> void:
	var renderer: Node = battle.animation_router.model_presenter
	assert(renderer.active, renderer.reason)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	var selected_moves: PackedStringArray = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--camera-moves="):
			selected_moves = argument.trim_prefix("--camera-moves=").to_lower().split(",")
	var reviewed := 0
	for move in CAMERA_MOVES:
		if not selected_moves.is_empty() and move.to_lower().replace(" ", "") not in selected_moves: continue
		reviewed += 1
		for i in move_picker.item_count:
			if move_picker.get_item_text(i) == move: move_picker.select(i)
		assert(move_picker.get_item_text(move_picker.selected) == move)
		for reverse in [false, true]:
			var original_environment: Environment = renderer.camera.environment
			move_reverse.button_pressed = reverse
			_preview_move()
			var deadline := Time.get_ticks_msec() + 15000
			while renderer.common_effects.is_empty():
				assert(Time.get_ticks_msec() < deadline, move + " effect did not start")
				await process_frame
			var effect: Node = renderer.common_effects[0]
			var samples := [effect.launch * 0.75, lerpf(effect.launch, effect.impact, 0.65), lerpf(effect.impact, effect.duration, 0.12)]
			for sample_index in samples.size():
				while is_instance_valid(effect) and effect.elapsed < samples[sample_index]:
					assert(Time.get_ticks_msec() < deadline, move + " playback stalled")
					await process_frame
				assert(is_instance_valid(effect) and not effect.done)
				battle.animation_router.playback_speed = 0.0
				await process_frame
				await process_frame
				if not output.is_empty() and DisplayServer.get_name() != "headless":
					toolbar.get_parent().hide()
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("%s-%s-%d.png" % [effect.key, reverse, sample_index]))
					toolbar.get_parent().show()
				var pose: Transform3D = renderer.camera.transform
				await create_timer(0.08).timeout
				assert(renderer.camera.transform.is_equal_approx(pose), move + " pause holds camera")
				assert(renderer.camera.environment == original_environment and renderer.move_atmosphere.effect == null)
				battle.animation_router.playback_speed = 1.0
			while move_busy:
				assert(Time.get_ticks_msec() < deadline, move + " recovery stalled")
				await process_frame
			assert(renderer.move_camera.effect == null and renderer.common_effects.is_empty())
			print("MOVE_CAMERA_PREVIEW ", move, " reverse=", reverse)
	assert(reviewed > 0, "No matching camera moves")
	print("MOVE_CAMERA_CHOREOGRAPHY_PREVIEW_OK moves=", reviewed, " directions=2 charge=true flight=true impact=true pause=true recovery=true offline=true")
	host.release()
	host.queue_free()
	await process_frame
	quit()
