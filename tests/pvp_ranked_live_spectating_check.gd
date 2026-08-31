extends SceneTree

const UI_PATH := "res://scripts/ui/ui_overlay.gd"
const API_PATH := "res://scripts/battle/battle_api/battle_api_client.gd"

var failed := false


func _init() -> void:
	var ui_source := FileAccess.get_file_as_string(UI_PATH)
	var api_source := FileAccess.get_file_as_string(API_PATH)

	_check(
		api_source.contains("func get_live_ranked_pvp_matches(") \
			and api_source.contains('"/account/pvp/ranked/live?limit=%d"') \
			and api_source.contains("func spectate_ranked_pvp_match(") \
			and api_source.contains('"/battle/pvp/matches/%s/spectate"'),
		"Ranked live discovery and match spectate endpoints are exposed to the client"
	)
	_check(
		ui_source.contains("pvp_ranked_battles_tabs.tab_changed.connect(_on_pvp_ranked_battles_tab_changed)") \
			and ui_source.contains("func _refresh_pvp_live_battles(force: bool = false) -> void:") \
			and ui_source.contains("BattleApiClient.get_live_ranked_pvp_matches("),
		"The Ranked Battles Live tab lazily loads ongoing battles"
	)
	_check(
		ui_source.contains("func _create_pvp_live_battle_row(entry: Dictionary) -> Control:") \
			and ui_source.contains("_on_pvp_live_watch_pressed.bind(match_id)") \
			and ui_source.contains("matchup_label.text = _pvp_live_players_label(entry)") \
			and ui_source.contains('watch_button.text = LocalizationManager.text("ui.pvp.room.spectate")') \
			and ui_source.contains('_apply_button_style(watch_button, "primary")') \
			and ui_source.contains("BattleApiClient.spectate_ranked_pvp_match(") \
			and ui_source.contains("func _pvp_live_watch_blocked() -> bool:") \
			and ui_source.contains('or pvp_active_queue_entry_id != ""'),
		"Live battle rows open the existing spectator battle flow by match id"
	)
	_check(
		ui_source.contains("not _spectator_response_has_public_teams(response)") \
			and ui_source.contains("await _start_pvp_battle_from_response(response)"),
		"Ranked spectating preserves the public-team boundary before opening battle"
	)

	if not failed:
		print("PASS pvp_ranked_live_spectating_check")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
