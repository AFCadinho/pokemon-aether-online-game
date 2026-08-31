extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains('"ui.pvp.popup.ranked_subtitle"'), "Ranked header explains its active competitive format")
	_check(source.contains('var ranked_shell_style := _make_glass_panel_style(14)') and not source.contains('pvp_room_popup.add_theme_stylebox_override("panel", _make_gold_panel_style'), "Ranked uses the shared modern glass shell")
	_check(source.contains('var play_tab_page := _create_pvp_ranked_tab_page("Play")'), "Ranked keeps a dedicated Play destination")
	_check(source.contains('var leaderboard_tab_page := _create_pvp_ranked_tab_page("Leaderboard")'), "Ranked keeps a dedicated Leaderboard destination")
	_check(source.contains('var rewards_tab_page := _create_pvp_ranked_tab_page("Rewards")'), "Ranked keeps a dedicated Rewards destination")
	_check(source.contains('var overview_tab_page := _create_pvp_ranked_tab_page("Overview", 8)') and source.contains('var battle_tab_page := _create_pvp_ranked_tab_page("Battle Rewards", 8)') and source.contains('var placements_tab_page := _create_pvp_ranked_tab_page("Placements", 8)') and source.contains('var objectives_tab_page := _create_pvp_ranked_tab_page("Objectives", 8)') and source.contains('var season_tab_page := _create_pvp_ranked_tab_page("Season", 8)'), "Rewards scales through Overview, battle, placement, objective and season subtabs")
	_check(source.contains('"ui.pvp.rewards.status_inactive"') and source.contains('"ui.pvp.rewards.activation_note"'), "Rewards clearly remain inactive until the backend enables grants")
	_check(source.contains('"ui.pvp.rewards.battle.win_value"') and source.contains('"ui.pvp.rewards.battle.loss_value"'), "Rewards previews the planned per-battle Battle Point amounts")
	_check(source.contains('"RankedPlacementRewardCard"') and source.contains('"RankedObjectivesRewardCard"') and source.contains('"RankedSeasonRewardCard"'), "Rewards reserves clear sections for placements, objectives and season rewards")
	_check(source.contains('pvp_ranked_objectives_filter = OptionButton.new()') and source.contains('_apply_pvp_ranked_dropdown_style(pvp_ranked_objectives_filter, true)'), "Objective periods use a compact filter inside the Objectives subtab")
	_check(source.contains('"ui.pvp.leaderboard.title"'), "Leaderboard clearly names the active ladder")
	_check(source.contains('"ui.pvp.leaderboard.period"') and source.contains("_apply_pvp_leaderboard_scope_style(pvp_leaderboard_scope_select)"), "Leaderboard period filter is presented as a compact control")
	_check(source.contains("_apply_pvp_ranked_dropdown_style(pvp_queue_select)"), "Play format uses the shared Ranked dropdown style")
	_check(source.contains('_create_pvp_leaderboard_header_label("ui.pvp.leaderboard.column.rank", 54') and source.contains('_create_pvp_leaderboard_header_label("ui.pvp.leaderboard.column.rating", 96') and source.contains('_create_pvp_leaderboard_header_label("ui.pvp.leaderboard.column.record", 104') and source.contains('_create_pvp_leaderboard_header_label("ui.pvp.leaderboard.column.win_rate", 86'), "Leaderboard columns prioritize rank, Elo rating, record and win rate")
	_check(source.contains("func _pvp_leaderboard_rank_color(rank: int)") and source.contains('return Color("#ffd45a")') and source.contains('return Color("#d3deea")') and source.contains('return Color("#e0a06c")'), "Top three ladder ranks have distinct medal colors")
	_check(source.contains("var is_current_player := _is_current_auth_user(entry)") and source.contains('"ui.pvp.leaderboard.you"'), "Leaderboard highlights the signed-in player")
	_check(not source.contains("player_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS"), "Leaderboard player names retain their content width")
	_check(source.contains('"ui.pvp.leaderboard.record"') and source.contains("func _pvp_leaderboard_rating_color(rating: int)"), "Leaderboard renders compact records and Elo states")
	_check(source.contains('"ui.pvp.leaderboard.provisional"') and source.contains('entry.get("provisional", games_played < 10)'), "Leaderboard marks the first ten rating games as provisional")
	_check(source.contains('"ui.pvp.leaderboard.empty"') and source.contains('"ui.pvp.leaderboard.unavailable"') and source.contains('"ui.pvp.leaderboard.updating_title"'), "Leaderboard has dedicated empty, error and loading states")
	_check(source.contains('var battles_tab_page := _create_pvp_ranked_tab_page("Battles")'), "Live battles and player history share one Battles destination")
	_check(source.contains('var live_tab_page := _create_pvp_ranked_tab_page("Live", 8)') and source.contains('var history_tab_page := _create_pvp_ranked_tab_page("My History", 8)'), "Battles exposes Live and My History subtabs")
	_check(source.contains('var rules_tab_page := _create_pvp_ranked_tab_page("Rules")'), "Ranked keeps a dedicated Rules destination")
	_check(source.contains('var format_tab_page := _create_pvp_ranked_tab_page("Format", 8)') and source.contains('var bans_tab_page := _create_pvp_ranked_tab_page("Banlist", 8)'), "Rules exposes Format and Banlist subtabs")

	_check(source.contains('_create_pvp_section_title("ui.pvp.team.selected")') and source.contains('"ui.pvp.team.current"'), "Play clearly identifies the selected team source")
	_check(source.contains("panel.custom_minimum_size = Vector2(62, 62)") and source.contains("icon.custom_minimum_size = Vector2(52, 52)"), "Selected team uses larger readable Pokemon slots")
	_check(source.contains('"ui.pvp.team.validation"'), "Team validation remains a prominent part of Play")
	_check(source.contains('"ui.pvp.validation.issue.one"') and source.contains('"ui.pvp.validation.issue.many"'), "Invalid teams report an actionable issue count")
	_check(source.contains('"ui.pvp.validation.ranked_ready"'), "Valid teams receive a clear Ranked Ready state")
	_check(source.contains('PvpRankedTeamValidation.allows_ranked_join(pvp_ranked_team_validation_result)'), "authoritative validation still gates ranked matchmaking")
	_check(source.contains("if server_is_authoritative:\n\t\t\t_render_pvp_ranked_server_validation()"), "authoritative Ranked validation keeps its detailed reasons visible after local checks")
	_check(source.contains('pvp_team_validator_panel.add_theme_stylebox_override("panel", _make_pvp_validator_panel_style(state))'), "validator surface reflects checking, valid and invalid states")

	_check(source.contains('"ui.pvp.queue.find"') and source.contains("pvp_join_queue_button.custom_minimum_size = Vector2(0, 46)"), "Find Match is the primary full-width action")
	_check(source.contains("pvp_join_queue_button.visible = not is_waiting and not has_match"), "Find Match only appears while idle")
	_check(source.contains("pvp_leave_queue_button.visible = is_waiting and not has_match"), "Leave Queue replaces Find Match while searching")
	_check(source.contains("pvp_reconnect_battle_button.visible = has_match"), "Reconnect only appears when a match exists")
	_check(source.contains("pvp_queue_ball_spin.gdshader") and source.contains("_setup_pvp_queue_ball_spin()"), "Ranked queue balls use shader-based smooth rotation")
	_check(not source.contains("pvp_queue_red_ball.rotation +="), "Ranked queue balls avoid pixel-snapped Control rotation")
	_check(not source.contains('_create_pvp_section_title("General Information")'), "Play no longer spends its main panel on static general information")

	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
