extends SceneTree

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/login_screen.gd")
	_check(source.contains('remember_me_checkbox.button_pressed = AuthService.web_remember_me if OS.has_feature("web") else true'), "Restoration retains the browser preference and desktop behavior")
	var login: Control = load("res://scripts/ui/login_screen.gd").new()
	for field in ["status_label", "saved_status_label", "saved_display_name_label", "saved_username_label"]:
		var label := Label.new()
		login.add_child(label)
		login.set(field, label)
	for field in ["login_card", "saved_session_card"]:
		var card := PanelContainer.new()
		login.add_child(card)
		login.set(field, card)
	var button := Button.new()
	get_root().add_child(button)
	login.set("continue_button", button)
	var message := "Your current map is unavailable in the browser."
	login.set("login_return_notice", message)
	login.call("_apply_login_return_notice")
	_check_notice(login, message, "Initial return notice")
	login.call("_show_saved_session_card")
	_check_notice(login, message, "Welcome Back preserves the notice")
	login.call("_set_server_access_notice", "Server temporarily offline")
	_check_notice(login, message, "Background health updates preserve the notice")
	login.call("_clear_server_access_notice")
	_check_notice(login, message, "Server recovery preserves the notice")
	login.call("_clear_login_return_notice")
	_check(not login.get("status_label").visible and not login.get("saved_status_label").visible, "Retry/logout clears the notice")
	login.call("_set_server_access_notice", "Server temporarily offline")
	_check_notice(login, "Server temporarily offline", "Ordinary server notices still work")
	login.free()
	button.free()
	print("login_return_notice_check: %s" % ("PASS" if failures == 0 else "FAIL"))
	quit(failures)

func _check_notice(login: Control, message: String, label: String) -> void:
	for field in ["status_label", "saved_status_label"]:
		var status: Label = login.get(field)
		_check(status.visible and status.text == message, label + ": " + field)
	_check(login.get("status_is_error") and login.get("saved_status_is_error"), label + ": error styling")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
