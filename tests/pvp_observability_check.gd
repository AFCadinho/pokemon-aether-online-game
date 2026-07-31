extends SceneTree


func _init() -> void:
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	var realtime_source := FileAccess.get_file_as_string("res://scripts/services/pvp_battle_realtime_service.gd")
	var required_fragments: Array[String] = [
		"func report_diagnostic(event_type: String, context: Dictionary = {}) -> bool:",
		'"type": "diagnostic"',
		'"pvp.client_waiting_state"',
		'"pvp.invalid_realtime_response"',
		'"pvp.realtime_response_timeout"',
		'"pvp.event_sequence_gap"',
		'"pvp.resync_required_received"',
	]
	for fragment in required_fragments:
		if not realtime_source.contains(fragment) and not battle_source.contains(fragment):
			push_error("Missing PvP observability contract fragment: %s" % fragment)
			quit(1)
			return

	var report_start := realtime_source.find("func report_diagnostic")
	var send_action_start := realtime_source.find("func send_action", report_start)
	var report_source := realtime_source.substr(report_start, send_action_start - report_start)
	for forbidden_key in ["team", "moves", "pokemon", "message", "response", "token", "battleId", "matchId", "userId", "playerSide"]:
		if report_source.contains('"%s"' % forbidden_key):
			push_error("PvP diagnostic payload exposes forbidden key: %s" % forbidden_key)
			quit(1)
			return

	print("PASS pvp_observability_check")
	quit(0)
