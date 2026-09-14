extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(1280, 900)
	root.content_scale_size = Vector2i(1280, 900)
	var service := root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	var snapshot := {"battleId": "coop-fixture", "revision": 1, "decisionId": "coop-1", "turn": 1,
		"participant": "p3", "locked": false, "partnerReady": true, "eventCursor": 20,
		"events": [{"seq": 11, "kind": "-damage", "actor": "p3", "hpPercent": 1}],
		"positions": [
			{"controller": "p1", "details": "Pidgey, L12, M", "hpPercent": 80},
			{"controller": "p3", "details": "Pikachu, L12, F", "hpPercent": 75, "status": "par"},
			{"controller": "p2", "details": "Geodude, L12, M", "hpPercent": 100, "boosts": {"def": 1}},
			{"controller": "p4", "details": "Golbat, L14, M", "hpPercent": 100}],
		"ownTeam": [{"slot": 1, "species": "Pikachu", "active": true, "hp": 30, "maxHp": 40},
			{"slot": 2, "species": "Bulbasaur", "hp": 24, "maxHp": 32}],
		"moves": [{"slot": 1, "name": "Thunder Shock", "pp": 24}, {"slot": 2, "name": "Growl", "pp": 40}],
		"legalActions": [{"type": "move", "slot": 1, "target": -1}, {"type": "move", "slot": 1, "target": 1},
			{"type": "move", "slot": 1, "target": 2}, {"type": "move", "slot": 2}, {"type": "switch", "slot": 2}]}
	service.apply_state({"activity": {"reservationId": "fixture", "battleId": "coop-fixture", "status": "active",
		"serverTime": 1000, "decisionDeadline": 1060, "partnerConnected": true}, "view": snapshot})
	var panel = load("res://scripts/battle/coop_battle_panel.gd").new()
	root.add_child(panel)
	await process_frame
	await process_frame
	_expect(panel.cards.size() == 4 and panel.displayed_cursor == 20, "four slots mount and reconnect establishes event cursor")
	_expect(panel.cards.p3.name.text.begins_with("YOU") and panel.cards.p1.name.text.begins_with("PARTNER"), "owner p3 is labelled independently from leader")
	_expect(panel.cards.p3.info.text.contains("30 / 40") and panel.cards.p1.info.text.contains("80%"), "only own HP is exact")
	_expect(panel.cards.p2.info.text.contains("DEF +1"), "public stat stages remain visible")
	_expect(panel.cards.p3.hp.value == 75 and not panel._playing, "old damage is not replayed over reconnect snapshot")
	var empty_snapshot: Dictionary = snapshot.duplicate(true)
	empty_snapshot.positions.remove_at(3)
	panel._apply_positions(empty_snapshot)
	_expect(panel.cards.p4.sprite.current_single_species.is_empty() and panel.cards.p4.hp.value == 0 and panel.cards.p4.name.text.begins_with("OPPONENT 2"), "empty NPC position clears the prior sprite and health without a phantom faint")
	var empty_capture := OS.get_environment("COOP_EMPTY_VISUAL_CAPTURE_PATH")
	if not empty_capture.is_empty():
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(empty_capture) == OK, "empty position visual capture saved")
	panel._apply_positions(snapshot)
	var effects = panel._effects
	var pair = effects.bind_pair("p3", "p4", panel.cards)
	_expect(pair.player_sprite_box == panel.cards.p3.sprite and pair.enemy_sprite_box == panel.cards.p4.sprite, "partner controller targets the second opponent")
	pair = effects.bind_pair("p4", "p1", panel.cards, false)
	_expect(pair.enemy_sprite_box == panel.cards.p4.sprite and pair.player_sprite_box == panel.cards.p1.sprite and not pair.audible, "reverse pair keeps controller identity and suppresses duplicate audio")
	var spread := {"seq": 1, "kind": "move", "actor": "p3", "target": "p2", "targets": ["p2"], "move": "Growl"}
	var plan: Dictionary = effects.move_targets(spread, [spread, {"seq": 2, "kind": "-miss", "actor": "p3", "target": "p4"}, {"seq": 3, "kind": "move", "actor": "p1"}, {"seq": 4, "kind": "-miss", "actor": "p3", "target": "p1"}])
	_expect(plan.targets == ["p2", "p4"] and plan.misses == ["p4"], "spread includes missed victim without borrowing the next move's miss")
	await effects.play_move(spread, [spread, {"seq": 2, "kind": "-miss", "actor": "p3", "target": "p4"}], panel.cards)
	_expect(effects.active_pairs == 0 and effects.routers["p3:p2"].audible and not effects.routers["p3:p4"].audible, "spread completes with exactly one audible move pair")
	panel._select_move(1)
	_expect(panel.cards.p1.target.visible and panel.cards.p2.target.visible and panel.cards.p4.target.visible and not panel.cards.p3.target.visible, "only legal ally/enemy locations are highlighted")
	await create_timer(0.15).timeout
	var capture := OS.get_environment("COOP_VISUAL_CAPTURE_PATH")
	if not capture.is_empty():
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(capture) == OK, "visual capture saved")
	snapshot.revision = 2
	snapshot.eventCursor = 22
	snapshot.positions[2].hpPercent = 64
	snapshot.events.append({"seq": 21, "kind": "move", "actor": "p3", "move": "Thunder Shock", "target": "p2"})
	snapshot.events.append({"seq": 22, "kind": "-damage", "actor": "p2", "hpPercent": 64})
	service.apply_view(snapshot)
	var effect_capture := OS.get_environment("COOP_VISUAL_EFFECT_CAPTURE_PATH")
	if not effect_capture.is_empty():
		await create_timer(0.35).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(effect_capture) == OK, "move effect capture saved")
	await _wait_for_cursor(panel, 22)
	_expect(panel.displayed_cursor == 22 and panel.cards.p2.hp.value == 64, "new move/damage events end at the authoritative snapshot")
	var history: String = panel._log.get_parsed_text()
	var action_node: Node = panel._actions.get_child(0)
	service.apply_view(snapshot)
	await process_frame
	_expect(panel._log.get_parsed_text() == history, "duplicate snapshots do not replay or duplicate history")
	_expect(panel._actions.get_child(0) == action_node, "heartbeat snapshots preserve keyboard focus and action nodes")
	snapshot.revision = 3
	snapshot.eventCursor = 23
	snapshot.positions[2].hpPercent = 0
	snapshot.positions[2].fainted = true
	snapshot.events.append({"seq": 23, "kind": "faint", "actor": "p2"})
	service.apply_view(snapshot)
	await _wait_for_cursor(panel, 23)
	_expect(panel.cards.p2.info.text == "FAINTED" and panel.cards.p2.sprite.current_single_species.is_empty(), "faint animation leaves no active sprite")
	snapshot.revision = 4
	snapshot.eventCursor = 24
	snapshot.positions[2].hpPercent = 80
	snapshot.positions[2].fainted = false
	snapshot.events.append({"seq": 24, "kind": "switch", "actor": "p2", "details": "Geodude, L12, M"})
	service.apply_view(snapshot)
	await _wait_for_cursor(panel, 24)
	_expect(panel.cards.p2.sprite.current_single_species == "Geodude" and panel.cards.p2.hp.value == 80, "same-species replacement gets a fresh visible sprite")
	snapshot.revision = 5
	snapshot.decisionId = "coop-2"
	snapshot.forceSwitch = true
	snapshot.moves = []
	snapshot.legalActions = [{"type": "switch", "slot": 2}]
	service.apply_view(snapshot)
	await process_frame
	await process_frame
	_expect(panel.selected_move == 0 and panel._prompt.text.contains("replacement"), "forced replacement clears stale target selection")
	var activity: Dictionary = service.activity.duplicate(true)
	activity.status = "finished"
	activity.outcome = "win"
	service.apply_state({"activity": activity, "view": snapshot})
	_expect(panel._prompt.text.contains("both Trainers won") and panel._actions.get_child_count() == 1, "finished state replaces commands with shared victory and return control")
	var old_generation: int = effects.generation
	effects.play_move({"actor": "p3", "target": "p2", "move": "Tackle"}, [], panel.cards)
	await process_frame
	effects.cancel()
	_expect(effects.generation > old_generation and effects.active_pairs == 0, "cancel invalidates in-flight move playback")
	var effects_ref: WeakRef = weakref(effects)
	panel.queue_free()
	await process_frame
	await process_frame
	_expect(effects_ref.get_ref() == null, "closing a battle releases its owned effect layer")
	pair = null
	await create_timer(0.2).timeout
	# SpriteBox deliberately shares render resources across battles. Explicitly
	# release this test process's shared cache before its rendering server exits.
	load("res://scripts/battle/battle_ui/sprite_box.gd")._shared_sprite_frames_cache.clear()
	PokemonAssets.party_icon_cache.clear()
	await process_frame
	service.reset()
	print("PASS coop_battle_presentation_check" if not failed else "FAIL coop_battle_presentation_check")
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _wait_for_cursor(panel: Control, cursor: int) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while panel.displayed_cursor != cursor and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(panel.displayed_cursor == cursor, "presentation reaches its cursor within the bounded animation budget")
