extends SceneTree

const TEAM_PREVIEW_LAYER_PATH := "res://scripts/battle/battle_ui/team_preview_layer.gd"

var failures := 0


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var source := FileAccess.get_file_as_string(TEAM_PREVIEW_LAYER_PATH)
	_check(not source.is_empty(), "Team Preview layer source is available")
	_check(source.contains("var team_is_shown := false"), "Team Preview tracks pre-ready content")
	_check(
		source.contains("if not team_is_shown:\n\t\tclear()"),
		"Team Preview only clears its editor placeholders when not already populated"
	)
	_check(
		source.contains("team_is_shown = true\n\tvisible = true"),
		"show_team marks the populated preview before making it visible"
	)
	_check(
		source.contains("team_is_shown = false\n\tvisible = false"),
		"clear resets the populated-preview lifecycle state"
	)
	if failures > 0:
		quit(1)
		return
	print("PASS team_preview_layer_lifecycle_check")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAIL: %s" % message)
