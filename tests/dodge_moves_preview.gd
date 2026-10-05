extends "res://tests/source_moves_preview.gd"
## Offline Dodge review; normal renderer plus the existing Water Gun candidate toggle.
var dodge_commands := 0
func _start() -> void:
	left_species = "Blastoise"
	await super._start()
	root.title = "PokeAether — Dodge! in 3D"
	move_outcome.select(1)
	status.text = "Ontwijken geselecteerd. Afspelen: trainer zegt Dodge!, Pokémon wijkt uit, aanval blijft op de oorspronkelijke plek gericht."
	if "--smoke-dodge" in OS.get_cmdline_user_args():
		create_timer(100).timeout.connect(func(): printerr("DODGE_PREVIEW_TIMEOUT"); quit(1))
		await _check_dodges()
func _preview_move() -> void:
	if not loading and not move_busy and is_instance_valid(battle):
		var actor := "p2" if move_reverse.button_pressed else "p1"
		var species := right_species if actor == "p2" else left_species
		var text: String = root.get_node("LocalizationManager").text("battle.command.move", {"pokemon": species, "move": FIRST_MOVES[move_picker.selected]})
		battle._show_trainer_command_text(actor, text)
	await super._preview_move()
func _preview_dodge_command(target: String) -> void:
	dodge_commands += 1
	var renderer = battle.animation_router.model_presenter
	assert(renderer.dodge_offsets[renderer.actor_index(target)] == Vector3.ZERO)
	await super._preview_dodge_command(target)
func _check_dodges() -> void:
	var renderer = battle.animation_router.model_presenter
	assert(renderer.active and battle.battle_state.battle_id.is_empty())
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for move_index in 6:
		move_picker.select(move_index)
		for reverse in [false, true]:
			move_reverse.button_pressed = reverse
			var index := 0 if reverse else 1
			var original: Vector3 = renderer.actors[index].position
			_preview_move()
			while renderer.dodge_offsets[index].length() < 0.4 and move_busy: await process_frame
			assert(move_busy, "Target must visibly dodge before the move finishes")
			var effect: Node = renderer.common_effects[0]
			while effect.elapsed < effect.impact - effect.duration * 0.015 and move_busy: await process_frame
			battle.animation_router.playback_speed = 0
			await process_frame
			await process_frame
			var frozen: Vector3 = renderer.dodge_offsets[index]
			var aim: Vector3 = effect.anchors.call().target
			assert(not effect.hit)
			renderer.user_camera_yaw += 0.2
			await create_timer(0.05).timeout
			assert(renderer.dodge_offsets[index].is_equal_approx(frozen))
			assert(effect.anchors.call().target.is_equal_approx(aim))
			if not output.is_empty() and move_index in [0,3,4] and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("dodge-%d-%s.png" % [move_index, reverse]))
			battle.animation_router.playback_speed = 1
			while move_busy: await process_frame
			assert(renderer.move_dodges[index].is_empty() and renderer.dodge_offsets[index] == Vector3.ZERO)
			assert(is_equal_approx(renderer.actors[index].position.x, original.x) and is_equal_approx(renderer.actors[index].position.z, original.z))
	assert(dodge_commands == 12)
	# Cancel a second dodge while displaced; restore synchronously.
	_preview_move()
	while renderer.dodge_offsets[0].length() < 0.4: await process_frame
	battle.animation_router.playback_speed = 0
	battle.animation_router.cancel_render()
	assert(renderer.dodge_offsets[0] == Vector3.ZERO)
	battle.animation_router.playback_speed = 1
	while move_busy: await process_frame
	print("DODGE_PREVIEW_OK moves=6 directions=2 callout_before_motion=true fixed_aim=true pause_orbit=true restore=true cancel=true")
	quit()
