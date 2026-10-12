extends "res://tests/battle_dialogue_preview.gd"
## Offline review: --moves [--capture-draco-camera], optionally STAGE_OUTPUT.

func _start() -> void:
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	await super._start()
	if not move_preview: return
	root.title = "PokeAether — Draco Meteor camera"
	move_picker.select(FIRST_MOVES.find("Draco Meteor"))
	status.text = "Draco Meteor: opladen vóór de aanvaller, daarna meteorregen op de target."
	if "--capture-draco-camera" in OS.get_cmdline_user_args():
		await _capture_camera()

func _capture_camera() -> void:
	var renderer: Node = battle.animation_router.model_presenter
	assert(renderer.active, renderer.reason)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for reverse in [false, true]:
		move_reverse.button_pressed = reverse
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		var effect: Node = renderer.common_effects[0]
		for phase in [0.18, 0.39, 0.62, 0.96]:
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
			await create_timer(0.08).timeout
			assert(renderer.camera.transform.is_equal_approx(pose), "Pause holds the cinematic shot")
			battle.animation_router.playback_speed = 1.0
		while move_busy: await process_frame
		assert(renderer.move_camera.effect == null and renderer.common_effects.is_empty())
	print("DRACO_METEOR_CAMERA_PREVIEW_OK directions=2 charge=true ascent=true rain=true recovery=true pause=true offline=true")
	host.release()
	host.queue_free()
	await process_frame
	quit()
