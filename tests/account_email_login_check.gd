extends SceneTree

const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const LOGIN_SCRIPT_PATH := "res://scripts/ui/login_screen.gd"
const ERROR_SERVICE_PATH := "res://scripts/services/backend_error_localization_service.gd"
const FORGOT_PASSWORD_URL := "https://pokeaether.com/forgot-password"

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
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

	_check_login_error_feedback()
	print("account_email_login_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _check_login_error_feedback() -> void:
	var localization := root.get_node("LocalizationManager")
	var original_locale: String = localization.current_locale
	var login: Control = load(LOGIN_SCRIPT_PATH).new()
	var expected_messages := {
		"en": "Username or password is incorrect. Check your details and try again.",
		"nl": "Gebruikersnaam of wachtwoord klopt niet. Controleer je gegevens en probeer opnieuw.",
		"pt_BR": "Nome de usuário ou senha incorretos. Confira seus dados e tente novamente.",
		"zh_CN": "用户名或密码不正确。请检查登录信息后重试。",
	}
	for locale: String in expected_messages:
		localization.set_locale(locale)
		for code: String in ["", "authentication_required", "unauthorized", "invalid_credentials"]:
			var response := {
				"success": false,
				"status": 401,
				"body": {"detail": {"code": code, "message": "invalid username or password"}},
			}
			_check(
				login.call("_get_login_error_message", response) == expected_messages[locale],
				"%s login rejection %s explains incorrect credentials" % [locale, code]
			)
		_check(
			login.call("_get_login_error_message", {"status": 401}) == expected_messages[locale],
			"%s bare login rejection explains incorrect credentials" % locale
		)
		var session_response := {"status": 401, "body": {"detail": {"code": "authentication_required"}}}
		_check(
			BackendErrorLocalizationService.message(session_response) == localization.text("backend.error.auth_required"),
			"%s expired sessions retain their separate sign-in guidance" % locale
		)
		_check(
			login.call("_get_login_error_message", {"status": 403, "body": {"detail": {"code": "email_not_verified"}}}) == localization.text("ui.login.error.email_not_verified"),
			"%s unverified email retains verification guidance" % locale
		)
		_check(
			login.call("_get_login_error_message", {"status": 503}) == localization.text("ui.login.error.unavailable"),
			"%s unavailable server does not report incorrect credentials" % locale
		)
		_check(
			login.call("_get_login_error_message", {"status": 403, "body": {"detail": {"code": "account_login_blocked", "message": "Please contact staff."}}}) == "Please contact staff.",
			"%s account restriction retains its public staff guidance" % locale
		)
	localization.set_locale(original_locale)
	login.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
