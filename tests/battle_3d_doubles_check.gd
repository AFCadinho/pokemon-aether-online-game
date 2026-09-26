extends SceneTree

const SLOTS := ["p1", "p2", "p3", "p4"]

func _init() -> void:
	_run.call_deferred()

func _snapshot(second_ally := "Roaring Moon", fourth_enemy := "Roaring Moon") -> Dictionary:
	return {
		"participant": "p1", "turn": 1, "opponentPartySize": 2,
		"positions": [
			{"controller": "p1", "details": "Dragonite, L100, M", "hpPercent": 100},
			{"controller": "p3", "details": second_ally + ", L100, M", "hpPercent": 100},
			{"controller": "p2", "details": "Dragonite, L100, M", "hpPercent": 100},
			{"controller": "p4", "details": fourth_enemy + ", L100, M", "hpPercent": 100},
		],
		"ownTeam": [{"species": "Dragonite", "active": true, "hp": 100, "maxHp": 100}],
		"partnerTeam": [{"species": second_ally, "active": true, "hp": 100, "maxHp": 100}],
	}

func _wait_for(stage: Node, expected: bool) -> void:
	for frame in 2000:
		if stage.active == expected and (not expected or stage.actors.all(func(actor): return is_instance_valid(actor))):
			return
		await process_frame
	assert(false, "Timed out waiting for 3D double battle: " + stage.reason)

func _run() -> void:
	assert(load("res://scripts/world/world.gd") is GDScript, "Co-op arena context must compile")
	var catalog := OS.get_environment("SUMMARY_MODEL_CATALOG")
	assert(FileAccess.file_exists(catalog), "Set SUMMARY_MODEL_CATALOG to a reviewed local catalog")
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_arena = "auto" if not OS.get_environment("POKEAETHER_TEST_ARENA").is_empty() else "classic"
	if not OS.get_environment("POKEAETHER_FOREST_MANIFEST").is_empty():
		settings.battle_3d_forest_manifest = OS.get_environment("POKEAETHER_FOREST_MANIFEST")
	settings.battle_3d_camera_motion = false
	settings.battle_3d_catalog_path = catalog
	settings._manual_model_catalog_this_session = true
	var service := root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.mount(battle, null, WildEncounterTransition.STYLE_WILD, true)
	assert(battle.setup_coop_battle())
	var panel: Control = battle.coop_presenter
	var stage: Node = battle.battle_stage.get_node("ExperimentalBattle3D")
	if not OS.get_environment("POKEAETHER_TEST_ARENA").is_empty():
		stage.set_battle_context(StringName(OS.get_environment("POKEAETHER_TEST_ARENA")), "trainer")
	panel._apply_positions(_snapshot())
	await _wait_for(stage, true)
	if not OS.get_environment("POKEAETHER_TEST_ARENA").is_empty():
		assert(stage.arena_id == OS.get_environment("POKEAETHER_TEST_ARENA"), stage.arena_problem)
	assert(stage.double_mode and stage.actors.size() == 4)
	await process_frame
	for index in 4:
		assert(stage.material_response.source_ids[index] == stage.actors[index].get_instance_id(),
			"Lighting pass did not follow model slot " + str(index))
	for controller: String in SLOTS:
		assert(stage.handles(controller), "Missing 3D actor for " + controller)
		assert(stage.actor_visual_rect(controller).has_area())
		assert(panel._native_sprite(controller).self_modulate.a == 0.0)
	var player_gap: float = stage.actor_anchor("p3").x - stage.actor_anchor("p1").x
	var enemy_gap: float = stage.actor_anchor("p4").x - stage.actor_anchor("p2").x
	assert(player_gap > 50.0 and enemy_gap > 50.0, "Doubles actors overlap in the battle camera")
	for yaw: float in [-PI, -PI * 0.5, 0.0, PI * 0.5, PI]:
		stage.user_camera_yaw = yaw
		stage.user_camera_zoom = stage.USER_CAMERA_ZOOM_MIN
		await process_frame
		await process_frame
		for controller: String in SLOTS:
			assert(stage.get_global_rect().grow(20.0).has_point(stage.actor_anchor(controller)),
				"Camera clipped " + controller + " at yaw " + str(yaw))
	stage.reset_user_camera()
	await process_frame
	panel._position_native_targets()
	for controller: String in SLOTS:
		var button: Button = panel.cards[controller].target
		assert(button.size.x >= 100.0 and button.size.y >= 100.0)
	var before_actions: Array = stage.action_generation.duplicate()
	await panel._animate_event({"kind": "move", "actor": "p3", "move": "QA Move"})
	assert(stage.action_generation[2] > before_actions[2] and stage.action_generation[0] == before_actions[0],
		"Partner move animated the wrong model")
	before_actions = stage.action_generation.duplicate()
	await panel._animate_event({"kind": "-damage", "actor": "p4", "hpPercent": 80})
	assert(stage.action_generation[3] > before_actions[3] and stage.action_generation[1] == before_actions[1],
		"Second opponent hit animated the wrong model")
	await panel._animate_event({"kind": "switch", "actor": "p3", "details": "Dragonite, L100, M"})
	panel._apply_positions(_snapshot("Dragonite"))
	for frame in 120:
		await process_frame
	assert(stage.handles("p3") and stage.identities[2] == "dragonite", "Partner switch did not update the correct 3D slot")
	await panel._animate_event({"kind": "switch", "actor": "p3", "details": "Eevee, L100, M"})
	panel._apply_positions(_snapshot("Eevee"))
	await _wait_for(stage, false)
	await process_frame
	for controller: String in SLOTS:
		assert(panel._native_sprite(controller).self_modulate.a == 1.0, "Fallback left a sprite hidden")
		assert(not panel._model_anchored_sprites.has(controller), "Fallback did not restore the 2D animation anchor")
	panel._apply_positions(_snapshot())
	await _wait_for(stage, true)
	print("BATTLE_3D_DOUBLES_OK: four positioned models, partner switch, target boxes and whole-field fallback")
	await stage.await_prepared(true)
	for frame in 10:
		await process_frame
	host.release()
	host.free()
	quit()
