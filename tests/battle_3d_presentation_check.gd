extends SceneTree

const Renderer = preload("res://scripts/battle/battle_ui/experimental_battle_3d.gd")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var settings = root.get_node("SettingsManager")
	var old_mode: String = settings.battle_presentation_mode
	var old_path: String = settings.battle_3d_catalog_path
	var old_camera: bool = settings.battle_3d_camera_motion
	settings.battle_3d_camera_motion = false
	settings.battle_presentation_mode = "2.5d"
	assert(Renderer.supported("Dragonite", false, false, false))
	for args in [["Eevee", false, false, false], ["Dragonite", true, false, false], ["Dragonite", false, true, false], ["Dragonite", false, false, true]]:
		assert(not Renderer.supported.callv(args))
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(battle)
	await process_frame
	var stage = battle.battle_stage.get_node("ExperimentalBattle3D")
	assert(stage.packed.is_empty() and stage.viewport == null and not stage.active)
	settings.battle_presentation_mode = "3d"
	settings.battle_3d_catalog_path = "user://missing-battle-model-report.json"
	await process_frame
	await process_frame
	assert(not stage.active and stage.packed.is_empty())
	var report := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	if not report.is_empty():
		settings.battle_3d_catalog_path = report
		battle.player_sprite_box.set_single_pokemon_species("Dragonite", "back", false)
		battle.enemy_sprite_box.set_single_pokemon_species("Roaring Moon", "front", false)
		for frame in 5:
			await process_frame
		assert(stage.active and stage.packed.size() == 2)
		print("3D_IMPORT_MS ", stage.import_times_ms)
		assert(stage.pending_entries.is_empty())
		assert(stage.camera.position.is_equal_approx(Renderer.CAMERA_HOME))
		settings.battle_3d_camera_motion = true
		stage._update_camera(2.0)
		assert(not stage.camera.position.is_equal_approx(Renderer.CAMERA_HOME))
		settings.battle_3d_camera_motion = false
		stage._update_camera(0.0)
		assert(stage.camera.position.is_equal_approx(Renderer.CAMERA_HOME))
		battle.enemy_sprite_box.current_single_species = ""
		await process_frame
		await process_frame
		assert(stage.active and stage.actors[1] == null)
		battle.enemy_sprite_box.current_single_species = "Roaring Moon"
		await process_frame
		await process_frame
		assert(stage.active and stage.actors[1] != null)
		assert(battle.player_sprite_box.single_sprite.self_modulate.a == 0)
		assert(battle.player_sprite_box.presentation_anchor.is_valid())
		battle.animation_router.play_attack_tween_for_actor("p1: Dragonite", "Dragon Pulse")
		await process_frame
		assert(stage.players[0].current_animation == "special_attack")
		settings.battle_3d_camera_motion = true
		var held_phase: float = stage.camera_phase
		stage._update_camera(2.0)
		assert(stage.camera_phase == held_phase)
		settings.battle_3d_camera_motion = false
		battle.player_sprite_box.playback_speed = 4.0
		await process_frame
		await process_frame
		assert(stage.players[0].speed_scale == 4.0)
		battle.player_sprite_box.playback_speed = 1.0
		battle.enemy_sprite_box.presentation_action.emit("damage")
		assert(stage.players[1].current_animation == "damage")
		battle.player_sprite_box.presentation_action.emit("sleep")
		battle.player_sprite_box.reset_battle_pose()
		assert(stage.players[0].current_animation == "sleep")
		# Cancellation must not let an old faint clear a current Pokémon.
		battle.player_sprite_box.play_faint_tween()
		assert(stage.players[0].current_animation == "faint_start")
		battle.player_sprite_box.reset_battle_pose()
		await process_frame
		await process_frame
		assert(battle.player_sprite_box.current_single_species == "Dragonite")
		# Actual SpriteBox faint waits for the full source clip, then clears.
		battle.enemy_sprite_box.play_faint_tween()
		assert(battle.enemy_sprite_box.current_single_species == "Roaring Moon")
		stage.players[1].advance(100.0)
		for frame in 3:
			await process_frame
		assert(battle.enemy_sprite_box.current_single_species.is_empty())
		assert(stage.actors[1] == null and stage.active)
		battle.enemy_sprite_box.set_single_pokemon_species("Roaring Moon", "front", false)
		for frame in 3:
			await process_frame
		battle.enemy_sprite_box.current_single_is_shiny = true
		await process_frame
		await process_frame
		assert(not stage.active and battle.player_sprite_box.single_sprite.self_modulate.a == 1)
		battle.enemy_sprite_box.current_single_is_shiny = false
		await process_frame
		await process_frame
		assert(stage.active)
		assert(battle.player_sprite_box.get_single_sprite_hover_rect().has_area())
		battle.enemy_sprite_box.substitute_active = true
		await process_frame
		await process_frame
		assert(not stage.active)
		battle.enemy_sprite_box.substitute_active = false
		battle.player_sprite_box.presentation_action.emit("idle")
		await process_frame
		await process_frame
		# Drive an actual recorded response through the client's existing renderer.
		var p1 := {"ident": "p1a: Dragonite", "details": "Dragonite, L100", "species": "Dragonite", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
		var p2 := {"ident": "p2a: Roaring Moon", "details": "Roaring Moon, L100", "species": "Roaring Moon", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
		var first := {"success": true, "battleId": "3d-fixture", "replayKind": "wild", "formatId": "gen9nationaldex", "players": {"p1": {"name": "Player"}, "p2": {"name": "Wild"}},
			"ownTeam": [{"species": "Dragonite", "level": 100}], "trainerTeam": [{"species": "Roaring Moon", "level": 100}],
			"requests": {"p1": {"side": {"pokemon": [p1]}}, "p2": {"side": {"pokemon": [p2]}}},
			"state": {"turn": 1, "ended": false}, "events": [{"type": "turn", "turn": 1, "eventSeq": 0}]}
		var second := first.duplicate(true)
		second.requests.p2.side.pokemon[0].hp = 82
		second.requests.p2.side.pokemon[0].condition = "82/100"
		second.events = [{"type": "move", "actor": "p1a: Dragonite", "target": "p2a: Roaring Moon", "move": "Dragon Pulse", "eventSeq": 1},
			{"type": "damage", "target": "p2a: Roaring Moon", "condition": "82/100", "eventSeq": 2}]
		var terminal := second.duplicate(true)
		terminal.state = {"turn": 2, "ended": true, "winner": "Player"}
		terminal.events = [{"type": "win", "winner": "Player", "eventSeq": 3}]
		assert(battle.setup_battle_replay({"schemaVersion": 1, "frames": [first, second, terminal]}))
		battle.replay_paused = false
		await battle.play_replay_frame(battle.replay_controls.timeline, 1)
		assert(battle.battle_state.get_active_player_pokemon("p2").hp == 82)
		await process_frame
		assert(stage.active)
		var output := OS.get_environment("POKEAETHER_STAGE_OUTPUT")
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("client-3d.png"))
		await battle.stop_battle_replay()
		settings.battle_presentation_mode = "2.5d"
		var old_viewport: WeakRef = weakref(stage.viewport)
		await process_frame
		await process_frame
		assert(not stage.active and stage.packed.is_empty())
		assert(stage.viewport == null and old_viewport.get_ref() == null)
		assert(stage.actors == [null, null] and stage.pending_entries.is_empty())
		assert(not battle.player_sprite_box.presentation_anchor.is_valid())
		assert(battle.player_sprite_box.single_sprite.self_modulate.a == 1)
	settings.battle_presentation_mode = old_mode
	settings.battle_3d_catalog_path = old_path
	settings.battle_3d_camera_motion = old_camera
	battle.queue_free()
	await process_frame
	await process_frame
	print("BATTLE_3D_PRESENTATION_OK")
	quit()
