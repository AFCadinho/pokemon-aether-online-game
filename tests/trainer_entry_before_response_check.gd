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
	var save := root.get_node("PlayerSave")
	var previous_party: Array = save.party.duplicate()
	var pokemon := Pokemon.new("Pikachu", 5)
	pokemon.current_hp = maxi(1, pokemon.max_hp)
	save.party.assign([pokemon])
	await _check_world_entry()
	await _check_leads(false)
	await _check_leads(true)
	save.party.assign(previous_party)
	print("trainer_entry_before_response_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check_world_entry() -> void:
	var world: Variant = Node2D.new()
	root.add_child(world)
	world.set_script(load("res://tests/fixtures/trainer_entry_request_probe.gd"))
	world.set_process(false)
	var ui := Control.new()
	root.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	world.battle_ui_host = ui
	var transition := WildEncounterTransition.new()
	root.add_child(transition)
	world.wild_encounter_transition = transition
	world._prewarm_wild_battle_ui()
	var warmed: Control = world.prepared_wild_battle
	world.run_trainer_entry()
	for frame in 3:
		await process_frame
	check(world.position_waiting and world.battle_instance == warmed, "NPC entry reuses the arena before position response")
	check(world.battle_screen_host.fade_progress > 0.0, "NPC fade starts while the position request is blocked")
	await world.battle_screen_host.wait_until_revealed()
	world.continue_position.emit()
	await process_frame
	check(world.response_waiting and world.battle_screen_host.content.modulate.a == 1.0, "NPC arena stays visible while creation is blocked")
	await _capture("npc-creation-pending")
	check(world.battle_instance.battle_stage.get_node("TrainerPortrait1").visible, "Known NPC portrait is visible while its battle response waits")
	check(world.battle_instance.battle_type == world.battle_instance.BattleType.TRAINER, "Pending arena keeps the trainer battle context")
	world.continue_response.emit()
	await process_frame
	await process_frame
	check(not world.is_in_battle and world.battle_instance == null and not ui.visible, "NPC rejection restores the overworld")
	check(not world.entry_result.get("success", true), "NPC rejection still reaches its caller")
	world.set_script(null)
	world.queue_free()
	ui.queue_free()
	transition.queue_free()
	await process_frame

func _check_leads(preview: bool) -> void:
	var battle: Variant = load("res://scenes/battle/battle.tscn").instantiate()
	battle.set_script(load("res://tests/fixtures/trainer_entry_lead_probe.gd"))
	var host: Variant = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE)
	battle.prepare_pending_entry(&"route_1", battle.BattleType.TRAINER, {"name": "Fixture Trainer", "_battle_sprite_frames": preload("res://assets/npcs/generic_npc_fallback_frames.tres")})
	host.reveal_pending_entry()
	await host.wait_until_revealed()
	battle.run_setup(preview)
	await process_frame
	if preview:
		check(battle.preview_waiting and not battle.has_meta("battle_entry_pending"), "Interactive Team Preview leaves pending state before selection")
		battle.continue_preview.emit()
	else:
		check(battle.player_lead_waiting and battle.has_meta("battle_entry_pending"), "Automatic player lead is awaited behind the visible arena")
		check(battle.battle_input_locked and not battle.moves_grid.visible, "Actions remain locked while leads wait")
		battle.continue_player_lead.emit()
		await process_frame
		check(battle.battle_stage.get_node("TrainerPortrait1").visible, "Known NPC portrait remains visible during automatic lead selection")
		check(battle.npc_lead_waiting and host.content.modulate.a == 1.0, "Automatic NPC lead does not cover the arena")
		check(battle.enemy_sprite_box.modulate.a == 0.0 and battle.enemy_team_preview_layer.modulate.a == 0.0, "Lead response visibility changes cannot flash mechanical combatants/preview")
		await _capture("npc-leads-pending")
		var card: Control = battle.battle_stage.get_node("TrainerPortrait1")
		check(card.is_visible_in_tree() and host.get_global_rect().encloses(card.get_global_rect()), "NPC portrait remains inside the visible arena")
		battle.continue_npc_lead.emit()
	await process_frame
	check(not battle.has_meta("battle_entry_pending") and battle._pending_entry_visibility.is_empty(), "Finished/failed lead setup releases pending masks")
	check(battle.enemy_sprite_box.modulate.a == 1.0, "Pending alpha masks are restored")
	host.release()
	host.queue_free()
	await process_frame

func _capture(name: String) -> void:
	var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
	if not output.is_empty() and DisplayServer.get_name() != "headless":
		for frame in 2:
			await process_frame
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(name + ".png"))
