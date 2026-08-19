extends SceneTree

const AUTH_SERVICE_PATH := "res://scripts/services/auth_service.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"

var failed := false


func _init() -> void:
	var auth_service := FileAccess.get_file_as_string(AUTH_SERVICE_PATH)
	var settings_menu := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)

	_check(auth_service.contains('base_url + "/auth/account-portal/launch"'), "the game requests portal access from the authenticated backend")
	_check(auth_service.contains("get_authorization_header()"), "portal launch uses the active game session")
	_check(auth_service.contains("func _is_safe_account_portal_url"), "portal addresses are validated before opening")
	_check(auth_service.contains('url.contains("/launch#ticket=")'), "the launch response must contain a fragment ticket")
	_check(auth_service.contains('url.begins_with("https://")'), "remote portal links require HTTPS")
	_check(auth_service.contains("is_impersonating()"), "staff impersonation cannot request player portal access")

	var account_builder := _function_body(settings_menu, "_build_account_tab", "_build_about_tab")
	_check(account_builder.contains('"ui.settings.account.portal"'), "account settings expose one browser portal control")
	_check(account_builder.contains('"ui.settings.account.portal_note"'), "account settings explain the secure browser handoff")
	_check(not account_builder.contains("_setup_account_details_dialog"), "the in-game profile and password dialog is no longer constructed")
	_check(not account_builder.contains("_setup_privacy_dialog"), "the in-game privacy dialog is no longer constructed")
	_check(not account_builder.contains('"ui.settings.privacy.manage"'), "privacy actions are no longer directly exposed in the game")
	_check(settings_menu.contains("OS.shell_open(launch_url)"), "the one-time portal address opens in the default browser")
	_check(not settings_menu.contains("print(launch_url)"), "the one-time portal address is not logged")
	_check(settings_menu.contains('"ui.settings.account.portal_error_impersonation"'), "the game explains why impersonation is blocked")

	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
	]:
		var catalog := FileAccess.get_file_as_string(locale_path)
		_check(catalog.contains('"ui.settings.account.portal"'), "%s has portal button copy" % locale_path)
		_check(catalog.contains('"ui.settings.account.portal_note"'), "%s has portal security guidance" % locale_path)
		_check(catalog.contains('"ui.settings.account.portal_error_open"'), "%s has browser failure guidance" % locale_path)

	quit(1 if failed else 0)


func _function_body(source: String, function_name: String, next_function_name: String) -> String:
	var start_marker := "func %s(" % function_name
	var end_marker := "func %s(" % next_function_name
	var start := source.find(start_marker)
	var end := source.find(end_marker, start + start_marker.length())
	if start < 0 or end < 0:
		return ""
	return source.substr(start, end - start)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
