extends SceneTree

const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check(source.contains('match.get("battleId", "")'), "history reads the authoritative Battle ID")
	_check(source.contains('get("finalBattleId", "")'), "history supports the settled Battle ID fallback")
	_check(source.contains('"ui.pvp.history.battle_id"'), "history displays a compact Battle ID")
	_check(source.contains('"ui.pvp.history.battle_code"'), "history exposes the full battle code")
	_check(source.contains("DisplayServer.clipboard_set(battle_id)"), "history copies the full Battle ID")
	_check(source.contains('copy_battle_id_button.text = LocalizationManager.text("ui.pvp.room.copy")'), "history provides a copy action")
	_check(source.contains('if battle_id != "":'), "history omits the action when no Battle ID exists")

	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if value:
		return
	failed = true
	push_error(label)
