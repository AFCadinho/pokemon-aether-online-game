extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = ""
	settings.battle_3d_arena = "classic"
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	var stage: Node = battle.animation_router.model_presenter
	stage.set_process(false)
	# Exercise the real sprite replacement synchronously, before the renderer's
	# next process tick can conceal the one-frame regression.
	stage._set_active(true)
	for index in 2:
		var box: Node = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		var side := "back" if index == 0 else "front"
		for shiny in [false, true]:
			battle._set_single_pokemon_species_with_pvp_warning(box, "Dragonite", side, shiny, "switch_event")
			_check(box.single_sprite.sprite_frames != null, "real normal/shiny sprite frames are available")
			_check(box.single_sprite.self_modulate.a == 0.0, "replacement never reveals the 2D sprite before a renderer tick")
			box._apply_single_web_frames(box.single_sprite.sprite_frames)
			_check(box.single_sprite.self_modulate.a == 0.0, "a late sprite upgrade cannot reveal a fallback over 3D")
		box.set_double_pokemon_species("Dragonite", "Roaring Moon", side)
		_check(box.double_sprite_1.self_modulate.a == 0.0 and box.double_sprite_2.self_modulate.a == 0.0,
			"double-slot frame replacement also respects model ownership")
	stage._set_active(false)
	for box: Node in [battle.player_sprite_box, battle.enemy_sprite_box]:
		for sprite: AnimatedSprite2D in [box.single_sprite, box.double_sprite_1, box.double_sprite_2]:
			_check(sprite.self_modulate == Color.WHITE, "leaving 3D restores the latest sprite color immediately")
		box.set_single_pokemon_species("Dragonite", "back" if box == battle.player_sprite_box else "front")
		_check(box.single_sprite.visible and box.single_sprite.self_modulate.a == 1.0, "ordinary 2D replacements stay visible")
	var catalog := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	if not catalog.is_empty():
		await _check_real_switches(battle, stage, catalog)
	battle.free()
	await process_frame
	print("battle_switch_sprite_flash_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check_real_switches(battle: Node, stage: Node, catalog: String) -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_3d_catalog_path = catalog
	stage.set_process(true)
	battle._set_single_pokemon_species_with_pvp_warning(battle.player_sprite_box, "Dragonite", "back", false, "initial_setup")
	battle._set_single_pokemon_species_with_pvp_warning(battle.enemy_sprite_box, "Roaring Moon", "front", false, "initial_setup")
	await stage.await_prepared(true)
	_check(stage.active and stage.handles("p1") and stage.handles("p2"), "real reviewed pair is prepared")
	if not stage.active or stage.preparation_failed:
		return
	var old_ball_player: Node = battle.pokeball_summon_animation_player
	battle.pokeball_summon_animation_player = null # Prove the 3D send-out route.
	for item: Array in [[0, "Snorlax", false], [1, "Arcanine", true], [0, "Dragonite", false], [0, "Dragonite", false]]:
		var index := int(item[0])
		var ident := "p1" if index == 0 else "p2"
		var side := "back" if index == 0 else "front"
		var box: Node = battle.player_sprite_box if index == 0 else battle.enemy_sprite_box
		await battle._play_switch_recall("poke-ball", box, side)
		battle._set_single_pokemon_species_with_pvp_warning(box, item[1], side, item[2], "switch_event")
		_check(box.single_sprite.self_modulate.a == 0.0, "switch event stays in 3D before loading starts")
		var observed := {"flash": false, "arena_fallback": false, "frames": 0}
		var monitor := func():
			observed.frames += 1
			observed.flash = observed.flash or box.single_sprite.self_modulate.a != 0.0
			observed.arena_fallback = observed.arena_fallback or not stage.active
		process_frame.connect(monitor)
		await battle._play_switch_release("poke-ball", item[1], box, side)
		process_frame.disconnect(monitor)
		_check(observed.frames > 0 and not observed.flash and not observed.arena_fallback,
			"cold/warm normal/shiny switch keeps sprites hidden and the arena in 3D throughout preparation")
		_check(stage.handles(ident) and stage.actor_shown[index] and stage.lifecycle[index] == "idle", "new 3D actor finishes its send-out")
		print("SWITCH_3D_NO_FLASH species=", item[1], " shiny=", item[2], " frames=", observed.frames)
	stage.set_combatant(0, "Definitely Not A Pokémon")
	await stage.await_prepared()
	_check(not stage.active and battle.player_sprite_box.single_sprite.self_modulate.a == 1.0,
		"a genuinely unsupported model still restores stable 2D fallback")
	battle.pokeball_summon_animation_player = old_ball_player

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
