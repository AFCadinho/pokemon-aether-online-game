extends SceneTree

const PANEL_SCENE := preload("res://scenes/battle/battle_status_panel.tscn")
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
		root.size = resolution
		var panel := PANEL_SCENE.instantiate()
		root.add_child(panel)
		await process_frame
		panel.show_bank_timers(
			{
				"bankRemainingMs": 89_000,
				"effectiveDecisionRemainingMs": 45_000,
				"decisionKind": "TEAM_PREVIEW",
				"state": "DECIDING",
			},
			{
				"bankRemainingMs": 80_000,
				"effectiveDecisionRemainingMs": 20_000,
				"decisionKind": "MOVE_SELECTION",
				"state": "DECIDING",
			}
		)
		_check(panel.local_timer_label.visible, "local bank is visible at %s" % resolution)
		_check(panel.opponent_timer_label.visible, "opponent bank is visible at %s" % resolution)
		_check(panel.local_timer_label.text.contains("You 01:29"), "local bank value is rendered")
		_check(panel.local_timer_label.text.contains("Team Preview 00:45"), "Team Preview countdown is rendered")
		_check(panel.opponent_timer_label.text.contains("Opponent 01:20"), "opponent bank value is rendered")
		_check(panel.opponent_timer_label.text.contains("Move 00:20"), "Move Selection countdown is rendered")
		panel.show_bank_timers(
			{"bankRemainingMs": 79_000, "scheduledRemainingMs": 2_000, "decisionKind": "FORCED_SWITCH", "state": "SCHEDULED"},
			{"bankRemainingMs": 80_000, "decisionKind": "MOVE_SELECTION", "state": "PAUSED"}
		)
		_check(panel.local_timer_label.text.contains("Forced Switch starts 00:02 · Scheduled"), "scheduled Forced Switch is rendered")
		_check(panel.opponent_timer_label.text.ends_with("Paused"), "paused status is rendered")
		panel.show_bank_timers(
			{"bankRemainingMs": 0, "effectiveDecisionRemainingMs": 0, "decisionKind": "MOVE_SELECTION", "state": "EXPIRED"},
			{"bankRemainingMs": 80_000, "state": "WAITING"}
		)
		_check(panel.local_timer_label.text.contains("Move 00:00 · Time expired"), "expired display clamps at zero")
		var player_text := "%s %s" % [panel.local_timer_label.text, panel.opponent_timer_label.text]
		for forbidden: String in ["BATTLE_BANK_V1_SHADOW", "LEGACY_PHASE_V1", "configurationHash", "timerContractVersion", "shadow"]:
			_check(not player_text.contains(forbidden), "player timer text hides %s" % forbidden)
		_check(panel.position.x >= 0.0, "timer panel stays on-screen at %s" % resolution)
		_check(panel.position.x + panel.size.x <= float(resolution.x), "timer panel fits width at %s" % resolution)
		panel.queue_free()
		await process_frame


func _check(value: bool, label: String) -> void:
	if value:
		return
	push_error(label)
	quit(1)
