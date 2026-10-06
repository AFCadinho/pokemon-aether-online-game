extends "res://tests/battle_dialogue_preview.gd"
func _start() -> void:
	left_species="Dragonite"
	await super._start()
	move_picker.clear();move_picker.add_item("Close Combat")
	root.title="PokeAether — Close Combat — 2D-combinatie in 3D"
	status.text="Close Combat: snelle aanloop, afwisselende slagen en een grote slotklap. Test ook ontwijken en de andere kant."
	print("CLOSE_COMBAT_PREVIEW_READY")
	if "--smoke-combo" in OS.get_cmdline_user_args():await _capture_combo()
func _capture_combo() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty());DirAccess.make_dir_recursive_absolute(output)
	var renderer=battle.animation_router.model_presenter
	for reverse in [false,true]:
		move_reverse.button_pressed=reverse;move_outcome.select(1 if reverse else 0)
		_preview_move()
		while renderer.common_effects.is_empty() and move_busy:await process_frame
		assert(not renderer.common_effects.is_empty())
		var effect: Node=renderer.common_effects[0]
		for frame in [2.,4.,6.,10.,14.,17.,21.,23.,28.5,31.,34.]:
			while is_instance_valid(effect) and effect.elapsed<effect.duration*frame/37.:await process_frame
			assert(is_instance_valid(effect))
			if reverse:
				battle.animation_router.playback_speed=0
				renderer.user_camera_yaw=.8
				await process_frame
				var before: float=effect.elapsed
				await create_timer(.1).timeout
				assert(is_equal_approx(before,effect.elapsed) and not effect.impact_drawn)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join(("reverse-" if reverse else "front-")+str(frame)+".png"))
			battle.animation_router.playback_speed=1
		while move_busy:await process_frame
		assert(renderer.common_effects.is_empty() and battle.animation_router.active_audio_nodes.is_empty())
		renderer.user_camera_yaw=0
	host.release();host.queue_free();host=null
	await process_frame;await process_frame
	print("CLOSE_COMBAT_RENDER_OK phases=22 directions=2 pause_orbit_miss=true")
	quit.call_deferred()
