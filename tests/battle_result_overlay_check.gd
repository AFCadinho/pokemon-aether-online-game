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
	_check(finish_source.contains("_show_pvp_battle_result(result)"), "PvP completion presents the result before exiting")
	_check(not finish_source.contains("battle_ended.emit(result)"), "PvP completion no longer destroys the battle scene immediately")
	_check(source.contains("func _on_battle_result_continue_pressed() -> void:"), "Continue closes the result screen")
	_check(source.contains('_t("battle.result.victory")'), "result screen supports a localized victory")
	_check(source.contains('_t("battle.result.defeat")'), "result screen supports a localized defeat")
	_check(source.contains('_t("battle.result.winner_title"'), "spectator result title names the public winner through a localized template")
	_check(source.contains("PvpBattleRealtimeService.is_local_terminal_winner("), "result screen resolves both winner sides and Showdown display names")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
