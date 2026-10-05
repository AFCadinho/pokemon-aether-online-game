extends "res://tests/battle_dialogue_preview.gd"
const Electric = preload("res://scripts/battle/battle_ui/electric_move_effect_3d.gd")
var electric_script: Script = Electric
var electric_name := "Thunder Shock"
var electric_index := 5
func _start() -> void:
	left_species = "Pikachu"
	if "--smoke-electric" in OS.get_cmdline_user_args():
		create_timer(100).timeout.connect(func(): printerr("ELECTRIC_PREVIEW_TIMEOUT"); quit(1))
	await super._start()
	root.title = "PokeAether — " + electric_name
	move_picker.select(electric_index)
	status.text = electric_name + " met bronmateriaal. Test raak / ontwijken, pauzeer en draai de camera."
	if "--smoke-electric" in OS.get_cmdline_user_args(): await _check_electric()

func _load_preview() -> void:
	right_species = "Charmander"
	await super._load_preview()

func _check_electric() -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for species in ["Pikachu", "Dragonite"]:
		left_species = species
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
				assert(effect.get_script()==electric_script)
				var original_aim: Vector3 = effect.anchors.call().target
				if species=="Pikachu" and not reverse:
					assert(effect.anchors.call().attachment_part == "electric_body")
				for phase in ["flight", "impact"]:
					var target_time: float = lerpf(effect.launch,effect.impact,0.7) if phase=="flight" else effect.impact+effect.duration*0.025
					while effect.elapsed < target_time: await process_frame
					battle.animation_router.playback_speed = 0
					await process_frame
					await process_frame
					var frozen: float = effect.elapsed
					assert(renderer.move_contacts[1 if reverse else 0].is_empty())
					if outcome==1: assert(effect.anchors.call().target.is_equal_approx(original_aim))
					if not reverse and not output.is_empty() and DisplayServer.get_name() != "headless":
						await RenderingServer.frame_post_draw
						root.get_texture().get_image().save_png(output.path_join("%s-%d-%s.png" % [species,outcome,phase]))
					renderer.user_camera_yaw += 0.18
					await create_timer(0.05).timeout
					assert(is_equal_approx(effect.elapsed,frozen))
					for piece_index in effect.cursor:
						var piece: MeshInstance3D = effect.pieces[piece_index]
						if piece.visible and piece.mesh is QuadMesh:
							if effect.sprite_keys[piece_index] in ["bolt_arc", "bolt_core"]: continue
							assert(absf(piece.global_basis.z.normalized().dot(renderer.camera.global_basis.z.normalized())) > 0.999)
					battle.animation_router.playback_speed = 1
				while move_busy: await process_frame
				await process_frame
				await process_frame
				assert(renderer.common_effects.is_empty())
				print("ELECTRIC_CASE_OK ",species," reverse=",reverse," outcome=",outcome)
		_preview_move()
		while renderer.common_effects.is_empty(): await process_frame
		battle.animation_router.playback_speed = 0
		battle.animation_router.cancel_render()
		battle.animation_router.playback_speed = 1
		while move_busy: await process_frame
		await process_frame
		assert(renderer.common_effects.is_empty() and battle.animation_router.active_audio_nodes.is_empty())
	print(electric_name.to_upper().replace(" ", ""), "_PREVIEW_OK species=3 directions=2 outcomes=3 pause_orbit=true dodge=true cancellation=true")
	quit()
