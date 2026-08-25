extends SceneTree

const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const LOGIN_SCRIPT_PATH := "res://scripts/ui/login_screen.gd"
const ERROR_SERVICE_PATH := "res://scripts/services/backend_error_localization_service.gd"
const FORGOT_PASSWORD_URL := "https://pokeaether.com/forgot-password"

var failed := false


func _init() -> void:
	var login_scene := FileAccess.get_file_as_string(LOGIN_SCENE_PATH)
	var login_script := FileAccess.get_file_as_string(LOGIN_SCRIPT_PATH)
	var error_service := FileAccess.get_file_as_string(ERROR_SERVICE_PATH)

	_check(login_scene.contains('[node name="ForgotPasswordLinkButton"'), "login exposes password recovery")
	_check(login_scene.contains('text = "ui.login.forgot_password"'), "password recovery link is localized")
	_check(login_script.contains('const FORGOT_PASSWORD_URL := "%s"' % FORGOT_PASSWORD_URL), "login uses the canonical recovery URL")
	_check(login_script.contains("OS.shell_open(FORGOT_PASSWORD_URL)"), "password recovery opens the secure website flow")
	_check(error_service.contains('"email_not_verified": "ui.login.error.email_not_verified"'), "unverified login errors are safely localized")
	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
		"res://localization/zh_CN.json",
	]:
		var catalog := FileAccess.get_file_as_string(locale_path)
		_check(catalog.contains('"ui.login.forgot_password"'), "%s has password recovery copy" % locale_path)
		_check(catalog.contains('"ui.login.error.email_not_verified"'), "%s has verification guidance" % locale_path)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
