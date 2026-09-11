extends SceneTree

const BATTLE_LOG_PANEL_PATH := "res://scripts/battle/battle_ui/battle_log_panel.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(BATTLE_LOG_PANEL_PATH)
	_check(not source.contains("────────────"), "battle-log turn divider does not use unsupported box-drawing glyphs")
	_check(source.contains("------------"), "battle-log turn divider uses an ASCII-safe fallback")
	quit(1 if failed else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: %s" % description)
		return
	failed = true
	push_error("FAIL: %s" % description)
