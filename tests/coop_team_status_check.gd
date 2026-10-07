extends SceneTree

var completed_requests := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await _check_command_feedback()
	var service: Node = root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	var settings: Node = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2d"
	settings.battle_ui_layout = "immersive"
	settings.battle_animations = false
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var host: Control = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE, true)
	assert(battle.setup_coop_battle())
	host.request_reveal()
	var panel: Control = battle.coop_presenter
	var view := {"battleId": "coop-fixture", "revision": 1, "decisionId": "coop-1", "turn": 1,
		"participant": "p3", "locked": false, "partnerReady": true, "ended": false, "eventCursor": 0,
		"events": [], "field": {}, "forceSwitch": false, "opponentPartySize": 2,
		"legalActions": [{"type": "move", "slot": 1, "target": 1}],
		"moves": [{"slot": 1, "id": "tackle", "name": "Tackle", "pp": 35, "maxPp": 35, "type": "normal", "category": "Physical"}],
		"positions": [
			{"controller": "p1", "details": "Pidgey, L12", "hpPercent": 80},
			{"controller": "p3", "details": "Pikachu, L12", "hpPercent": 75},
			{"controller": "p2", "details": "Rattata, L12", "hpPercent": 100},
			{"controller": "p4", "details": "Caterpie, L12", "hpPercent": 100}],
		"ownTeam": [{"slot": 1, "species": "Pikachu", "active": true, "hp": 30, "maxHp": 40}],
		"partnerTeam": [{"slot": 1, "species": "Pidgey", "active": true, "hp": 32, "maxHp": 40}]}
	service.apply_state({"party": {"leaderId": 1, "memberIds": [1, 2], "memberUsernames": {"1": "adinho", "2": "m1bhompson"}},
		"activity": {"reservationId": "fixture", "battleId": "coop-fixture", "activityId": "wild_route_1", "status": "active", "partnerConnected": true}, "view": view})
	for _frame in 30:
		await process_frame
	var header: Control = battle.vs_panel_container
	var strip: Control = header.team_status_strip
	assert(strip != null and strip.trainer_rows.size() == 2)
	assert(strip.trainer_rows[0][0].name.text == "adinho")
	assert(strip.trainer_rows[0][1].name.text == "m1bhompson · You", "p3 must be the local Trainer")
	assert(strip.trainer_rows[0][0].status.text == "Ready ✓")
	assert(strip.trainer_rows[0][1].status.text == "Choosing…")
	assert(strip.trainer_rows[1][0].name.text == "Wild Pokémon" and strip.trainer_rows[1][0].status.text.is_empty(), "NPCs have no invented choice status")
	assert(not header.player_1_timer_panel.visible and not header.player_2_timer_panel.visible)
	await _capture("choosing")
	view.locked = true
	view.partnerReady = false
	view.revision = 2
	service.confirmed_decision_id = "coop-1"
	service.apply_view(view)
	assert(panel._prompt.text == "Choice confirmed · Waiting for adinho…")
	assert(strip.trainer_rows[0][1].status.text == "Ready ✓")
	var stable_rows: Array = strip.trainer_rows[0].duplicate()
	await _capture("waiting")
	service.activity.partnerConnected = false
	service.state_changed.emit()
	assert(strip.trainer_rows[0][0].status.text == "Disconnected")
	assert(panel._prompt.text.contains("adinho disconnected"))
	service.activity.partnerConnected = true
	service.confirmed_decision_id = ""
	view.forceSwitch = true
	view.locked = false
	view.revision = 3
	view.decisionId = "coop-2"
	service.apply_view(view)
	assert(strip.trainer_rows[0][1].status.text == "Choosing replacement…")
	service.pending_command = {"decisionId": "coop-2", "idempotencyKey": "choice"}
	panel._capture_animation_pending = true
	service.command_in_flight = true
	service.state_changed.emit()
	assert(strip.trainer_rows[0][1].status.text == "Sending…")
	assert(panel._prompt.text == "Sending your choice…", "a capture POST is sending, not animated playback")
	assert(panel._actions.get_child_count() == 0, "normal sending has no retry button")
	service.command_in_flight = false
	service.state_changed.emit()
	assert(strip.trainer_rows[0][1].status.text == "Checking…")
	assert(panel._actions.get_child_count() == 1, "uncertain submission exposes a durable retry")
	panel._capture_animation_pending = false
	service.pending_command = {}
	view.ended = true
	view.locked = true
	view.revision = 4
	service.view = view.duplicate(true)
	panel._latest = view.duplicate(true)
	panel._playing = true
	panel._update_actions()
	assert(panel._prompt.text == "Turn is playing…", "final animation takes priority over saving")
	panel._playing = false
	panel._update_actions()
	assert(panel._prompt.text == "Saving the battle result…")
	assert(strip.trainer_rows[0][0].name == stable_rows[0].name and strip.trainer_rows[0][1].status == stable_rows[1].status, "polls and phase changes reuse the same rows")
	var localization: Node = root.get_node("LocalizationManager")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
			root.size = resolution
			root.content_scale_size = resolution
			for _frame in 3:
				await process_frame
			_assert_header_bounds(battle)
		assert(not strip.trainer_rows[0][0].status.text.begins_with("battle.coop."))
	localization.set_locale("en")
	view.ended = false
	view.locked = false
	view.forceSwitch = false
	view.revision = 5
	service.apply_view(view)
	for _frame in 3:
		await process_frame
	header.show_team_status([
		{"name": "adinho", "local": true, "state": "ready"}, {"name": "m1bhompson", "state": "choosing"}],
		[{"name": "Trainer Three", "state": "choosing"}, {"name": "Trainer Four", "state": "ready"}])
	assert(strip.trainer_rows[1][1].name.text == "Trainer Four" and strip.trainer_rows[1][1].status.text == "Ready ✓", "both sides accept two public Trainer statuses")
	# Nested status chips need the container layout pass before measuring bounds.
	for _frame in 3:
		await process_frame
	await _capture("four-trainers")
	assert(strip.trainer_rows[0][0].status.text == "Ready ✓" and strip.trainer_rows[0][1].status.text == "Choosing…")
	_assert_header_bounds(battle)
	host.queue_free()
	service.reset()
	for _frame in 3:
		await process_frame
	print("PASS coop_team_status_check")
	quit(0)

func _assert_header_bounds(battle: Control) -> void:
	var header: Control = battle.vs_panel_container
	var rectangle := Rect2(header.position, header.size * header.scale)
	assert(rectangle.position.x >= 0 and rectangle.end.x <= battle.battle_stage.size.x)
	for card: Control in battle.get_node("ImmersiveHud").coop_huds.values():
		assert(card.position.y >= rectangle.end.y + 11.99, "HP cards leave room below team status")
	var turn: Control = battle.battle_status_panel
	assert(not rectangle.intersects(Rect2(turn.position, turn.size * turn.scale)), "team status leaves room for the turn indicator")
	for side_index in range(2):
		var side: Array = header.team_status_strip.trainer_rows[side_index]
		var side_bounds: Rect2 = header.team_status_strip.sides[side_index].get_global_rect()
		for row: Dictionary in side:
			# NPCs and empty rows have hidden chips; their old bounds are not drawn.
			if not row.status.is_visible_in_tree():
				continue
			assert(not row.name.get_global_rect().intersects(row.status.get_global_rect()), "names and statuses have distinct space")
			assert(row.status.get_global_rect().end.x <= side_bounds.end.x + 1.0, "each status stays inside its own side panel")

func _capture(name: String) -> void:
	var directory := OS.get_environment("COOP_TEAM_CAPTURE_DIR")
	if directory.is_empty():
		return
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(directory.path_join(name + ".png")) == OK)
	await process_frame

func _submit(fixture: Node, action: Dictionary) -> void:
	await fixture.submit_action(action)
	completed_requests += 1

func _retry(fixture: Node) -> void:
	await fixture.retry_command()
	completed_requests += 1

func _check_command_feedback() -> void:
	var fixture: Node = load("res://tests/fixtures/coop_command_status_fixture.gd").new()
	root.add_child(fixture)
	fixture.set_process(false)
	var action := {"type": "move", "slot": 1, "target": 1}
	var view := {"battleId": "test", "revision": 1, "decisionId": "first", "locked": false, "legalActions": [action]}
	fixture.activity = {"reservationId": "test", "battleId": "test"}
	fixture.view = view.duplicate(true)
	_submit(fixture, action)
	assert(fixture.command_in_flight and fixture.requests.size() == 1)
	var key: String = fixture.pending_command.idempotencyKey
	await fixture.retry_command()
	assert(fixture.requests.size() == 1, "a second click never resubmits an in-flight choice")
	fixture.response_ready.emit({"success": false, "status": 0})
	assert(not fixture.command_in_flight and fixture.pending_command.idempotencyKey == key)
	_retry(fixture)
	assert(fixture.requests[1].payload.idempotencyKey == key, "retry preserves the original durable receipt key")
	view.locked = true
	view.revision = 2
	fixture.response_ready.emit({"success": true, "body": {"view": view}})
	assert(not fixture.command_in_flight and fixture.pending_command.is_empty() and fixture.confirmed_decision_id == "first")
	view.locked = false
	view.revision = 3
	view.decisionId = "second"
	fixture.apply_view(view)
	assert(fixture.confirmed_decision_id.is_empty(), "a new turn clears the accepted-choice badge")
	_submit(fixture, action)
	fixture.reset()
	fixture.response_ready.emit({"success": true, "body": {"view": view}})
	assert(fixture.view.is_empty() and fixture.pending_command.is_empty() and not fixture.command_in_flight)
	assert(completed_requests == 3)
	fixture.queue_free()
	await process_frame
