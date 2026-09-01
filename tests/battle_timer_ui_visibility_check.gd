extends SceneTree

const PANEL_SCENE := preload("res://scenes/battle/vs_panel_container.tscn")
const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"


func _init() -> void:
	var battle_source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	_check(
		battle_source.contains('ProjectSettings.get_setting("battle/show_shadow_bank_timer", true)'),
		"bank timer visibility defaults on when a valid projection exists"
	)
	_check(not battle_source.to_lower().contains("server enforcement is still being finalized"), "technical preview warning is absent")
	_check(
		battle_source.contains('"TEAM_PREVIEW" if team_preview_lead_selection_active else ""'),
		"visible Team Preview overrides stale per-player decision labels"
	)
	_check(
		battle_source.contains('if state == "TIEBREAK":\n\t\tcolor = Color(1.0, 0.35, 0.25)\n\telif remaining_ms <= 15_000:'),
		"resolved Clash tiebreak status is steady while only the final countdown pulses"
	)
	await _check_supported_resolutions()
	print("PASS battle_timer_ui_visibility_check")
	quit(0)


func _check_supported_resolutions() -> void:
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		var host := Control.new()
		host.size = resolution
		root.add_child(host)
		var panel := PANEL_SCENE.instantiate()
		host.add_child(panel)
		await process_frame
		_check(not panel.player_1_timer_panel.visible, "player 1 timer block is hidden without a PvP projection")
		_check(not panel.player_2_timer_panel.visible, "player 2 timer block is hidden without a PvP projection")
		panel.player_1_label.text = "Alpha"
		panel.player_2_label.text = "Beta"
		panel.show_decision_timers(
			{
				"bankRemainingMs": 89_000,
				"bankMaximumMs": 90_000,
				"effectiveDecisionRemainingMs": 45_000,
				"decisionMaximumMs": 45_000,
				"decisionKind": "TEAM_PREVIEW",
				"state": "DECIDING",
			},
			{
				"bankRemainingMs": 80_000,
				"bankMaximumMs": 90_000,
				"effectiveDecisionRemainingMs": 90_000,
				"decisionMaximumMs": 90_000,
				"state": "DECIDING",
			}
		)
		_check(panel.player_1_timer_panel.visible, "player 1 timer block appears for PvP")
		_check(panel.player_2_timer_panel.visible, "player 2 timer block appears for PvP")
		_check(panel.player_1_timer_label.visible, "player 1 bank is visible at %s" % resolution)
		_check(panel.player_2_timer_label.visible, "player 2 bank is visible at %s" % resolution)
		_check(not panel.player_1_timer_label.text.contains("Bank"), "player 1 bank value stays hidden")
		_check(panel.player_1_timer_state_label.text == "%s · %s" % [_t("battle.timer.team_preview"), _t("battle.timer.choosing")], "Team Preview state is rendered")
		_check(panel.player_1_timer_label.text == _t("battle.timer.time", {"time": "00:45"}), "Team Preview countdown is rendered")
		_check(not panel.player_2_timer_label.text.contains("Bank"), "player 2 bank value stays hidden")
		_check(panel.player_2_timer_state_label.text == "%s · %s" % [_t("battle.timer.move"), _t("battle.timer.choosing")], "privacy-stripped active opponent still renders Move Choosing")
		_check(panel.player_2_timer_label.text == _t("battle.timer.time", {"time": "01:30"}), "privacy-stripped active opponent keeps its countdown")
		panel.show_decision_timers(
			{"effectiveDecisionRemainingMs": 30_000, "decisionMaximumMs": 30_000, "decisionKind": "TEAM_PREVIEW", "state": "DECIDING"},
			{"effectiveDecisionRemainingMs": 30_000, "decisionMaximumMs": 30_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"},
			"TEAM_PREVIEW"
		)
		_check(
			panel.player_2_timer_state_label.text == "%s · %s" % [_t("battle.timer.team_preview"), _t("battle.timer.choosing")],
			"active Team Preview keeps the opponent label in the shared preview phase"
		)
		_check_equal(panel.player_1_timer_bar.value, 100.0, "player 1 decision bar starts full")
		_check_equal(panel.player_2_timer_bar.value, 100.0, "player 2 decision bar starts full")
		panel.show_decision_timers(
			{"bankRemainingMs": 84_000, "bankMaximumMs": 90_000, "effectiveDecisionRemainingMs": 45_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"},
			{"bankRemainingMs": 80_000, "bankMaximumMs": 90_000, "state": "WAITING"}
		)
		_check_equal(panel.player_1_timer_bar.value, 50.0, "active decision bar decreases with server time")
		_check(not panel.player_2_timer_label.visible, "waiting side hides the irrelevant countdown")
		_check(not panel.player_2_timer_bar.visible, "waiting side hides the irrelevant progress bar")
		panel.show_decision_timers(
			{"decisionId": "4152e51d-ace8-4cac-9a8c-87c220a02321", "effectiveDecisionRemainingMs": 63_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "WAITING"},
			{"effectiveDecisionRemainingMs": 45_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"}
		)
		_check(panel.player_1_timer_state_label.text == _t("common.waiting"), "accepted choice uses the Waiting heading")
		_check(panel.player_1_timer_label.visible, "accepted choice keeps its frozen countdown visible")
		_check(panel.player_1_timer_label.text == _t("battle.timer.time", {"time": "01:03"}), "accepted choice shows the frozen remaining time")
		_check(panel.player_1_timer_bar.visible, "accepted choice keeps its frozen progress visible")
		_check_equal(panel.player_1_timer_bar.value, 70.0, "accepted choice freezes progress at submission")
		_check(not panel.player_1_timer_state_label.text.contains("4152e51d"), "timer text never renders an opaque decision id")
		panel.show_decision_timers(
			{"bankRemainingMs": 79_000, "bankMaximumMs": 90_000, "scheduledRemainingMs": 2_000, "decisionKind": "FORCED_SWITCH", "state": "SCHEDULED"},
			{"bankRemainingMs": 80_000, "bankMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "PAUSED"}
		)
		_check(panel.player_1_timer_state_label.text == _t("common.waiting"), "scheduled render safety is presented as ordinary waiting")
		_check(not panel.player_1_timer_label.visible, "scheduled render safety countdown stays hidden")
		_check(not panel.player_1_timer_bar.visible, "scheduled render safety progress stays hidden")
		_check(panel.player_2_timer_state_label.text == _t("battle.timer.paused"), "paused status is rendered")
		panel.show_decision_timers(
			{"bankRemainingMs": 0, "bankMaximumMs": 90_000, "effectiveDecisionRemainingMs": 0, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "EXPIRED"},
			{"bankRemainingMs": 80_000, "bankMaximumMs": 90_000, "state": "WAITING"}
		)
		_check(panel.player_1_timer_state_label.text == "%s · %s" % [_t("battle.timer.move"), _t("battle.timer.expired")], "expired status is rendered")
		_check(panel.player_1_timer_label.text == _t("battle.timer.time", {"time": "00:00"}), "expired display clamps at zero")
		_check_equal(panel.player_1_timer_bar.value, 0.0, "expired progress bar clamps at zero")
		var reconnect_deadline := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + 60, true)
		var reconnect_server_now := Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()), true)
		panel.show_reconnect_timer("p1", reconnect_deadline, 60, reconnect_server_now)
		panel.show_reconnect_timer("p2", reconnect_deadline, 60, reconnect_server_now)
		await process_frame
		_check(panel.player_2_timer_state_label.text == _t("battle.timer.disconnected"), "disconnected player state is visible")
		_check(panel.player_2_timer_label.text == _t("battle.timer.reconnect", {"time": "01:00"}), "reconnect countdown is visible beside the disconnected player")
		_check(panel.player_2_timer_bar.visible, "reconnect countdown progress is visible")
		_check(panel.has_active_reconnect_timer(), "two disconnected players keep the decision clocks paused")
		panel.clear_reconnect_timer("p2")
		_check(panel.player_2_timer_state_label.text == _t("common.waiting"), "reconnect restores the decision presentation")
		_check(panel.has_active_reconnect_timer(), "one reconnect does not clear the opponent reconnect state")
		_check(panel.player_1_timer_state_label.text == _t("battle.timer.disconnected"), "remaining opponent reconnect countdown stays visible")
		panel.hide_decision_timers()
		panel.show_decision_timers(
			{"effectiveDecisionRemainingMs": 43_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"},
			{"effectiveDecisionRemainingMs": 43_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"}
		)
		_check(panel.player_1_timer_state_label.text == _t("battle.timer.disconnected"), "normal battle HUD refresh preserves the remaining reconnect countdown")
		panel.clear_reconnect_timer("p1")
		_check(not panel.has_active_reconnect_timer(), "decision clocks resume only after every player reconnects")
		var player_text := "%s %s %s %s" % [panel.player_1_timer_state_label.text, panel.player_1_timer_label.text, panel.player_2_timer_state_label.text, panel.player_2_timer_label.text]
		for forbidden: String in ["Bank", "BATTLE_BANK_V1_SHADOW", "BATTLE_BANK_V1_AUTHORITY", "LEGACY_AUTHORITY", "LEGACY_PHASE_V1", "configurationHash", "timerContractVersion", "shadow"]:
			_check(not player_text.contains(forbidden), "player timer text hides %s" % forbidden)
		_check(panel.position.x >= 0.0, "timer panel stays on-screen at %s" % resolution)
		_check(panel.position.x + panel.size.x <= float(resolution.x), "timer panel fits width at %s" % resolution)
		panel.hide_decision_timers(true)
		_check(not panel.player_1_timer_panel.visible, "leaving PvP hides player 1 timer block")
		_check(not panel.player_2_timer_panel.visible, "leaving PvP hides player 2 timer block")
		panel.configure_compact_timer_mode(true, true)
		panel.show_decision_timers(
			{"effectiveDecisionRemainingMs": 12_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"},
			{"effectiveDecisionRemainingMs": 38_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"}
		)
		_check(not panel.names_panel.visible, "compact Calcdex timer hides the VS name card")
		_check(panel.player_1_timer_panel.visible, "compact Calcdex timer keeps the local countdown visible")
		_check(panel.player_2_timer_panel.visible, "wide compact Calcdex timer can show the opponent countdown")
		_check(panel.player_1_timer_state_label.text.begins_with(_t("ui.chat.you")), "compact local timer identifies the player")
		_check(panel.player_2_timer_state_label.text.begins_with(_t("battle.player.opponent")), "compact secondary timer identifies the opponent")
		_check(panel.player_1_timer_label.modulate.is_equal_approx(Color(1.0, 0.72, 0.24)), "compact timer warns the player when time is running low")
		_check_equal(panel.player_1_timer_panel.custom_minimum_size.x, 170.0, "compact timer cards use the reduced width")
		_check(panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "compact timer dock never intercepts battle input")
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
		panel.size = Vector2(370, 50)
		await process_frame
		_check(panel.get_combined_minimum_size().x <= 370.0, "wide compact timer fits the reserved Calcdex side space")
		panel.configure_compact_timer_mode(true, false)
		panel.size = Vector2(170, 50)
		await process_frame
		_check(panel.player_1_timer_panel.visible, "narrow compact timer prioritizes the local countdown")
		_check(not panel.player_2_timer_panel.visible, "narrow compact timer hides the secondary opponent countdown")
		_check(panel.get_combined_minimum_size().x <= 170.0, "narrow compact timer collapses to a single local card")
		host.queue_free()
		await process_frame


func _check(value: bool, label: String) -> void:
	if value:
		return
	push_error(label)
	quit(1)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s: expected %s got %s" % [label, str(expected), str(actual)])


func _t(key: String, replacements: Dictionary = {}) -> String:
	var localization_manager := root.get_node_or_null("LocalizationManager")
	if localization_manager != null:
		return str(localization_manager.call("text", key, replacements))
	return key
