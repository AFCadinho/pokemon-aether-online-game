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
	_check_entry_scale(world.battle_instance, "before first frame")
	var entry_scales := _entry_scales(world.battle_instance)
	for frame in 3:
		await process_frame
		_check_same_scales(world.battle_instance, entry_scales, "during the first fade frames")
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
	_check_entry_scale(battle, "while the requests wait")
	await _capture("early-entry-awaiting-position")
	world.continue_position.emit()
	await process_frame
	check(world.response_waiting and world.battle_screen_host.content.modulate.a == 1.0, "Arena remains visible while the battle response is pending")
	battle._prepare_battle_setup(battle.BattleType.WILD, Pokemon.new("Pikachu",5), Pokemon.new("Rattata",3))
	_check_entry_scale(battle, "after authoritative setup")
	_check_same_scales(battle, entry_scales, "after authoritative setup")
	await _capture("early-entry-after-setup")
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
	for mode: String in ["2d", "3d"]:
		await _check_cold_fullscreen_entry(mode)
	settings.battle_presentation_mode = "2d"
	for log_open in [true, false]:
		await _check_classic_entry(log_open)
	print("wild_entry_before_response_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check_cold_fullscreen_entry(mode: String) -> void:
	root.get_node("SettingsManager").battle_presentation_mode = mode
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
	check(world.prepared_wild_battle == null, "Startup can leave the unused battle UI unallocated")
	world.run_entry()
	var battle: Control = world.battle_instance
	check(battle != null and is_instance_valid(world.battle_screen_host), "First fullscreen encounter mounts its UI without a startup prewarm")
	for _frame in range(3):
		await process_frame
	check(world.position_waiting and battle.has_meta("battle_entry_pending") and battle.battle_input_locked, "Cold entry still waits for authoritative position with actions locked")
	world.continue_position.emit()
	await process_frame
	check(world.response_waiting, "Cold entry waits for the battle response")
	world.continue_response.emit()
	await process_frame
	await process_frame
	check(not world.is_in_battle and world.battle_instance == null and not ui.visible, "Rejected first encounter safely restores the overworld")
	world.set_script(null)
	world.queue_free()
	ui.queue_free()
	transition.queue_free()
	await process_frame

func _capture(name: String) -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(name + ".png"))

func _check_entry_scale(battle: Control, phase: String) -> void:
	for node: Control in [battle.player_battle_platform, battle.enemy_battle_platform, battle.player_sprite_box, battle.enemy_sprite_box]:
		check(node.scale.is_equal_approx(Vector2.ONE * 0.82), "Sprite/platform size must already be final " + phase)
	for node: Control in [battle.player_hud_panel, battle.enemy_hud_panel]:
		check(node.scale.is_equal_approx(Vector2.ONE * 0.65), "HP panels must already have their final scale " + phase)
	var expected_move_scale := minf(0.8 * float(root.get_node("SettingsManager").ui_scale) / 100.0, maxf(0.4, (battle.battle_stage.size.x * 0.5) / 400.0))
	check(is_equal_approx(battle.moves_grid.scale.x, expected_move_scale), "Move controls must already have their final scale " + phase)

func _entry_scales(battle: Control) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for node: Control in [battle, battle.battle_stage, battle.player_battle_platform, battle.enemy_battle_platform, battle.player_sprite_box, battle.enemy_sprite_box, battle.player_hud_panel, battle.enemy_hud_panel, battle.moves_grid]:
		result.append(node.get_global_transform().get_scale())
	return result

func _check_same_scales(battle: Control, expected: Array[Vector2], phase: String) -> void:
	var current := _entry_scales(battle)
	for index in current.size():
		check(current[index].is_equal_approx(expected[index]), "Battle element %d must not shrink %s (%s -> %s)" % [index, phase, expected[index], current[index]])

func _check_classic_entry(log_open: bool) -> void:
	root.get_node("SettingsManager").battle_ui_layout = "classic"
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
	world.run_entry()
	var battle: Control = world.battle_instance
	battle._set_battle_log_open(log_open)
	battle.update_entry_layout()
	var entry_scales := _entry_scales(battle)
	var entry_view_size: Vector2 = battle.get_node("%BattleStageViewport").size
	for frame in 3:
		await process_frame
		_check_same_scales(battle, entry_scales, "during Classic pending frames")
		check(battle.get_node("%BattleStageViewport").size.is_equal_approx(entry_view_size), "Classic stage already has its final available space before the first frame")
	check(world.position_waiting and battle.has_meta("battle_entry_pending"), "Classic scale check blocks the real position request")
	check(battle.get_node("%ActionsDock").visible and is_zero_approx(battle.get_node("%ActionsDock").modulate.a) and not battle.get_node("%ActionsDock").can_process(), "Reserved Classic dock stays invisible and cannot receive input")
	await _capture("classic-scale-awaiting-position")
	world.continue_position.emit()
	await process_frame
	check(world.response_waiting, "Classic scale check blocks the real battle creation request")
	battle._prepare_battle_setup(battle.BattleType.WILD, Pokemon.new("Pikachu",5), Pokemon.new("Rattata",3))
	for frame in 3:
		await process_frame
		_check_same_scales(battle, entry_scales, "after Classic authoritative setup")
		check(battle.get_node("%BattleStageViewport").size.is_equal_approx(entry_view_size), "Restoring Classic actions does not shrink the battlefield")
	await _capture("classic-scale-after-setup")
	check(not battle.has_meta("battle_entry_pending") and battle._pending_entry_visibility.is_empty(), "Classic layout reservation is released with pending masks")
	check(battle.get_node("%ActionsDock").visible and is_equal_approx(battle.get_node("%ActionsDock").modulate.a, 1.0) and battle.get_node("%ActionsDock").can_process(), "Classic actions restore their visibility, original opacity and input")
	world.continue_response.emit()
	await process_frame
	await process_frame
	check(not world.is_in_battle and world.battle_instance == null, "Classic scale entry rejection still cleans up")
	world.set_script(null)
	world.queue_free()
	ui.queue_free()
	transition.queue_free()
	await process_frame
