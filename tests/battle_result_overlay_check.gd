extends SceneTree

const BATTLE_SCRIPT_PATH := "res://scripts/battle/battle.gd"
const BATTLE_SCENE_PATH := "res://scenes/battle/battle.tscn"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_SCRIPT_PATH)
	var scene_source := FileAccess.get_file_as_string(BATTLE_SCENE_PATH)
	var finish_index := source.find("func _finish_battle(result: Dictionary) -> void:")
	var finish_next_index := source.find("\nfunc ", finish_index + 1)
	var finish_source := source.substr(finish_index, finish_next_index - finish_index)

	_check(scene_source.contains('[node name="BattleResultOverlay" type="Control"'), "battle scene has a terminal result overlay")
	_check(scene_source.contains('[node name="BattleResultContinueButton" type="Button"'), "result overlay has an explicit Continue action")
	_check(scene_source.contains('[node name="BattleResultRating" type="Label"'), "result overlay has a dedicated rating change line")
	_check(finish_source.contains("_show_pvp_battle_result(result)"), "PvP completion presents the result before exiting")
	_check(finish_source.contains("_close_battle_drawers_for_terminal_result()"), "terminal completion closes battle drawers before presenting the result")
	_check(not finish_source.contains("battle_ended.emit(result)"), "PvP completion no longer destroys the battle scene immediately")
	_check(source.contains("func _on_battle_result_continue_pressed() -> void:"), "Continue closes the result screen")
	_check(source.contains("func _close_battle_drawers_for_terminal_result() -> void:"), "battle completion has a shared terminal drawer cleanup")
	_check(source.contains("current_action_view = ActionView.NONE\n\t_set_action_panel_mode(BattleActionsPanelMode.BATTLE)"), "terminal drawer cleanup closes both the Bag and Damage Calc")
	_check(source.contains('_t("battle.result.victory")'), "result screen supports a localized victory")
	_check(source.contains('_t("battle.result.defeat")'), "result screen supports a localized defeat")
	_check(source.contains('_t("battle.result.winner_title"'), "spectator result title names the public winner through a localized template")
	_check(source.contains("PvpBattleRealtimeService.is_local_terminal_winner("), "result screen resolves both winner sides and Showdown display names")
	_check(source.contains("func _refresh_pvp_battle_rating(match_id: String) -> void:"), "rated PvP completion fetches the committed rating change")
	_check(source.contains('BattleApiClient.get_pvp_match_summary(request, normalized_match_id)'), "rating presentation reads the participant-authorized match summary")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
