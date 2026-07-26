extends SceneTree

const LOADING_SCREEN_SCRIPT := "res://scripts/ui/loading_screen.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(LOADING_SCREEN_SCRIPT)
	_check(source.contains('"Preparing your adventure"'), "loading screen uses the current player-facing title")
	_check(source.contains('"●  SECURE TRAINER SESSION"'), "loading screen identifies the authenticated transition")
	_check(source.contains("GradientTexture2D.FILL_RADIAL"), "loading screen uses the current aura treatment")
	_check(source.contains("func _create_loading_spinner()"), "loading screen builds a dedicated activity spinner")
	_check(source.contains('"rotation", TAU, 0.85'), "loading spinner rotates continuously without implying percentage progress")
	_check(source.contains('["TRAINER", "PARTY", "WORLD"]'), "loading screen communicates its three preparation stages")
	_check(source.contains("_set_loading_status"), "loading flow updates stage and status together")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
