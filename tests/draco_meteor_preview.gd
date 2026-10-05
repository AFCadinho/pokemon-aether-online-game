extends "res://tests/battle_dialogue_preview.gd"
func _start() -> void:
	left_species = "Dragonite"
	await super._start()
	move_picker.select(FIRST_MOVES.find("Draco Meteor"))
	root.title = "PokeAether — Draco Meteor"
	status.text = "Draco Meteor: opladen, opstijgen, meteorietenregen. Test ook ontwijken en draai de camera."
	print("DRACO_METEOR_PREVIEW_READY")
	if "--smoke-draco" in OS.get_cmdline_user_args(): await _check_draco()
func _check_draco() -> void:
	create_timer(90).timeout.connect(func(): printerr("DRACO_PREVIEW_TIMEOUT"); quit(1))
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	for reverse in [false,true]:
		for outcome in 3:
			move_reverse.button_pressed = reverse
			move_outcome.select(outcome)
			_preview_move()
			var renderer = battle.animation_router.model_presenter
			while renderer.common_effects.is_empty(): await process_frame
			var effect: Node = renderer.common_effects[0]
			for phase in [["charge",0.16],["rise",0.34],["split",0.435],["rain",0.60],["impact",0.735]]:
				while is_instance_valid(effect) and effect.elapsed<effect.duration*float(phase[1]): await process_frame
				assert(is_instance_valid(effect))
				if not reverse and outcome==0 or phase[0]=="rain" or phase[0]=="impact":
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("draco-%s-%d-%s.png" % [reverse,outcome,phase[0]]))
				if not reverse and outcome==0 and phase[0]=="rain":
					battle.animation_router.playback_speed = 0
					await process_frame
					await RenderingServer.frame_post_draw
					var before: float = effect.elapsed
					var count: int = effect.cursor
					renderer.user_camera_yaw = 0.65
					await create_timer(0.15).timeout
					assert(is_equal_approx(effect.elapsed,before) and effect.cursor==count)
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("draco-orbit.png"))
					renderer.user_camera_yaw = 0
					battle.animation_router.playback_speed = 1
			while move_busy: await process_frame
			print("DRACO_PREVIEW_CASE_OK reverse=",reverse," outcome=",outcome)
	print("DRACO_PREVIEW_OK directions=2 outcomes=3 pause_orbit=true")
	quit()
