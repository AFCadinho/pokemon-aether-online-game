extends "res://tests/battle_dialogue_preview.gd"
## Offline review: --moves [--capture-draco-camera] [--arena=sea] [--rain].

func _start() -> void:
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	await super._start()
	if not move_preview: return
	root.title = "PokeAether — Draco Meteor cinematic preview"
	move_picker.select(FIRST_MOVES.find("Draco Meteor"))
	status.text = "Draco Meteor: blauwe lucht tijdens het opladen en de gouden meteorregen."
	if "--capture-draco-camera" in OS.get_cmdline_user_args():
		await _capture_camera()

func _load_preview() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--arena="):
			var index := ARENAS.find(argument.trim_prefix("--arena="))
			assert(index >= 0, "Choose stadium, forest, cave or sea")
			arena.select(index)
	await super._load_preview()
	if "--rain" in OS.get_cmdline_user_args():
		battle.animation_router.model_presenter.set_weather_condition("RainDance")

func _capture_camera() -> void:
	var renderer: Node = battle.animation_router.model_presenter
	assert(renderer.active, renderer.reason)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for reverse in [false, true]:
		var original_environment: Environment = renderer.camera.environment
		move_reverse.button_pressed = reverse
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		var effect: Node = renderer.common_effects[0]
		for phase in [0.18, 0.39, 0.62, 0.74, 0.96]:
			while is_instance_valid(effect) and effect.elapsed < effect.duration * phase: await process_frame
			assert(is_instance_valid(effect) and not effect.done)
			battle.animation_router.playback_speed = 0.0
			await process_frame
			await process_frame
			if not output.is_empty() and DisplayServer.get_name() != "headless":
				toolbar.get_parent().hide()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("draco-camera-%s-%s.png" % [reverse, phase]))
				toolbar.get_parent().show()
			var pose: Transform3D = renderer.camera.transform
			var blue_strength: float = renderer.move_atmosphere.strength
			assert(blue_strength > 0.0 and renderer.camera.environment != original_environment)
			await create_timer(0.08).timeout
			assert(renderer.camera.transform.is_equal_approx(pose), "Pause holds the cinematic shot")
			assert(is_equal_approx(renderer.move_atmosphere.strength, blue_strength), "Pause holds the blue atmosphere")
			battle.animation_router.playback_speed = 1.0
		while move_busy: await process_frame
		assert(renderer.move_camera.effect == null and renderer.common_effects.is_empty())
		assert(renderer.move_atmosphere.effect == null and renderer.camera.environment == original_environment)
	print("DRACO_METEOR_CAMERA_PREVIEW_OK directions=2 charge=true ascent=true rain=true recovery=true pause=true blue_atmosphere=true environment_restored=true offline=true")
	host.release()
	host.queue_free()
	await process_frame
	quit()
