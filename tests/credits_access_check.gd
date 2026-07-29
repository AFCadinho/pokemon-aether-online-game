extends SceneTree

const CREDITS_URL := "https://pokeaether.com/credits"
const EXTERNAL_LINKS_PATH := "res://scripts/core/external_links.gd"
const LOGIN_SCENE_PATH := "res://scenes/interface/login_screen.tscn"
const LOGIN_SCRIPT_PATH := "res://scripts/ui/login_screen.gd"
const SETTINGS_SCRIPT_PATH := "res://scripts/ui/settings_menu.gd"
const LAUNCHER_SCENE_PATH := "res://launcher/scenes/launcher.tscn"
const LAUNCHER_SCRIPT_PATH := "res://launcher/scripts/launcher.gd"
const LAUNCHER_CONFIG_PATH := "res://launcher/config/launcher_config.json"

var failed := false


func _init() -> void:
	var external_links := FileAccess.get_file_as_string(EXTERNAL_LINKS_PATH)
	var login_scene := FileAccess.get_file_as_string(LOGIN_SCENE_PATH)
	var login_script := FileAccess.get_file_as_string(LOGIN_SCRIPT_PATH)
	var settings_script := FileAccess.get_file_as_string(SETTINGS_SCRIPT_PATH)
	var launcher_scene := FileAccess.get_file_as_string(LAUNCHER_SCENE_PATH)
	var launcher_script := FileAccess.get_file_as_string(LAUNCHER_SCRIPT_PATH)
	var launcher_config := FileAccess.get_file_as_string(LAUNCHER_CONFIG_PATH)

	_check_contains(external_links, CREDITS_URL, "game client defines the canonical credits URL")
	_check_contains(login_scene, '[node name="CreditsButton"', "login screen exposes credits")
	_check_contains(login_script, "ExternalLinks.CREDITS_URL", "login screen uses the shared credits URL")
	_check_contains(login_script, "func _on_credits_button_pressed", "login credits action is connected")
	_check_contains(settings_script, '_create_tab_content("About", "ui.settings.tab.about")', "settings expose an About tab")
	_check_contains(settings_script, "ExternalLinks.CREDITS_URL", "settings use the shared credits URL")
	_check_contains(settings_script, '_set_localized_text(credits_button, "ui.settings.about.credits")', "About tab exposes localized credits")
	_check_contains(launcher_scene, '[node name="CreditsButton"', "launcher exposes credits")
	_check_contains(launcher_scene, 'text = "Credits"', "launcher uses a clear Credits label")
	_check_not_contains(launcher_scene, 'text = "Credits & Legal"', "launcher avoids unclear legal wording")
	_check_contains(launcher_script, "func open_credits", "launcher credits action is connected")
	_check_contains(launcher_script, "patch_notes_button, credits_button, uninstall_button", "launcher credits uses the pointing-hand cursor")
	_check_contains(
		launcher_script,
		'credits_button.tooltip_text = _t("View credits")',
		"launcher credits has a clear localized tooltip"
	)
	_check_contains(launcher_config, '"creditsUrl": "%s"' % CREDITS_URL, "launcher config uses the canonical credits URL")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		return
	failed = true
	push_error(label)


func _check_not_contains(source: String, unexpected: String, label: String) -> void:
	if not source.contains(unexpected):
		return
	failed = true
	push_error(label)
