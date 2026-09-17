extends SceneTree

class ReturnWorld:
	extends Node
	var coop_finishing := false
	var finish_calls := 0
	var complete_on_finish := true

	func finish_coop_activity() -> void:
		finish_calls += 1
		if complete_on_finish:
			coop_finishing = true

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
	var saved_party: Dictionary = service.party.duplicate(true)
	var saved_activity: Dictionary = service.activity.duplicate(true)
	service.party = {"leaderId": 1, "memberIds": [1, 2], "memberUsernames": {"1": "Adinho", "2": "Admin"}}
	service.activity.activityId = "wild_grass:kanto_route_1"
	panel._log.clear()
	for event: Dictionary in [
		{"kind": "switch", "actor": "p2", "details": "Furret, L6, M"},
		{"kind": "switch", "actor": "p4", "details": "Furret, L6, F"},
		{"kind": "switch", "actor": "p3", "details": "Pikachu, L12, F"},
		{"kind": "switch", "actor": "p1", "details": "Pidgey, L12, M"},
	]:
		panel._append_event(event)
	var opening_log: String = panel._log.get_parsed_text()
	_expect(opening_log.count("A wild Furret has appeared!") == 2
		and opening_log.contains("Go! Pikachu!")
		and opening_log.contains("Adinho sent out Pidgey!")
		and not opening_log.contains("L12") and not opening_log.contains("Wild Pokémon 1:"),
		"wild doubles narrate both appearances and both Trainers without position summaries")
	service.party = saved_party
	service.activity = saved_activity
	_expect(panel.cards.size() == 4 and panel.displayed_cursor == 20, "four slots mount and reconnect establishes event cursor")
	_expect(panel.cards.p3.name.text.begins_with("YOU") and panel.cards.p1.name.text.begins_with("PARTNER"), "owner p3 is labelled independently from leader")
	_expect(panel.cards.p3.info.text.contains("30 / 40") and panel.cards.p1.info.text.contains("80%"), "only own HP is exact")
	_expect(panel.cards.p2.info.text.contains("DEF +1"), "public stat stages remain visible")
	_expect(panel.cards.p3.hp.value == 75 and not panel._playing, "old damage is not replayed over reconnect snapshot")
	_expect(not panel._actions.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text.begins_with("Run")), "trainer view has no Run control")
	_expect(not panel._actions.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text.begins_with("Wait")), "trainer view has no Wait control")
	service.view.legalActions.append({"type": "wait"})
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._actions.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "Wait — skip my action" and button.tooltip_text.contains("Wild Pokémon still act")), "wild wait explains no protection from enemy actions")
	service.view.legalActions.pop_back()
	service.view.legalActions.append({"type": "run"})
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._actions.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "Run — ask your partner"), "wild escape asks the partner for consent")
	service.view.legalActions.pop_back()
	var normal_actions: Array = service.view.legalActions.duplicate(true)
	service.view.exitRequest = {"type": "run", "requestedBy": "p1"}
	service.view.legalActions = [{"type": "run"}, {"type": "reject-exit"}]
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._prompt.text.contains("Your partner wants to flee") and panel._actions.find_children("*", "Button", true, false).size() == 2, "a partner with a previously selected attack sees only consent and refusal")
	await _capture_visual("COOP_CONSENT_VISUAL_CAPTURE_PATH")
	service.view.exitRequest.type = "forfeit"
	service.view.legalActions = [{"type": "forfeit"}, {"type": "reject-exit"}]
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._prompt.text.contains("Both Trainers will lose") and panel._actions.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "Agree — forfeit together"), "forfeit confirmation explains the shared loss")
	service.view.exitRequest.requestedBy = "p3"
	service.view.locked = true
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._prompt.text.contains("Waiting for your partner") and panel._actions.find_children("*", "Button", true, false).is_empty(), "requester cannot answer their own request")
	service.view.exitRequest = null
	service.view.locked = false
	service.view.legalActions = normal_actions
	service.view.captureOptions = {"targetController": "p4", "storageAvailable": true, "balls": [{"itemId": "poke-ball", "quantity": 2}]}
	service.view.lastCapture = {"checkpointRevision": 1, "itemId": "poke-ball", "caught": false, "shakeCount": 2}
	panel._bag_open = true
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._actions.find_children("*", "Button", true, false).any(func(button: Button) -> bool: return button.text == "Poke Ball ×2 — your target"), "co-op Bag uses server-owned ball options for only the assigned target")
	_expect(panel._capture_status.text.contains("2 shakes"), "reconnect shows the last accepted throw result")
	await _capture_visual("COOP_BAG_VISUAL_CAPTURE_PATH")
	service.view.captureOptions.storageAvailable = false
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._actions.find_children("*", "Label", true, false).any(func(label: Label) -> bool: return label.text.contains("party and PC are full")), "full storage explains why catching is unavailable without hiding other actions")
	await _capture_visual("COOP_STORAGE_VISUAL_CAPTURE_PATH")
	service.view.captureOptions = null
	service.view.lastCapture = {"checkpointRevision": 2, "itemId": "poke-ball", "caught": true, "shakeCount": 3}
	panel._bag_open = false
	panel._action_signature = ""
	panel._update_actions()
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
	var router_source := FileAccess.get_file_as_string("res://scripts/battle/coop_animation_router.gd")
	var presenter_source := FileAccess.get_file_as_string("res://scripts/battle/coop_battle_panel.gd")
	_expect(router_source.contains("var cover_scale: float = maxf(available_size.x / SOURCE_SIZE.x, available_size.y / SOURCE_SIZE.y)")
		and router_source.contains("animation_node.scale = Vector2(cover_scale, cover_scale)")
		and presenter_source.contains("var animate := displayed_cursor >= 0")
		and not presenter_source.contains("fresh.size() <= 20")
		and presenter_source.contains("func _final_event_playback_pending()")
		and presenter_source.contains('not bool(_latest.get("ended", false))'),
		"doubles cover the battlefield with catalog effects and never skip live event batches")
	_expect(presenter_source.contains("is_instance_valid(_loading_overlay) and _loading_overlay.visible")
		and presenter_source.contains("if is_instance_valid(_native_turn):"),
		"native co-op teardown does not process stale loading or turn controls")
	_expect(presenter_source.contains("%MegaEvolutionIcon")
		and presenter_source.contains("%ZMove")
		and presenter_source.contains("func _toggle_mega_evolution()")
		and presenter_source.contains("func _toggle_z_move()")
		and presenter_source.contains("action.get(\"mega\", false)")
		and presenter_source.contains("action.get(\"zMove\", false)"),
		"native co-op mechanics use only the server-offered Mega and Z-Move action variants")
	_expect(presenter_source.contains('"-boost", "-unboost"')
		and presenter_source.contains("func _play_native_stat_change(")
		and FileAccess.get_file_as_string("res://scripts/battle/coop_native_animation_router.gd").contains("func play_stat_change_tween_for_target("),
		"native co-op stat changes animate only the affected doubles sprite")
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
	snapshot.ended = true
	var return_world := ReturnWorld.new()
	root.add_child(return_world)
	return_world.add_to_group("world")
	panel._playing = true
	service.apply_state({"activity": activity, "view": snapshot})
	_expect(panel._prompt.text.contains("both Trainers won") and panel._actions.get_child_count() == 0,
		"victory starts returning without a separate confirmation button")
	await process_frame
	_expect(return_world.finish_calls == 0, "automatic return waits for final event playback")
	panel._playing = false
	await process_frame
	_expect(return_world.finish_calls == 1, "victory invokes world return automatically")
	panel._latest.eventCursor = panel.displayed_cursor + 1
	_expect(panel._final_event_playback_pending(), "world return waits until the final shared event cursor is displayed")
	panel._latest.eventCursor = panel.displayed_cursor
	service.activity.outcome = "draw"
	service.activity.escaped = true
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._prompt.text.contains("fled") and panel._actions.get_child_count() == 0,
		"confirmed wild escape has no second confirmation")
	await process_frame
	_expect(return_world.finish_calls == 1 and panel._actions.get_child_count() == 0,
		"finished snapshots do not invoke world return twice")
	return_world.coop_finishing = false
	return_world.complete_on_finish = false
	panel._finished_return_started = false
	panel._action_signature = ""
	panel._update_actions()
	await process_frame
	_expect(return_world.finish_calls == 2 and panel._actions.get_child_count() == 1,
		"a failed automatic return offers a manual retry")
	return_world.complete_on_finish = true
	panel._finished_return_started = false
	panel._finished_return_retry_available = false
	service.activity.outcome = "loss"
	service.activity.escaped = false
	service.activity.forfeited = true
	panel._action_signature = ""
	panel._update_actions()
	_expect(panel._prompt.text.contains("forfeited") and panel._actions.get_child_count() == 0,
		"forfeit receipt identifies shared surrender and returns without confirmation")
	await process_frame
	_expect(return_world.finish_calls == 3, "forfeit also invokes automatic world return")
	return_world.queue_free()
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


func _capture_visual(environment_name: String) -> void:
	var capture_path := OS.get_environment(environment_name)
	if capture_path.is_empty():
		return
	await create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(capture_path) == OK, "visual acceptance snapshot saved")


func _wait_for_cursor(panel: Control, cursor: int) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while panel.displayed_cursor != cursor and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(panel.displayed_cursor == cursor, "presentation reaches its cursor within the bounded animation budget")
