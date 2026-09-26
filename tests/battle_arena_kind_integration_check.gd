extends SceneTree
## Real battle host wires encounter kind to the 3D arena selection.
const Arenas = preload("res://scripts/battle/arenas/arena_catalog.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings = root.get_node("SettingsManager")
	var old_mode: String = settings.battle_presentation_mode
	settings.battle_presentation_mode = "2.5d"
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	host.mount(battle)
	await process_frame
	var presenter = battle.animation_router.model_presenter
	assert(presenter != null)
	var player := Pokemon.new("Dragonite", 100)
	var enemy := Pokemon.new("Roaring Moon", 100)
	for example in [
		[battle.BattleType.WILD, &"route_1", "wild", "forest"],
		[battle.BattleType.WILD, &"route_24_water", "wild", "sea"],
		[battle.BattleType.WILD, &"cave", "wild", "cave"],
		[battle.BattleType.TRAINER, &"route_1", "trainer", "route_1"],
		[battle.BattleType.TRAINER, &"pewter_city_gym", "trainer", "pewter_city_gym"],
		[battle.BattleType.TRAINER, &"cerulean_city_gym", "trainer", "cerulean_city_gym"],
	]:
		if example[3] == "route_1":
			# An empty stage prepared before the response must not keep the
			# previous grassfield when the trainer's map is known.
			var prewarmed := SubViewport.new()
			presenter.add_child(prewarmed)
			presenter.viewport = prewarmed
			presenter.arena_id = "forest"
		battle._prepare_battle_setup(example[0], player, enemy, example[1])
		if example[3] == "route_1":
			assert(presenter.viewport == null, "prewarmed arena is replaced")
		assert(presenter.battle_kind == example[2])
		assert(battle.active_battle_environment_id == example[1])
		assert(presenter._requested_arena() == example[3])
	battle.pvp_room_code = "test-room"
	battle._prepare_battle_setup(battle.BattleType.TRAINER, player, enemy, &"pvp_stadium")
	assert(presenter.battle_kind == "pvp")
	assert(presenter._requested_arena() == "stadium")
	assert(Arenas.resolve("auto", &"route_1", "wild") == "forest")
	var model_catalog := OS.get_environment("POKEAETHER_ARENA_KIND_CATALOG")
	if model_catalog != "":
		var old_catalog: String = settings.battle_3d_catalog_path
		var old_forest: String = settings.battle_3d_forest_manifest
		var old_manual: bool = settings._manual_model_catalog_this_session
		settings.battle_3d_catalog_path = model_catalog
		settings.battle_3d_forest_manifest = OS.get_environment("POKEAETHER_FOREST_MANIFEST")
		settings._manual_model_catalog_this_session = true
		settings.battle_presentation_mode = "3d"
		battle.pvp_room_code = ""
		for example in [
			[battle.BattleType.WILD, &"route_1", "forest"],
			[battle.BattleType.TRAINER, &"route_1", "route_1"],
			[battle.BattleType.WILD, &"route_24_water", "sea"],
			[battle.BattleType.WILD, &"cave", "cave"],
			[battle.BattleType.TRAINER, &"pewter_city_gym", "pewter_city_gym"],
		]:
			battle._prepare_battle_setup(example[0], player, enemy, example[1])
			presenter.set_combatant(0, "Dragonite")
			presenter.set_combatant(1, "Roaring Moon")
			for frame in 2000:
				await process_frame
				if presenter.active and presenter.arena_id == example[2]:
					break
			assert(presenter.active and presenter.arena_id == example[2], presenter.arena_problem)
			var capture := OS.get_environment("POKEAETHER_ARENA_KIND_CAPTURE")
			if capture != "":
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png(capture + "-" + example[2] + ".png") == OK)
		settings.battle_3d_catalog_path = old_catalog
		settings.battle_3d_forest_manifest = old_forest
		settings._manual_model_catalog_this_session = old_manual
	host.free()
	settings.battle_presentation_mode = old_mode
	print("BATTLE_ARENA_KIND_INTEGRATION_OK")
	quit()
