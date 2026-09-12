extends SceneTree

var failures := 0


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	_check(source.contains("dialog.cancel_button.pressed.connect"), "only Download client opens the client download page")
	_check(source.contains("dialog.canceled.connect(func():"), "the browser notice retains a close-only dismissal path")
	_check(source.contains('get_tree().call_deferred("change_scene_to_file", LOADING_SCENE_PATH)'), "browser confirmation queues the world hand-off on SceneTree after dialog input is complete")
	_check(not source.contains('continue_button.text = "Enter browser demo"'), "browser saved-session action no longer labels itself as a demo")
	_check(source.contains('return "ui.login.sign_in" if OS.has_feature("web") else "ui.login.continue"'), "browser saved-session action uses the normal Sign in label")
	var preview_function := _function(source, "_apply_saved_session_preview_state")
	_check(not preview_function.contains('OS.has_feature("web")'), "browser saved sessions hydrate the canonical outfit")
	_check(preview_function.contains("PlayerSave.apply_appearance_state(appearance)"), "login preview applies the saved outfit")
	var password_login := _function(source, "_submit_login")
	_check(password_login.find("await _apply_saved_session_preview_state()") < password_login.find("_show_web_demo_notice()"), "fresh browser login hydrates the outfit before its notice")
	print("web_login_demo_notice_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)


func _check(ok: bool, label: String) -> void:
	if ok:
		return
	failures += 1
	push_error(label)


func _function(source: String, name: String) -> String:
	var start := source.find("func " + name + "(")
	var end := source.find("\nfunc ", start + 1)
	return source.substr(start, end - start if end >= 0 else -1)
