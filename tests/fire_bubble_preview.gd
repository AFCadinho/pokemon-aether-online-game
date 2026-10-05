extends "res://tests/battle_dialogue_preview.gd"
const Fire = preload("res://scripts/battle/battle_ui/fire_stream_move_effect_3d.gd")
const Bubbles = preload("res://scripts/battle/battle_ui/bubble_move_effect_3d.gd")
func _start() -> void:
	left_species = "Charmander"
	if "--smoke-fire-bubbles" in OS.get_cmdline_user_args():
		create_timer(180).timeout.connect(func(): printerr("FIRE_BUBBLE_PREVIEW_TIMEOUT"); quit(1))
	await super._start()
	root.title = "PokeAether — Flamethrower, Bubble & Bubble Beam"
	move_picker.select(7)
	status.text = "Kies Flamethrower, Bubble of Bubble Beam. Test raak / ontwijken en draai de camera."
	if "--smoke-fire-bubbles" in OS.get_cmdline_user_args(): await _check_batch()

func _check_batch() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for spec in [["Charmander",7],["Squirtle",8],["Blastoise",9]]:
		left_species = spec[0]
		move_picker.select(spec[1])
		await _load_preview()
		var renderer = battle.animation_router.model_presenter
		assert(renderer.active and battle.battle_state.battle_id.is_empty())
		for reverse in [false,true]:
			move_reverse.button_pressed = reverse
			for outcome in [0,1,2]:
				move_outcome.select(outcome)
				_preview_move()
				while renderer.common_effects.is_empty(): await process_frame
				var effect: Node = renderer.common_effects[0]
				assert(effect.get_script()==(Fire if spec[1]==7 else Bubbles))
				var original_aim: Vector3 = effect.anchors.call().target
				if not reverse:
					assert(effect.anchors.call().attachment_part==("cannons" if spec[1]==9 else "mouth"))
					if spec[1]==7: assert(renderer.current_actions[0]=="special_attack_2")
				for phase in ["flight","impact"]:
					var target_time: float = lerpf(effect.launch,effect.impact,0.75) if phase=="flight" else effect.impact+effect.duration*0.025
					while effect.elapsed < target_time: await process_frame
					battle.animation_router.playback_speed = 0
					await process_frame
					await process_frame
					var frozen: float = effect.elapsed
					assert(renderer.move_contacts[1 if reverse else 0].is_empty())
					if outcome==1: assert(effect.anchors.call().target.is_equal_approx(original_aim))
					if not reverse and not output.is_empty() and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output.path_join("%s-%d-%s.png" % [effect.key,outcome,phase]))
					renderer.user_camera_yaw += 0.2
					await create_timer(0.05).timeout
					assert(is_equal_approx(effect.elapsed,frozen))
					for piece: MeshInstance3D in effect.pieces:
						if piece.visible and piece.mesh is QuadMesh:
							assert(absf(piece.global_basis.z.normalized().dot(renderer.camera.global_basis.z.normalized()))>0.999)
					battle.animation_router.playback_speed = 1
				while move_busy: await process_frame
				await process_frame
				assert(renderer.common_effects.is_empty())
				print("FIRE_BUBBLE_CASE_OK ",spec," reverse=",reverse," outcome=",outcome)
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		battle.animation_router.cancel_render()
		while move_busy: await process_frame
		await process_frame
		assert(renderer.common_effects.is_empty() and battle.animation_router.active_audio_nodes.is_empty())
	print("FIRE_BUBBLE_PREVIEW_OK moves=3 directions=2 outcomes=3 mouth_cannons=true pause_orbit=true dodge=true cancellation=true")
	quit()
