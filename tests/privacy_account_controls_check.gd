extends SceneTree

const AUTH_SERVICE_PATH := "res://scripts/services/auth_service.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"

var failed := false


func _init() -> void:
	var auth_service := FileAccess.get_file_as_string(AUTH_SERVICE_PATH)
	var settings_menu := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)

	_check(auth_service.contains('base_url + "/privacy/export"'), "auth service exposes the privacy export route")
	_check(auth_service.contains('base_url + "/privacy/delete"'), "auth service exposes the privacy deletion route")
	_check(auth_service.contains('"confirmation": "DELETE"'), "account deletion uses the server confirmation contract")
	_check(auth_service.contains("clear_session()"), "successful account deletion clears the player session")

	_check(settings_menu.contains('"ui.settings.privacy.export"'), "account settings expose a data export control")
	_check(settings_menu.contains('"ui.settings.privacy.delete"'), "account settings expose an account deletion control")
	_check(settings_menu.contains('"ui.settings.privacy.manage"'), "the account overview groups privacy actions behind one neutral control")
	_check(settings_menu.contains('privacy_export_button.visible = action == "menu"'), "privacy actions are only exposed inside the privacy workspace")
	_check(settings_menu.contains('privacy_delete_confirmation_input.text != "DELETE"'), "the destructive action requires explicit typed confirmation")
	_check(settings_menu.contains('user://exports/pokeaether-personal-data-'), "exports are written to the application data directory")
	_check(settings_menu.contains("OS.shell_show_in_file_manager(privacy_last_export_path)"), "successful exports can be revealed in the system file manager")
	_check(settings_menu.contains("AuthService.is_impersonating()"), "privacy controls reject staff impersonation sessions")

	for locale_path: String in [
		"res://localization/en.json",
		"res://localization/nl.json",
		"res://localization/pt_BR.json",
	]:
		var catalog := FileAccess.get_file_as_string(locale_path)
		_check(catalog.contains('"ui.settings.privacy.export"'), "%s has export copy" % locale_path)
		_check(catalog.contains('"ui.settings.privacy.delete"'), "%s has deletion copy" % locale_path)
		_check(catalog.contains('"ui.settings.privacy.manage"'), "%s has privacy management copy" % locale_path)
		_check(catalog.contains('"ui.settings.privacy.open_folder"'), "%s has open-folder copy" % locale_path)
		_check(catalog.contains('"ui.settings.privacy.error.confirmation"'), "%s has destructive confirmation guidance" % locale_path)

	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
