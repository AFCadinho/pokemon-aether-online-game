extends "res://tests/source_moves_preview.gd"
## Offline normal/shiny comparison using the shipped native breath addition.
func _start() -> void:
	left_species = "Charmander"
	right_species = "Charmander"
	if "--check-breath" in OS.get_cmdline_user_args():
		create_timer(90).timeout.connect(func(): printerr("BREATH_PREVIEW_TIMEOUT"); quit(1))
	await super._start()
	move_picker.select(3)
	root.title = "PokeAether — Charmander Ember: nieuwe spuwbeweging"
	status.text = "Links normaal, rechts shiny. Ember gebruikt de nieuwe spuwbeweging. Pauzeer of draai de camera."
	if "--check-breath" in OS.get_cmdline_user_args(): await _check_breath()

func _load_preview() -> void:
	right_species = "Charmander"
	await super._load_preview()
	if not is_instance_valid(battle): return
	var renderer = battle.animation_router.model_presenter
	if renderer.active:
		renderer.set_combatant(1, "Charmander", true, true)
		await renderer.await_prepared(true, 30000)
		assert(renderer.active and not renderer.preparation_failed)
		battle.enemy_hud_panel.set_pokemon_data("Charmander", 100, 351, 351)

func _check_breath() -> void:
	var renderer = battle.animation_router.model_presenter
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty(): DirAccess.make_dir_recursive_absolute(output)
	for reverse in [false, true]:
		move_reverse.button_pressed = reverse
		var index := 1 if reverse else 0
		var ident := "p2" if reverse else "p1"
		assert(renderer.attack_action_for("Ember", ident) == "special_attack_2")
		assert(renderer.attack_action_for("Water Gun", ident) == "special_attack")
		for outcome in [0, 1]:
			move_outcome.select(outcome)
			_preview_move()
			while renderer.common_effects.is_empty(): await process_frame
			var effect: Node = renderer.common_effects[0]
			assert(is_equal_approx(effect.launch, 40.0/60.0) and is_equal_approx(effect.impact,64.0/60.0))
			while effect.elapsed < effect.launch + 0.1: await process_frame
			battle.animation_router.playback_speed = 0
			await process_frame
			await process_frame
			assert(renderer.current_actions[index] == "special_attack_2")
			var anchors: Dictionary = renderer._move_anchors(ident, "p1" if reverse else "p2", "Ember")
			assert(anchors.attachment_part == "mouth")
			var mouth_local: Vector3 = renderer.actors[index].to_local(renderer.world.to_global(anchors.sources[0]))
			assert(mouth_local.y > 0.3, "Mouth must remain upright during emission")
			var frozen: Vector3 = anchors.sources[0]
			renderer.user_camera_yaw += 0.3
			await create_timer(0.1).timeout
			assert(renderer._move_anchors(ident,"p1" if reverse else "p2","Ember").sources[0].is_equal_approx(frozen))
			if not output.is_empty() and DisplayServer.get_name() != "headless":
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png(output.path_join("breath-%s-%s.png" % [reverse,outcome]))
			battle.animation_router.playback_speed = 1
			while move_busy: await process_frame
			await renderer.wait_action(ident)
			print("BREATH_CASE_OK shiny=",reverse," outcome=",outcome," mouth_height=",mouth_local.y)
	print("CHARMANDER_EMBER_PREVIEW_OK normal_shiny=true hit_miss=true pause_orbit=true upright_mouth=true")
	quit()
