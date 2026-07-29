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
				"decisionKind": "MOVE_SELECTION",
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
		_check(panel.player_2_timer_state_label.text == "%s · %s" % [_t("battle.timer.move"), _t("battle.timer.choosing")], "Move Selection state is rendered")
		_check(panel.player_2_timer_label.text == _t("battle.timer.time", {"time": "01:30"}), "Move Selection countdown is rendered")
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
			{"effectiveDecisionRemainingMs": 63_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "WAITING"},
			{"effectiveDecisionRemainingMs": 45_000, "decisionMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"}
		)
		_check(panel.player_1_timer_state_label.text == _t("common.waiting"), "accepted choice uses the Waiting heading")
		_check(panel.player_1_timer_label.text == _t("battle.timer.time", {"time": "01:03"}), "accepted choice keeps its frozen decision time visible")
		_check_equal(panel.player_1_timer_bar.value, 70.0, "accepted choice keeps its frozen progress visible")
		panel.show_decision_timers(
			{"bankRemainingMs": 79_000, "bankMaximumMs": 90_000, "scheduledRemainingMs": 2_000, "decisionKind": "FORCED_SWITCH", "state": "SCHEDULED"},
			{"bankRemainingMs": 80_000, "bankMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "PAUSED"}
		)
		_check(panel.player_1_timer_state_label.text == "%s · %s" % [_t("battle.timer.forced_switch"), _t("battle.timer.scheduled")], "scheduled Forced Switch is rendered")
		_check(panel.player_1_timer_label.text == _t("battle.timer.starts", {"time": "00:02"}), "scheduled start countdown is rendered")
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
