extends "res://tests/battle_dialogue_preview.gd"
## Live source contact effects, with existing native model actions and Dodge.
const Contact = preload("res://scripts/battle/battle_ui/contact_move_effect_3d.gd")
func _start() -> void:
	left_species = "Charmander"
	if "--smoke-contact" in OS.get_cmdline_user_args():
		create_timer(150).timeout.connect(func(): printerr("CONTACT_PREVIEW_TIMEOUT"); quit(1))
	await super._start()
	root.title = "PokeAether — Tackle / Scratch / Bite"
	move_picker.select(1)
	status.text = "Contactmoves met bronmateriaal. Test raak / ontwijken, wissel Pokémon en draai de camera."
	if "--smoke-contact" in OS.get_cmdline_user_args(): await _check_contacts()

func _check_contacts() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for species in ["Charmander", "Arcanine"]:
		left_species = species
		await _load_preview()
		var renderer = battle.animation_router.model_presenter
		assert(renderer.active and battle.battle_state.battle_id.is_empty())
		for move_index in 3:
			move_picker.select(move_index)
			for reverse in [false, true]:
				move_reverse.button_pressed = reverse
				for outcome in [0, 1, 2]:
					move_outcome.select(outcome)
					_preview_move()
					while renderer.common_effects.is_empty(): await process_frame
					var source_index := 1 if reverse else 0
					var home: Vector3 = renderer.actors[source_index].position
					var effect: Node = renderer.common_effects[0]
					assert(effect.get_script() == Contact)
					while effect.elapsed < effect.impact + effect.duration * 0.02: await process_frame
					battle.animation_router.playback_speed = 0
					await process_frame
					await process_frame
					assert(renderer.contact_offsets[source_index].length() > 0.3, "Contact attack must approach")
					var contact_position: Vector3 = renderer.actors[source_index].position
					var hud_home: Rect2 = renderer._visual_rect(source_index)
					var offset: Vector3 = renderer.contact_offsets[source_index]
					renderer.actors[source_index].position -= offset
					renderer.contact_offsets[source_index] = Vector3.ZERO
					assert(renderer._visual_rect(source_index).is_equal_approx(hud_home), "HUD stays at home during approach")
					renderer.contact_offsets[source_index] = offset
					renderer.actors[source_index].position += offset
					var frozen: float = effect.elapsed
					var aim: Vector3 = effect.anchors.call().target
					if not reverse and outcome < 2 and not output.is_empty() and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output.path_join("%s-%s-%d.png" % [species,effect.key,outcome]))
					renderer.user_camera_yaw += 0.25
					await create_timer(0.05).timeout
					assert(effect.elapsed == frozen and effect.anchors.call().target.is_equal_approx(aim))
					assert(renderer.actors[source_index].position.is_equal_approx(contact_position))
					for piece: MeshInstance3D in effect.pieces:
						if piece.visible and piece.mesh is QuadMesh:
							assert(absf(piece.global_basis.z.normalized().dot(renderer.camera.global_basis.z.normalized())) > 0.999)
					battle.animation_router.playback_speed = 1
					while move_busy: await process_frame
					await process_frame
					await process_frame
					assert(renderer.common_effects.is_empty() and renderer.contact_offsets[source_index] == Vector3.ZERO)
					assert(renderer.actors[source_index].position.distance_to(home) < 0.12)
					print("CONTACT_CASE_OK ",species," move=",FIRST_MOVES[move_index]," reverse=",reverse," outcome=",outcome)
		# Paused cancellation must restore VFX/audio/dodge state immediately.
		move_outcome.select(1)
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		battle.animation_router.playback_speed = 0
		battle.animation_router.cancel_render()
		battle.animation_router.playback_speed = 1
		while move_busy: await process_frame
		await process_frame
		assert(renderer.common_effects.is_empty() and battle.animation_router.active_audio_nodes.is_empty())
	print("CONTACT_PREVIEW_OK species=3 moves=3 directions=2 outcomes=3 pause_orbit=true cancel=true")
	quit()
