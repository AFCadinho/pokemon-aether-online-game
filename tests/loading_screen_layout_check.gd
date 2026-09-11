extends SceneTree

const LOADING_SCREEN_SCRIPT := "res://scripts/ui/loading_screen.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(LOADING_SCREEN_SCRIPT)
	_check(source.contains("AuthService.set_pending_login_notice(message)"), "loading failures remain visible after returning to login")
	_check(source.contains('"ui.loading.preparing"'), "loading screen uses a localized player-facing title")
	_check(source.contains('"ui.loading.secure_session"'), "loading screen localizes the authenticated transition")
	_check(source.contains("GradientTexture2D.FILL_RADIAL"), "loading screen uses the current aura treatment")
	_check(source.contains("func _create_loading_spinner()"), "loading screen builds a dedicated activity spinner")
	_check(source.contains('"rotation", TAU, 0.85'), "loading spinner rotates continuously without implying percentage progress")
	_check(
		source.contains("ResourceLoader.load_threaded_request(WORLD_SCENE_PATH")
		and source.contains("await get_tree().process_frame")
		and source.contains("change_scene_to_packed(world_scene)"),
		"world loads in the background so the spinner keeps animating"
	)
	_check(
		source.contains('"ui.loading.stage.trainer"')
		and source.contains('"ui.loading.stage.party"')
		and source.contains('"ui.loading.stage.world"'),
		"loading screen localizes its three preparation stages"
	)
	_check(source.contains("_set_loading_status"), "loading flow updates stage and status together")
	_check(source.contains("func _on_locale_changed"), "loading screen refreshes during a locale change")
	quit(1 if failed else 0)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s" % message)
