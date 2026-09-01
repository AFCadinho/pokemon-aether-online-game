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
	_check(source.contains("const AETHER_CLASH_RESULT_AUTO_CONTINUE_SECONDS := 5"), "Aether Clash result screen has a short fixed auto-continue countdown")
	_check(source.contains("func _is_aether_clash_battle() -> bool:"), "result countdown can be limited to Aether Clash battles")
	_check(source.contains("_start_battle_result_auto_continue()"), "showing an Aether Clash result starts the countdown")
	_check(source.contains('continue_text = "%s (%d)"'), "Continue button exposes the remaining countdown")
	_check(source.contains("func _on_battle_result_auto_continue_tick() -> void:"), "result countdown advances once per second")
	_check(source.contains("_complete_pvp_battle_result()"), "manual and automatic continuation share one completion path")
	_check(source.contains("func _close_battle_drawers_for_terminal_result() -> void:"), "battle completion has a shared terminal drawer cleanup")
	_check(source.contains("current_action_view = ActionView.NONE\n\t_set_action_panel_mode(BattleActionsPanelMode.BATTLE)"), "terminal drawer cleanup closes both the Bag and Damage Calc")
	_check(source.contains('_t("battle.result.victory")'), "result screen supports a localized victory")
	_check(source.contains('_t("battle.result.defeat")'), "result screen supports a localized defeat")
	_check(source.contains('_t("battle.result.winner_title"'), "spectator result title names the public winner through a localized template")
	_check(source.contains("PvpBattleRealtimeService.is_local_terminal_winner("), "result screen resolves both winner sides and Showdown display names")
	_check(source.contains("func _refresh_pvp_battle_rating(match_id: String) -> void:"), "rated PvP completion fetches the committed rating change")
	_check(source.contains('BattleApiClient.get_pvp_match_summary(request, normalized_match_id)'), "rating presentation reads the participant-authorized match summary")
	_check(source.contains('match.get("battlePointRewards", [])'), "Ranked completion reads the committed Battle Point reward")
	_check(source.contains('_t("battle.result.battle_points_reward"'), "Ranked completion presents the Battle Point payout")
	_check(source.contains("PlayerWalletService.load_wallet()") and source.contains("PlayerWalletService.apply_wallet_result(wallet_result)"), "Ranked completion refreshes the authoritative wallet balance")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
