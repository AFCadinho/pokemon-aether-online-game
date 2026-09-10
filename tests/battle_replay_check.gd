extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _run() -> void:
	var timeline_script := load("res://scripts/battle/battle_replay_timeline.gd") as GDScript
	_check(timeline_script != null and timeline_script.can_instantiate(), "Replay timeline compiles")
	for path: String in ["res://scripts/ui/battle_replay_library.gd", "res://scripts/ui/battle_replay_controls.gd", "res://scripts/battle/battle.gd", "res://scripts/ui/ui_overlay.gd", "res://scripts/world/world.gd"]:
		var script := load(path) as GDScript
		_check(script != null and script.can_instantiate(), path + " compiles")
	if failures:
		quit(1)
		return
	var timeline = timeline_script.new()
	var p1 := {"ident": "p1a: Pikachu", "details": "Pikachu, L50", "species": "Pikachu", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
	var p2 := {"ident": "p2a: Eevee", "details": "Eevee, L50", "species": "Eevee", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
	var first := {"success": true, "battleId": "fixture", "formatId": "gen9nationaldex", "players": {"p1": {"name": "Player"}, "p2": {"name": "Scholar"}},
		"ownTeam": [{"species": "Pikachu", "level": 50}], "trainerTeam": [{"species": "Eevee", "level": 50}], "trainerName": "Scholar",
		"requests": {"p1": {"side": {"pokemon": [p1]}}, "p2": {"side": {"pokemon": [p2]}}},
		"state": {"turn": 1, "ended": false}, "events": [{"type": "turn", "turn": 1, "eventSeq": 0}]}
	var second := first.duplicate(true)
	second["state"] = {"turn": 2, "ended": false}
	second["requests"]["p1"]["side"]["pokemon"][0]["condition"] = "50/100 par"
	second["requests"]["p1"]["side"]["pokemon"][0]["hp"] = 50
	second["events"] = [{"type": "damage", "target": "p1a: Pikachu", "condition": "50/100 par", "eventSeq": 1}, {"type": "turn", "turn": 2, "eventSeq": 2}]
	var terminal := second.duplicate(true)
	terminal["state"] = {"turn": 2, "ended": true, "winner": "Player"}
	terminal["requests"] = {}
	terminal["events"] = [{"type": "faint", "target": "p2a: Eevee", "eventSeq": 3}, {"type": "win", "winner": "Player", "eventSeq": 4}]
	var recording := {"schemaVersion": 1, "frames": [first, second, terminal]}
	_check(timeline.load_recording(recording), "Complete recording accepted")
	_check(timeline.index_for_turn(2) == 1, "Jump selects the beginning of the turn, not terminal state")
	_check(timeline.events_through(0).size() == 1, "Seeking excludes future log entries")
	var later: BattleState = timeline.state_through(1)
	_check(later.get_active_player_pokemon("p1").get("condition", "") == "50/100 par", "Recorded damage/status restored")
	var earlier: BattleState = timeline.state_through(0)
	_check(earlier.get_active_player_pokemon("p1").get("condition", "") == "100/100", "Backward seek removes future damage/status")
	_check(timeline.state_through(2).get_player_team("p2").size() == 1, "Terminal empty requests preserve roster")
	_check(not timeline.load_recording({"schemaVersion": 2, "frames": [first, terminal]}), "Unsupported format rejected")
	var scene := load("res://scenes/battle/battle.tscn") as PackedScene
	var battle := scene.instantiate()
	root.add_child(battle)
	await process_frame
	_check(battle.setup_battle_replay(recording), "Battle scene opens in replay mode")
	_check(not battle.battle_actions_ready and battle.battle_request.has_meta("replay_read_only"), "Replay cannot issue battle actions")
	_check(not battle.action_buttons.visible, "Live action controls are hidden")
	var request_result: Dictionary = await root.get_node("BattleApiClient").send_post_request(battle.battle_request, "/must-not-send", {})
	_check(not request_result.get("success", true), "Replay transport blocks writes before network access")
	var controls: Control = battle.replay_controls
	controls._toggle()
	await process_frame
	controls.seek(0)
	while controls.busy:
		await process_frame
	_check(controls.index == 0 and not controls.playing, "Seeking cancels in-flight playback")
	controls._toggle()
	await process_frame
	await battle.stop_battle_replay()
	_check(not controls.busy and controls.closing, "Closing drains the animated renderer before freeing the battle")
	battle.queue_free()
	await process_frame
	var fixture_path := OS.get_environment("POKEAETHER_REPLAY_PLAYBACK_PATH")
	if not fixture_path.is_empty():
		var real_recording: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(fixture_path))
		_check(timeline.load_recording(real_recording), "Stored real simulator recording loads")
		var real_battle := scene.instantiate()
		root.add_child(real_battle)
		await process_frame
		_check(real_battle.setup_battle_replay(real_recording), "Real recording opens")
		for frame_index in range(timeline.frames.size()):
			real_battle.restore_replay_position(timeline, frame_index)
			var expected: BattleState = timeline.state_through(frame_index)
			_check(real_battle.battle_state.requests == expected.requests, "Real frame restores exact recorded roster")
			real_battle._hide_replay_actions()
			_check(not real_battle.battle_actions_ready, "Seeking never enables actions")
		# Exercise the existing animated renderer and then rewind its mutations.
		real_battle.restore_replay_position(timeline, 1)
		real_battle.replay_paused = false
		real_battle.set_replay_speed(4.0)
		await real_battle.play_replay_frame(timeline, 2)
		_check(real_battle.battle_state.requests == timeline.state_through(2).requests, "Animated frame reconciles to recorded state")
		real_battle.restore_replay_position(timeline, 1)
		_check(real_battle.battle_state.requests == timeline.state_through(1).requests, "Rewinding an animated frame restores original state")
		var capture_dir := OS.get_environment("POKEAETHER_REPLAY_CAPTURE_DIR")
		if not capture_dir.is_empty():
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(capture_dir.path_join("playback.png"))
		real_battle.queue_free()
		await process_frame
	var library: Control = (load("res://scripts/ui/battle_replay_library.gd") as GDScript).new()
	root.add_child(library)
	var overlay: CanvasLayer = (load("res://scripts/ui/ui_overlay.gd") as GDScript).new()
	library.team_strip_factory = Callable(overlay, "_create_pvp_history_team_strip")
	library.show()
	library.list.add_child(library._card({"battleId": "preview", "title": "My comeback against Scholar", "opponentDisplayName": "Scholar", "createdAt": "2026-09-10T09:00:00", "turns": 24, "result": "win", "status": "available", "favorite": true,
		"playerRoster": [{"species": "Pikachu"}, {"species": "Charizard"}, {"species": "Tyranitar"}],
		"opponentRoster": [{"species": "Blissey"}, {"species": "Scizor"}, {"species": "Garchomp"}]}))
	library.list.add_child(library._card({"battleId": "preview2", "opponentDisplayName": "Grandmaster Hard", "createdAt": "2026-09-09T18:00:00", "turns": 36, "result": "loss", "status": "available", "expiresAt": "2026-10-09"}))
	for i in range(4):
		await process_frame
	_check(library.list.get_child_count() == 2, "Library renders management cards")
	_check(library.shell.get_theme_stylebox("panel") != null, "Library shell has a dedicated replay visual style")
	_check(library.search.get_theme_stylebox("focus") != null and library.outcome.get_theme_stylebox("hover") != null, "Replay filters have focused and hover states")
	_check(library.outcome.get_theme_icon("arrow") != null and library.outcome.get_popup().get_theme_stylebox("panel") != null, "Replay dropdowns style their arrow and menu")
	_check(library.favorites.get_theme_icon("checked") != null and library.favorites.get_theme_stylebox("normal") != null, "Favorites uses a dedicated toggle style")
	var card_buttons: Array[Node] = library.list.get_child(0).find_children("*", "Button", true, false)
	var watch_button := card_buttons[0] as Button if not card_buttons.is_empty() else null
	_check(watch_button != null and watch_button.get_theme_stylebox("normal") != null, "Replay cards provide styled actions")
	print("Replay library geometry: viewport=%s root=%s shell=%s minimum=%s" % [root.size, library.size, library.shell.get_rect(), library.shell.get_combined_minimum_size()])
	_check(library.shell.position.y >= 0 and library.shell.get_rect().end.y <= library.size.y + 1, "Library fits the viewport")
	var capture_dir := OS.get_environment("POKEAETHER_REPLAY_CAPTURE_DIR")
	if not capture_dir.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_dir.path_join("library.png"))
	library.queue_free()
	overlay.free()
	await process_frame
	var full_overlay := (load("res://scenes/interface/ui_overlay.tscn") as PackedScene).instantiate()
	root.add_child(full_overlay)
	await process_frame
	_check(full_overlay.find_child("BattleReplaysButton", true, false) != null, "Replays have their own main toolbar entry")
	_check(full_overlay._priority_overlay_panels().has(full_overlay.replay_library), "Replay library participates in overlay focus policy")
	var history_card: Control = full_overlay._create_pvp_ai_sparring_history_card({"battleId": "fixture", "replayStatus": "available"})
	var history_buttons := history_card.find_children("*", "Button", true, false)
	_check(history_buttons.size() == 1 and not history_buttons[0].disabled, "Available match history opens the same replay")
	history_card.free()
	full_overlay.queue_free()
	await process_frame
	# Release test-owned static texture references before the renderer shuts down.
	PokemonAssets.party_icon_cache.clear()
	(load("res://scripts/battle/battle_ui/sprite_box.gd") as GDScript)._shared_sprite_frames_cache.clear()
	await process_frame
	print("Battle replay checks: %d failures" % failures)
	quit(1 if failures else 0)
