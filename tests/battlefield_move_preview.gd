extends "res://tests/battle_dialogue_preview.gd"
const Moves := ["Heat Wave","Tera Starstorm"]
func _start() -> void:
	left_species="Dragonite"
	await super._start()
	move_picker.clear()
	for move in Moves:move_picker.add_item(move)
	root.title="PokeAether — Heat Wave en Tera Starstorm"
	status.text="Twee aangepaste veldanimaties: kies een move, draai de camera en test ook ontwijken."
	print("BATTLEFIELD_PREVIEW_READY moves=2")
	if "--smoke-field" in OS.get_cmdline_user_args():await _check_field()
func _check_field() -> void:
	var watchdog := Timer.new()
	root.add_child(watchdog)
	watchdog.one_shot=true
	watchdog.timeout.connect(func():printerr("FIELD_PREVIEW_TIMEOUT");quit(1))
	watchdog.start(300)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	DirAccess.make_dir_recursive_absolute(output)
	var renderer = battle.animation_router.model_presenter
	for reverse in [false,true]:
		move_reverse.button_pressed=reverse
		for i in Moves.size():
			move_picker.select(i)
			move_outcome.select(1 if reverse else 0)
			_preview_move()
			while renderer.common_effects.is_empty():await process_frame
			var effect: Node=renderer.common_effects[0]
			for phase in [["build",effect.launch*.9],["field",lerpf(effect.launch,effect.impact,.7)],["climax",lerpf(effect.impact,effect.duration,.2)]]:
				while is_instance_valid(effect) and effect.elapsed<float(phase[1]):await process_frame
				assert(is_instance_valid(effect))
				if reverse:
					battle.animation_router.playback_speed=0
					renderer.user_camera_yaw=.8
					await process_frame
					var before: float=effect.elapsed
					await create_timer(.15).timeout
					assert(is_equal_approx(before,effect.elapsed))
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join(str(i)+("-reverse-" if reverse else "-front-")+str(phase[0])+".png"))
				battle.animation_router.playback_speed=1
			while move_busy:await process_frame
			renderer.user_camera_yaw=0
			assert(renderer.common_effects.is_empty())
			print("FIELD_RENDER_OK ",Moves[i]," reverse=",reverse)
	watchdog.queue_free()
	host.release()
	host.queue_free()
	host=null
	await process_frame
	await process_frame
	print("FIELD_RENDER_SUITE_OK moves=2 phases=12 orbit_pause_miss=true")
	quit()
