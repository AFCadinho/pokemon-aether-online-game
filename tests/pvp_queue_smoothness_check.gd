extends SceneTree

const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	var open_start := source.find("func _open_pvp_popup_section(section_name: String) -> void:")
	var open_end := source.find("func _pvp_popup_title_for_section", open_start)
	var open_source := source.substr(open_start, open_end - open_start)
	var tab_start := source.find("func _on_pvp_ranked_tab_changed(tab_index: int) -> void:")
	var tab_end := source.find("func _on_pvp_ranked_rules_tab_changed", tab_start)
	var tab_source := source.substr(tab_start, tab_end - tab_start)
	var join_start := source.find("func _on_pvp_join_queue_pressed() -> void:")
	var join_end := source.find("func _refresh_pvp_queue_list", join_start)
	var join_source := source.substr(join_start, join_end - join_start)

	_check_true(open_start >= 0 and open_end > open_start, "Ranked popup loading boundary exists")
	_check_true(
		not open_source.contains("_refresh_pvp_banlists")
			and not open_source.contains("_refresh_pvp_leaderboard")
			and not open_source.contains("_refresh_pvp_match_history"),
		"opening Ranked does not wait for hidden tabs"
	)
	_check_true(
		tab_source.contains('_refresh_pvp_banlists_if_selected()')
			and tab_source.contains('_refresh_pvp_leaderboard.call_deferred(false)')
			and tab_source.contains('_refresh_pvp_match_history.call_deferred(false)'),
		"Ranked tabs load their own data on demand"
	)
	_check_true(
		source.contains("var pvp_leaderboard_loaded := false")
			and source.contains("var pvp_history_loaded := false")
			and source.contains("func _invalidate_pvp_ranked_lazy_data() -> void:"),
		"lazy Ranked data is cached and invalidated with its format"
	)
	_check_true(
		join_source.contains("not PvpRankedTeamValidation.allows_ranked_join(pvp_ranked_team_validation_result)")
			and not join_source.contains('pvp_ranked_team_validation_party_signature = ""'),
		"an already valid team joins without a redundant validation request"
	)
	_check_true(
		source.contains("const PVP_QUEUE_POLL_INTERVAL_SECONDS := 1.0")
			and source.contains("pvp_poll_timer.wait_time = PVP_QUEUE_POLL_INTERVAL_SECONDS"),
		"active matchmaking checks for a match once per second"
	)
	_check_true(
		source.contains('pvp_queue_joined_at_unix = _pvp_iso_timestamp_to_unix_time(str(entry.get("joinedAt", "")))')
			and source.contains("Time.get_unix_time_from_system() - pvp_queue_joined_at_unix"),
		"queue elapsed time resumes from the authoritative joinedAt timestamp"
	)

	if not failed:
		print("PASS pvp_queue_smoothness_check")
	quit(1 if failed else 0)


func _check_true(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
