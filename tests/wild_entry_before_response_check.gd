extends SceneTree

var failed := false
func _init() -> void:
	_run.call_deferred()
func check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2d"
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(load("res://tests/fixtures/wild_entry_request_probe.gd"))
	world.set_process(false)
	var ui := Control.new()
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.battle_ui_host = ui
	var transition := WildEncounterTransition.new()
	root.add_child(transition)
	world.wild_encounter_transition = transition
	world._prewarm_wild_battle_ui()
	check(is_instance_valid(world.prepared_wild_battle), "The battle scene is prewarmed on desktop and browser as well as Android")
	var warmed: Control = world.prepared_wild_battle
	world.run_entry()
	for frame in 3:
		await process_frame
	check(world.position_waiting, "Real entry is blocked on the position response fixture")
	check(world.battle_instance == warmed, "Entry reuses the prewarmed scene")
	check(is_instance_valid(world.battle_screen_host) and world.battle_screen_host.fade_progress > 0.0, "Battle fade starts before the position save completes")
	await _capture("early-entry-first-blend")
	var battle: Control = world.battle_instance
	check(battle.has_meta("battle_entry_pending"), "Arena is explicitly pending authoritative data")
	check(not battle.enemy_sprite_box.visible and not battle.moves_grid.visible and battle.battle_input_locked, "Unknown combatants and actions stay hidden/locked")
	check(not battle.get_node("%ActionsDock").visible and not battle.get_node("%UtilityActions").visible and not battle.player_party_grid.visible, "Pending entry hides default party cards and utility actions")
	await world.battle_screen_host.wait_until_revealed()
	check(world.position_waiting and world.battle_screen_host.content.modulate.a == 1.0, "The full arena is visible while the first request is pending")
	await _capture("early-entry-awaiting-position")
	world.continue_position.emit()
	await process_frame
	check(world.response_waiting and world.battle_screen_host.content.modulate.a == 1.0, "Arena remains visible while the battle response is pending")
	battle._prepare_battle_setup(battle.BattleType.WILD, Pokemon.new("Pikachu",5), Pokemon.new("Rattata",3))
	check(not battle.has_meta("battle_entry_pending") and battle._pending_entry_visibility.is_empty(), "Authoritative setup restores controls and exits pending entry")
	world.continue_response.emit()
	await process_frame
	await process_frame
	check(not world.is_in_battle and world.battle_instance == null and not ui.visible, "Rejected entry restores the overworld and frees pending UI")
	world.set_script(null)
	world.queue_free()
	ui.queue_free()
	transition.queue_free()
	await process_frame
	print("wild_entry_before_response_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _capture(name: String) -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(name + ".png"))
