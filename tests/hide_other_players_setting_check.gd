extends SceneTree

const SETTINGS_MANAGER_PATH := "res://scripts/services/settings_manager.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"
const WORLD_PATH := "res://scripts/world/world.gd"
const REMOTE_AVATAR_PATH := "res://scripts/world/remote_player_avatar.gd"

var failures := 0


func _init() -> void:
	var manager_source := FileAccess.get_file_as_string(SETTINGS_MANAGER_PATH)
	var menu_source := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var avatar_source := FileAccess.get_file_as_string(REMOTE_AVATAR_PATH)

	_check(manager_source.contains("var hide_other_players := false"), "Other players remain visible by default")
	_check(manager_source.contains('"hide_other_players": hide_other_players'), "Visibility preference is persisted")
	_check(manager_source.contains('data.get("hide_other_players", hide_other_players)'), "Visibility preference is loaded")
	_check(manager_source.contains("func set_hide_other_players(enabled: bool)"), "Settings manager exposes the preference")
	_check(menu_source.contains("_create_hide_other_players_check_box()"), "General settings includes the visibility toggle")
	_check(menu_source.contains("SettingsManager.set_hide_other_players(enabled)"), "Settings toggle updates the preference")
	_check(world_source.contains("remote_players_container.visible = players_visible"), "World hides the remote-player container")
	_check(world_source.contains("SettingsManager.settings_changed.connect(_on_settings_changed)"), "World applies visibility changes immediately")
	_check(world_source.contains("avatar.call(\"set_interaction_enabled\", players_visible)"), "Hidden players cannot be interacted with")
	_check(avatar_source.contains("func set_interaction_enabled(enabled: bool)"), "Remote avatars expose interaction visibility")

	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog_value: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/%s.json" % locale)
		)
		_check(
			catalog_value is Dictionary and (catalog_value as Dictionary).has("ui.settings.hide_other_players"),
			"%s localizes the other-player visibility setting" % locale
		)

	if failures == 0:
		print("Hide other players setting checks passed.")
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % label)

