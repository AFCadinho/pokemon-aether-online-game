extends SceneTree


func _init() -> void:
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	var realtime_source := FileAccess.get_file_as_string(
		"res://scripts/services/pvp_battle_realtime_service.gd"
	)

	_check(
		realtime_source.contains('if message_type in ["pvp.forfeit", "pvp.match_ended", "pvp.match_settled"]:') \
			and realtime_source.contains('if active_viewer_role == "spectator":') \
			and realtime_source.contains("battle_update_received.emit(message)"),
		"realtime transport forwards public terminal fallbacks to spectators"
	)
	_check(
		battle_source.contains('if _is_spectator_terminal_message(message):') \
			and battle_source.contains('"pvp.forfeit"') \
			and battle_source.contains('"pvp.match_ended"') \
			and battle_source.contains('"pvp.match_settled"') \
			and battle_source.contains("_finish_spectator_terminal_message.call_deferred"),
		"public spectator terminal messages bypass the ordinary battle update queue"
	)
	_check(
		battle_source.contains("func _finish_spectator_terminal_message(message: Dictionary) -> void:") \
			and battle_source.contains('str(message.get("winnerSide", ""))') \
			and battle_source.contains('str(message.get("loserSide", ""))') \
			and battle_source.contains('finish_result["winner"] = winner_side') \
			and battle_source.contains('"skipPartyBattleSync": true') \
			and battle_source.contains('"localPartyDefeated": false'),
		"spectator terminal handling preserves the public winner without participant persistence"
	)
	_check(
		battle_source.contains("if allows_gameplay_persistence or _is_spectator_battle():") \
			and battle_source.contains('current_action_panel.set_message(message)') \
			and battle_source.contains('_t("battle.result.winner_title", {"winner": winner_name})'),
		"spectator winner appears in the battle log, battle text, and result screen"
	)
	_check(
		battle_source.contains("func _hide_spectator_rosters_for_terminal_result() -> void:") \
			and battle_source.contains("if _is_spectator_battle():\n\t\t_hide_spectator_rosters_for_terminal_result()") \
			and battle_source.contains("player_party_grid.visible = false") \
			and battle_source.contains("opponent_stage_party_rail.visible = false"),
		"spectator result overlay hides observed team rails"
	)
	_check(
		battle_source.contains("if battle_finished:") \
			and battle_source.contains("var completed_result := pending_battle_end_result.duplicate(true)") \
			and battle_source.contains("_emit_battle_ended(completed_result)"),
		"Leave Battle can close an already-terminal spectator battle"
	)

	if checks_passed:
		quit(0)


var checks_passed := true


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("FAIL %s" % label)
	checks_passed = false
	quit(1)
