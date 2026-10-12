extends "res://tests/battle_dialogue_preview.gd"
var sample_seconds := 0.0

func _preview_moves() -> Array:
	return ["darkpulse", "surf", "blizzard", "earthpower", "overheat"]

func _start() -> void:
	left_species = "Dragonite"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--caster="): left_species = argument.trim_prefix("--caster=")
	await super._start()
	root.get_node("SettingsManager").battle_3d_camera_motion = true
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	assert(not output.is_empty())
	DirAccess.make_dir_recursive_absolute(output)
	var renderer: Node = battle.animation_router.model_presenter
	assert(renderer.active,renderer.reason)
	battle.animation_router.playback_speed = 0
	toolbar.get_parent().hide()
	for move in _preview_moves():
		for reverse in [false,true]:
			var actor := "p2" if reverse else "p1"
			var target := "p1" if reverse else "p2"
			for outcome in ["hit","miss","block"]:
				renderer.start_move_action(actor,move)
				var effect: Node = renderer.create_move_effect(move,actor,target,{"show_impact":outcome=="hit","result":outcome})
				effect.clock = func(): return sample_seconds
				var samples := [effect.launch*0.75,lerpf(effect.launch,effect.impact,0.25),lerpf(effect.launch,effect.impact,0.5),lerpf(effect.launch,effect.impact,0.82),lerpf(effect.impact,effect.duration,0.15)]
				for fraction in [.35,.65]: samples.append(lerpf(effect.impact,effect.duration,fraction))
				for phase in samples.size():
					sample_seconds = samples[phase]
					var slot: int = renderer.actor_index(actor)
					renderer.players[slot].seek(sample_seconds,true)
					renderer.players[slot].advance(0)
					renderer._update_move_contacts()
					effect._process(0)
					renderer._update_camera(0)
					await process_frame
					await RenderingServer.frame_post_draw
					root.get_texture().get_image().save_png(output.path_join("%s-%s-%s-%d.png" % [move,reverse,outcome,phase]))
				effect.cancel()
				sample_seconds = 0
				await process_frame
				renderer._action("idle",renderer.actor_index(actor))
				assert(renderer.common_effects.is_empty() and renderer.move_camera.effect==null and renderer.move_atmosphere.effect==null)
	print("ELEMENTAL_PREVIEW_OK moves=",_preview_moves().size()," directions=2 outcomes=3 phases=7")
	host.release()
	host.queue_free()
	host = null
	await process_frame
	quit()
