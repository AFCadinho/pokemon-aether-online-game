extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var settings := root.get_node("SettingsManager")
	settings.battle_ui_layout = "immersive"
	settings.battle_presentation_mode = "2.5d"
	root.mode = Window.MODE_WINDOWED
	var host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	root.add_child(host)
	var battle = load("res://scenes/battle/battle.tscn").instantiate()
	host.mount(battle)
	await process_frame
	_check(battle.setup_battle_replay(_recording()), "immersive replay opens")
	if failed:
		quit(1)
		return
	host.get_node("Cover").hide()
	battle.current_action_panel.set_message("Go! Pikachu!")
	var output := OS.get_environment("POKEAETHER_REPLAY_CAPTURE_DIR")
	for dimensions: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = dimensions
		for frame in 12:
			await process_frame
		var prompt_rect: Rect2 = battle.current_action_panel.get_global_rect()
		var dock_rect: Rect2 = battle.replay_controls.get_global_rect()
		var transport_rect: Rect2 = battle.replay_controls.transport_overlay.get_global_rect()
		_check(not prompt_rect.intersects(dock_rect), "%s message clears replay dock" % dimensions)
		_check(not transport_rect.intersects(dock_rect), "%s transport clears replay dock" % dimensions)
		_check(not prompt_rect.intersects(transport_rect), "%s message clears replay transport" % dimensions)
		_check(prompt_rect.end.y + 4.0 <= dock_rect.position.y, "%s replay rows retain visible vertical spacing" % dimensions)
		if not output.is_empty() and DisplayServer.get_name() != "headless":
			DirAccess.make_dir_recursive_absolute(output)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("immersive-replay-%s.png" % dimensions.x))
	await battle.stop_battle_replay()
	host.release()
	host.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _recording() -> Dictionary:
	var p1 := {"ident": "p1a: Pikachu", "details": "Pikachu, L50", "species": "Pikachu", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
	var p2 := {"ident": "p2a: Eevee", "details": "Eevee, L50", "species": "Eevee", "condition": "100/100", "hp": 100, "maxHp": 100, "active": true}
	var first := {"success": true, "battleId": "layout", "formatId": "gen9nationaldex", "players": {"p1": {"name": "Review"}, "p2": {"name": "Scholar"}}, "ownTeam": [{"species": "Pikachu", "level": 50}], "trainerTeam": [{"species": "Eevee", "level": 50}], "trainerName": "Scholar", "requests": {"p1": {"side": {"pokemon": [p1]}}, "p2": {"side": {"pokemon": [p2]}}}, "state": {"turn": 1, "ended": false}, "events": [{"type": "turn", "turn": 1, "eventSeq": 0}]}
	var second: Dictionary = first.duplicate(true)
	second.state = {"turn": 2, "ended": false}
	second.events = [{"type": "turn", "turn": 2, "eventSeq": 1}]
	var terminal: Dictionary = second.duplicate(true)
	terminal.state = {"turn": 2, "ended": true, "winner": "Review"}
	terminal.requests = {}
	terminal.events = [{"type": "win", "winner": "Review", "eventSeq": 2}]
	return {"schemaVersion": 1, "frames": [first, second, terminal]}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL %s" % label)
