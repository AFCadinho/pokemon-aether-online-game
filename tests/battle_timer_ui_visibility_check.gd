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
		panel.show_bank_timers(
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
				"effectiveDecisionRemainingMs": 20_000,
				"decisionMaximumMs": 20_000,
				"decisionKind": "MOVE_SELECTION",
				"state": "DECIDING",
			}
		)
		_check(panel.player_1_timer_panel.visible, "player 1 timer block appears for PvP")
		_check(panel.player_2_timer_panel.visible, "player 2 timer block appears for PvP")
		_check(panel.player_1_timer_label.visible, "player 1 bank is visible at %s" % resolution)
		_check(panel.player_2_timer_label.visible, "player 2 bank is visible at %s" % resolution)
		_check(panel.player_1_timer_label.text.contains("Bank 01:29"), "player 1 bank value is rendered")
		_check(panel.player_1_timer_state_label.text == "Team Preview · Choosing", "Team Preview state is rendered")
		_check(panel.player_1_timer_label.text.contains("Decision 00:45"), "Team Preview countdown is rendered")
		_check(panel.player_2_timer_label.text.contains("Bank 01:20"), "player 2 bank value is rendered")
		_check(panel.player_2_timer_state_label.text == "Move · Choosing", "Move Selection state is rendered")
		_check(panel.player_2_timer_label.text.contains("Decision 00:20"), "Move Selection countdown is rendered")
		_check_equal(panel.player_1_timer_bar.value, 100.0, "player 1 decision bar starts full")
		_check_equal(panel.player_2_timer_bar.value, 100.0, "player 2 decision bar starts full")
		panel.show_bank_timers(
			{"bankRemainingMs": 84_000, "bankMaximumMs": 90_000, "effectiveDecisionRemainingMs": 15_000, "decisionMaximumMs": 30_000, "decisionKind": "MOVE_SELECTION", "state": "DECIDING"},
			{"bankRemainingMs": 80_000, "bankMaximumMs": 90_000, "state": "WAITING"}
		)
		_check_equal(panel.player_1_timer_bar.value, 50.0, "active decision bar decreases with server time")
		_check(panel.player_2_timer_bar.value > panel.player_1_timer_bar.value, "waiting side keeps an independent bar")
		panel.show_bank_timers(
			{"bankRemainingMs": 79_000, "bankMaximumMs": 90_000, "scheduledRemainingMs": 2_000, "decisionKind": "FORCED_SWITCH", "state": "SCHEDULED"},
			{"bankRemainingMs": 80_000, "bankMaximumMs": 90_000, "decisionKind": "MOVE_SELECTION", "state": "PAUSED"}
		)
		_check(panel.player_1_timer_state_label.text == "Forced Switch · Scheduled", "scheduled Forced Switch is rendered")
		_check(panel.player_1_timer_label.text.contains("Starts 00:02"), "scheduled start countdown is rendered")
		_check(panel.player_2_timer_state_label.text == "Paused", "paused status is rendered")
		panel.show_bank_timers(
			{"bankRemainingMs": 0, "bankMaximumMs": 90_000, "effectiveDecisionRemainingMs": 0, "decisionMaximumMs": 20_000, "decisionKind": "MOVE_SELECTION", "state": "EXPIRED"},
			{"bankRemainingMs": 80_000, "bankMaximumMs": 90_000, "state": "WAITING"}
		)
		_check(panel.player_1_timer_state_label.text == "Move · Time expired", "expired status is rendered")
		_check(panel.player_1_timer_label.text.contains("Decision 00:00"), "expired display clamps at zero")
		_check_equal(panel.player_1_timer_bar.value, 0.0, "expired progress bar clamps at zero")
		var player_text := "%s %s %s %s" % [panel.player_1_timer_state_label.text, panel.player_1_timer_label.text, panel.player_2_timer_state_label.text, panel.player_2_timer_label.text]
		for forbidden: String in ["BATTLE_BANK_V1_SHADOW", "LEGACY_PHASE_V1", "configurationHash", "timerContractVersion", "shadow"]:
			_check(not player_text.contains(forbidden), "player timer text hides %s" % forbidden)
		_check(panel.position.x >= 0.0, "timer panel stays on-screen at %s" % resolution)
		_check(panel.position.x + panel.size.x <= float(resolution.x), "timer panel fits width at %s" % resolution)
		panel.hide_bank_timers()
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
