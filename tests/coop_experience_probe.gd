extends SceneTree
# Synthetic presentation audit: real native 2D scene, no backend/session.
var results: Array[Dictionary] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	var settings: Node = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2d"
	settings.battle_ui_layout = "immersive"
	settings.battle_animations = true
	var service: Node = root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE, true)
	assert(battle.setup_coop_battle())
	var panel: Control = battle.coop_presenter
	var snapshot := {"battleId": "coop-fixture", "revision": 1, "decisionId": "coop-1", "turn": 1,
		"participant": "p1", "locked": false, "partnerReady": true, "ended": false, "eventCursor": 0,
		"events": [], "field": {}, "legalActions": [{"type": "move", "slot": 1, "target": 1}],
		"moves": [{"slot": 1, "name": "Tackle", "pp": 35, "maxPp": 35}],
		"positions": [
			{"controller": "p1", "details": "Pikachu, L30", "hpPercent": 100},
			{"controller": "p3", "details": "Snorlax, L30", "hpPercent": 100},
			{"controller": "p2", "details": "Pikachu, L30", "hpPercent": 100},
			{"controller": "p4", "details": "Snorlax, L30", "hpPercent": 100}],
		"ownTeam": [{"slot": 1, "species": "Pikachu", "active": true, "hp": 100, "maxHp": 100}]}
	service.apply_state({"activity": {"reservationId": "fixture", "battleId": "coop-fixture", "status": "active", "partnerConnected": true}, "view": snapshot})
	for _frame in 10:
		await process_frame
	assert(panel._native_mode and panel.displayed_cursor == 0)
	for move_name: String in ["Tackle", "Earthquake"]:
		assert(panel._native_move_router.has_move_animation(move_name))
	for targets: Array in [["p2"], ["p2", "p4"], ["p2", "p4", "p3"]]:
		var event := {"seq": 1, "kind": "move", "actor": "p1", "move": "Earthquake", "targets": targets}
		var started := Time.get_ticks_usec()
		await panel._animate_event(event, [event])
		_record("earthquake_targets_%d" % targets.size(), started)
	var batch: Array[Dictionary] = []
	var seq := 1
	for pair: Array in [["p1", "p2"], ["p3", "p4"], ["p2", "p1"], ["p4", "p3"]]:
		batch.append({"seq": seq, "kind": "move", "actor": pair[0], "move": "Tackle", "target": pair[1]})
		seq += 1
		batch.append({"seq": seq, "kind": "-damage", "actor": pair[1], "hpPercent": 90, "damagePercent": 10})
		seq += 1
	batch.append({"seq": seq, "kind": "turn", "turn": 2})
	for animations: bool in [true, false]:
		settings.battle_animations = animations
		panel.displayed_cursor = 0
		panel._revision = 1
		snapshot.revision = 2
		snapshot.decisionId = "coop-2"
		snapshot.turn = 2
		snapshot.events = batch
		snapshot.eventCursor = seq
		service.view = snapshot.duplicate(true)
		panel._latest = snapshot.duplicate(true)
		var started := Time.get_ticks_usec()
		panel._present()
		assert(panel._playing or not animations)
		var deadline := Time.get_ticks_msec() + 30000
		var locked_frames := 0
		while panel._playing and Time.get_ticks_msec() < deadline:
			locked_frames += 1
			await process_frame
		assert(not panel._playing and panel.displayed_cursor == seq)
		_record("four_tackle_turn_animations_%s" % str(animations), started, {"locked_frames": locked_frames})
	# Non-terminal backlog keeps actions locked for every historical animation.
	settings.battle_animations = true
	panel.displayed_cursor = 0
	panel._revision = 1
	var damage_batch: Array[Dictionary] = []
	for index in 24:
		damage_batch.append({"seq": index + 1, "kind": "-damage", "actor": "p2", "hpPercent": 90, "damagePercent": 1})
	panel._latest = snapshot.duplicate(true)
	panel._latest.revision = 3
	panel._latest.events = damage_batch
	panel._latest.eventCursor = 24
	service.view = panel._latest.duplicate(true)
	var started := Time.get_ticks_usec()
	panel._present()
	while panel._playing:
		await process_frame
	_record("backlog_24_damage_events", started)
	print("COOP_AUDIT_RESULT ", JSON.stringify(results))
	host.release()
	host.queue_free()
	service.reset()
	# Drain short audio/tween teardown continuations before ending the tree.
	await create_timer(0.5).timeout
	for _frame in 8:
		await process_frame
	print("PASS coop_experience_probe (synthetic native 2D, headless)")
	quit()

func _record(label: String, started: int, extra: Dictionary = {}) -> void:
	var result := {"case": label, "elapsed_ms": (Time.get_ticks_usec() - started) / 1000.0}
	result.merge(extra)
	results.append(result)
	print("COOP_AUDIT ", JSON.stringify(result))
