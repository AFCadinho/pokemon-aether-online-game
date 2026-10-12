extends "res://tests/battle_dialogue_preview.gd"
## Offline visual review: --moves --capture-solid-forms [--caster=Cinderace].
## Write charge, travel and impact captures to POKEAETHER_STAGE_OUTPUT.
const REVIEW_MOVES := ["Hyper Beam", "Pyro Ball", "Hurricane", "Draco Meteor"]

func _start() -> void:
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--caster="): left_species = argument.trim_prefix("--caster=")
	await super._start()
	if "--capture-solid-forms" not in OS.get_cmdline_user_args(): return
	create_timer(90).timeout.connect(func(): printerr("SOLID_MOVE_PREVIEW_TIMEOUT"); quit(1))
	var renderer: Node = battle.animation_router.model_presenter
	assert(renderer.active, renderer.reason)
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	for move in REVIEW_MOVES:
		for index in move_picker.item_count:
			if move_picker.get_item_text(index) == move: move_picker.select(index)
		for reverse in [false, true]:
			move_reverse.button_pressed = reverse
			_preview_move()
			while renderer.common_effects.is_empty(): await process_frame
			var effect: Node = renderer.common_effects[0]
			var samples := [effect.launch * 0.8, lerpf(effect.launch, effect.impact, 0.8), lerpf(effect.impact, effect.duration, 0.15)]
			if move == "Draco Meteor": samples = [effect.duration * 0.17, effect.duration * 0.59, effect.duration * 0.73]
			for index in samples.size():
				while is_instance_valid(effect) and effect.elapsed < samples[index]: await process_frame
				assert(is_instance_valid(effect) and not effect.done)
				battle.animation_router.playback_speed = 0
				await process_frame
				await process_frame
				toolbar.get_parent().hide()
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("%s-%s-%d.png" % [effect.key, reverse, index]))
				toolbar.get_parent().show()
				var pose: Transform3D = renderer.camera.transform
				var transforms: Array[Transform3D] = []
				for piece in effect.pieces: transforms.append(piece.transform)
				await create_timer(0.08).timeout
				assert(renderer.camera.transform.is_equal_approx(pose))
				for j in effect.cursor: assert(effect.pieces[j].transform.is_equal_approx(transforms[j]), move + " pause")
				battle.animation_router.playback_speed = 1
			while move_busy: await process_frame
			assert(renderer.move_camera.effect == null and renderer.common_effects.is_empty())
			print("SOLID_MOVE_PREVIEW ", move, " reverse=", reverse)
	print("SOLID_MOVE_FORMS_PREVIEW_OK moves=4 directions=2 pause=true recovery=true")
	host.release()
	host.queue_free()
	await process_frame
	quit()
