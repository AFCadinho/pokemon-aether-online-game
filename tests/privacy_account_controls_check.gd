extends SceneTree

const AUTH_SERVICE_PATH := "res://scripts/services/auth_service.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"

var failed := false


func _init() -> void:
	var auth_service := FileAccess.get_file_as_string(AUTH_SERVICE_PATH)
	var settings_menu := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)

	_check(auth_service.contains('base_url + "/privacy/export"'), "auth service exposes the privacy export route")
	_check(auth_service.contains('base_url + "/privacy/delete"'), "auth service exposes the privacy deletion route")
	_check(auth_service.contains("const PRIVACY_REQUEST_TIMEOUT_SECONDS := 60.0"), "privacy requests allow bounded large exports to finish")
	_check(auth_service.count("PRIVACY_REQUEST_TIMEOUT_SECONDS") >= 3, "both privacy actions use the extended timeout")
	_check(auth_service.contains('"confirmation": "DELETE"'), "account deletion uses the server confirmation contract")
	_check(auth_service.contains("clear_session()"), "successful account deletion clears the player session")

	_check(settings_menu.contains('"ui.settings.privacy.export"'), "account settings expose a data export control")
	_check(settings_menu.contains('"ui.settings.privacy.delete"'), "account settings expose an account deletion control")
	_check(settings_menu.contains('"ui.settings.privacy.manage"'), "the account overview groups privacy actions behind one neutral control")
	_check(settings_menu.contains('privacy_export_button.visible = action == "menu"'), "privacy actions are only exposed inside the privacy workspace")
	_check(settings_menu.contains('privacy_delete_confirmation_input.text != "DELETE"'), "the destructive action requires explicit typed confirmation")
	_check(settings_menu.contains('user://exports/pokeaether-personal-data-'), "exports are written to the application data directory")
	_check(settings_menu.contains("OS.shell_show_in_file_manager(privacy_last_export_path)"), "successful exports can be revealed in the system file manager")
	_check(settings_menu.contains("FileAccess.set_unix_permissions"), "desktop exports are restricted to the current OS user")
	_check(settings_menu.contains("FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER"), "exports do not grant group or public file access")
	_check(settings_menu.contains("AuthService.is_impersonating()"), "privacy controls reject staff impersonation sessions")
	_check_export_file_permissions()

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


func _check_export_file_permissions() -> void:
	var export_directory := ProjectSettings.globalize_path("user://exports")
	_check(DirAccess.make_dir_recursive_absolute(export_directory) == OK, "the export directory can be created")
	var path := ProjectSettings.globalize_path(
		"user://exports/privacy-permission-check-%s.json" % Time.get_ticks_usec()
	)
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "a privacy export can be written to the local data folder")
	if file != null:
		file.store_string("{}")
		file.close()
	if FileAccess.file_exists(path) and OS.get_name() in ["Linux", "macOS"]:
		var expected := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER
		_check(FileAccess.set_unix_permissions(path, expected) == OK, "owner-only permissions can be applied")
		_check(FileAccess.get_unix_permissions(path) == expected, "a written desktop export has owner-only 0600 permissions")
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
