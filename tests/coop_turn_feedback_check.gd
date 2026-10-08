extends SceneTree
## Real native playback and polling updates; no login or backend traffic.
var failed := false
var host: Control

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var settings: Node = root.get_node("SettingsManager")
	settings.battle_presentation_mode = "2d"
	settings.battle_ui_layout = "immersive"
	settings._manual_model_catalog_this_session = true
	settings.battle_animations = true
	settings.ui_scale = 100.0
	var service: Node = root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	host = load("res://scenes/battle/battle_screen_host.tscn").instantiate()
	var battle: Control = load("res://scenes/battle/battle.tscn").instantiate()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(1280, 720)
	host.mount(battle, null, WildEncounterTransition.STYLE_FULLSCREEN_FADE, true)
	_check(battle.setup_coop_battle(), "native co-op setup")
	var view := {"battleId": "feedback-fixture", "revision": 1, "decisionId": "feedback-1", "turn": 1,
		"participant": "p1", "locked": false, "partnerReady": false, "ended": false, "eventCursor": 4,
		"events": [], "field": {}, "opponentPartySize": 2,
		"moves": [{"slot": 1, "id": "tackle", "name": "Tackle", "pp": 35, "maxPp": 35, "type": "normal", "category": "Physical"}],
		"legalActions": [{"type": "move", "slot": 1, "target": 1}],
		"positions": [
			{"controller": "p1", "details": "Pidgey, L12", "hpPercent": 80},
			{"controller": "p3", "details": "Pikachu, L12", "hpPercent": 75},
			{"controller": "p2", "details": "Rattata, L12", "hpPercent": 100},
			{"controller": "p4", "details": "Caterpie, L12", "hpPercent": 100}],
		"ownTeam": [{"slot": 1, "species": "Pidgey", "active": true, "hp": 32, "maxHp": 40}],
		"partnerTeam": [{"slot": 1, "species": "Pikachu", "active": true, "hp": 30, "maxHp": 40}]}
	service.apply_state({"party": {"leaderId": 1, "memberIds": [1, 2], "memberUsernames": {"1": "adinho", "2": "m1bhompson"}},
		"activity": {"reservationId": "feedback", "battleId": "feedback-fixture", "activityId": "wild_route_1", "status": "active", "partnerConnected": true}, "view": view})
	host.request_reveal()
	for _frame in 30:
		await process_frame
	var panel: Control = battle.coop_presenter
	var hud: Node = battle.get_node("ImmersiveHud")
	# A newer projection already contains a changed identity and next-turn choices.
	# During the attack, the presenter must still name the earlier visible actor.
	view.revision = 2
	view.decisionId = "feedback-2"
	view.turn = 2
	view.eventCursor = 9
	view.positions[0].details = "Bulbasaur, L12"
	view.ownTeam[0].species = "Bulbasaur"
	view.positions[2].hpPercent = 65
	view.positions[3].hpPercent = 80
	view.events = [
		{"seq": 5, "kind": "move", "actor": "p1", "move": "Tackle", "target": "p2"},
		{"seq": 6, "kind": "-damage", "actor": "p2", "hpPercent": 65, "damagePercent": 35},
		{"seq": 7, "kind": "move", "actor": "p3", "move": "Tackle", "target": "p4"},
		{"seq": 8, "kind": "-damage", "actor": "p4", "hpPercent": 80, "damagePercent": 20},
		{"seq": 9, "kind": "detailschange", "actor": "p1", "details": "Bulbasaur, L12"}]
	panel._capture_feedback_text = "Old capture feedback"
	panel._capture_feedback_until_msec = Time.get_ticks_msec() + 4000
	service.apply_view(view)
	_check(panel._playing and panel._prompt.text.contains("adinho") and panel._prompt.text.contains("Pidgey")
		and panel._prompt.text.contains("Tackle") and not panel._prompt.text.contains("Bulbasaur"), "playback names the actual earlier actor, not the future snapshot identity")
	_check(battle.vs_panel_container.team_status_strip.trainer_rows[0][1].status.text == "Waiting…", "remote playback cannot be inferred from this screen or a new server decision")
	_check(service._presentation.phase == "playing" and service._presentation.eventCursor == 4, "real playback reports completed cursor rather than future snapshot cursor")
	var original_message: String = panel._prompt.text
	view.revision = 3
	service.apply_view(view)
	_check(panel._prompt.text == original_message and not panel._native_moves.visible, "a polling update retains current playback feedback and keeps next choices closed")
	hud.layout_now(0.0, true)
	_check(hud.coop_huds.p1.get_theme_stylebox("panel") == hud.coop_huds.p1.get_meta("coop_playback_style"), "the acting Pokémon's HP panel is highlighted")
	await _capture("playing-own")
	var deadline := Time.get_ticks_msec() + 10000
	while panel._playing and int(panel._playback_event.get("seq", 0)) < 7 and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(panel._playing and panel._prompt.text.contains("m1bhompson") and panel._prompt.text.contains("Pikachu"), "partner's actual action replaces own action feedback")
	hud.layout_now(0.0, true)
	_check(hud.coop_huds.p3.get_theme_stylebox("panel") == hud.coop_huds.p3.get_meta("coop_playback_style")
		and hud.coop_huds.p1.get_theme_stylebox("panel") == hud.coop_huds.p1.get_meta("coop_normal_style"), "HP emphasis follows the next actor")
	_check(not panel._first_trainer.visible, "a new actor without Trainer art clears the previous actor's command bubble")
	await _capture("playing-partner")
	while panel._playing and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not panel._playing and panel.displayed_cursor == 9 and panel._playback_event.is_empty(), "all public events finish before next-turn controls reopen")
	_check(service._presentation.phase == "idle" and service._presentation.eventCursor == 9, "real playback completion reports readiness to choose")
	panel._capture_feedback_text = ""
	panel._action_signature = ""
	panel._update_actions()
	hud.layout_now(0.0, true)
	_check(panel._native_moves.visible and hud.coop_huds.values().all(func(card: Control) -> bool:
		return card.get_theme_stylebox("panel") == card.get_meta("coop_normal_style")), "choice controls reopen and playback emphasis clears")
	# The partner can still animate after our controls reopen (different clients/speeds).
	service.activity.partnerPresentation = {"eventCursor": 4, "phase": "playing"}
	service.state_changed.emit()
	_check(not panel._playing and panel._trainer_choice_state("p3") == "playing", "partner playback is independent from our finished animation")
	_check(panel._native_moves.visible, "partner presentation never blocks our next legal choice")
	view.locked = true
	service.view = view.duplicate(true)
	panel._action_signature = "" # Manual fixture mutation bypasses the usual revision bump.
	service.state_changed.emit()
	_check(panel._prompt.text == "Waiting for m1bhompson's animations…", "waiting prompt does not claim an animating partner is choosing")
	service.activity.partnerPresentation = {"eventCursor": 4, "phase": "idle"}
	service.state_changed.emit()
	_check(panel._trainer_choice_state("p3") == "waiting" and panel._prompt.text == "Waiting for m1bhompson…", "older idle cursor is not proof the latest turn has played")
	service.activity.partnerPresentation = {"eventCursor": 9, "phase": "idle"}
	service.state_changed.emit()
	_check(panel._trainer_choice_state("p3") == "choosing" and panel._prompt.text.contains("to choose"), "only a caught-up idle report means choosing")
	service.activity.partnerPresentation = {"eventCursor": 10, "phase": "idle"}
	_check(panel._trainer_choice_state("p3") == "waiting", "a future report cannot label an older projection choosing")
	service.activity.partnerPresentation = {"eventCursor": 9, "phase": "idle"}

	panel._capture_feedback_text = "Earlier capture result"
	panel._capture_feedback_until_msec = Time.get_ticks_msec() + 4000
	view.locked = true
	view.revision = 4
	view.moves = []
	view.legalActions = []
	service.confirmed_decision_id = "feedback-2"
	service.apply_view(view)
	_check(panel._prompt.text == "Choice confirmed · Waiting for m1bhompson…", "waiting distinguishes authoritative choice acceptance from sending")
	await _capture("waiting-confirmed")
	service.confirmed_decision_id = ""
	panel._action_signature = ""
	panel._update_actions()
	_check(panel._prompt.text == "Waiting for m1bhompson to choose…", "an implicit lock does not invent an accepted choice")
	service.confirmed_decision_id = "feedback-2"
	view.partnerReady = true
	view.revision = 5
	service.apply_view(view)
	_check(panel._prompt.text == "Preparing the next turn…", "both ready transitions to preparation instead of asking the partner to choose")
	await _capture("preparing")
	# Public narration must stay translated through polls and final settlement.
	var localization: Node = root.get_node("LocalizationManager")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		localization.set_locale(locale)
		panel._playing = true
		panel._playback_event = {"kind": "move", "actor": "p3", "move": "Tackle"}
		panel._action_signature = ""
		panel._update_actions()
		_check(not panel._prompt.text.contains("battle.") and panel._prompt.text.contains("m1bhompson"), "localized public playback retains Trainer identity")
		service.activity.status = "finished"
		panel._finished_return_started = true
		panel._action_signature = ""
		panel._update_actions()
		_check(panel._prompt.text == panel._playback_message(), "final settlement cannot overwrite the final animation's action")
		service.activity.status = "active"
	panel._playing = false
	panel._playback_event = {}
	localization.set_locale("en")
	# Headless runs skip screenshot waits; let independent Trainer callout timers drain.
	await create_timer(TrainerCommandCallout.DISPLAY_SECONDS).timeout
	await process_frame
	print("COOP_TURN_FEEDBACK_", "FAIL" if failed else "OK")
	host.release()
	host.queue_free()
	service.reset()
	await process_frame
	await process_frame
	quit(1 if failed else 0)

func _capture(name: String) -> void:
	var directory := OS.get_environment("COOP_TURN_CAPTURE_DIR")
	if directory.is_empty() or DisplayServer.get_name() == "headless":
		return
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var transform: Transform2D = root.get_final_transform() * host.get_global_transform_with_canvas()
	var region := Rect2i(Rect2(transform * Vector2.ZERO, transform.basis_xform(host.size))).intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	_check(image.get_region(region).save_png(directory.path_join(name + ".png")) == OK, "turn feedback screenshot saved")
	# Resume UI changes outside the post-draw signal callback.
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
