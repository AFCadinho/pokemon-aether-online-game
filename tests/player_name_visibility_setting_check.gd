extends SceneTree

const PLAYER_PATH := "res://scripts/world/player.gd"
const WORLD_PATH := "res://scripts/world/world.gd"
const SETTINGS_MENU_PATH := "res://scripts/ui/settings_menu.gd"
const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var settings_source := FileAccess.get_file_as_string(SETTINGS_MENU_PATH)
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)

	_check(
		player_source.contains("visible and SettingsManager.display_own_name and nameplate_label.text"),
		"Local player nameplate always respects the saved own-name preference"
	)
	_check(
		world_source.contains("_sync_local_player_nameplate_visibility()")
		and world_source.contains('player.call("set_display_name", PlayerSave.player_name, SettingsManager.display_own_name)'),
		"World refreshes the actual local-player nameplate when settings change"
	)
	_check(
		settings_source.contains(
			'var world := GameState.get_world()\n'
			+ '\tif world != null:\n'
			+ '\t\tplayer_node = world.get_node_or_null("Player")\n'
			+ '\tif player_node == null:\n'
			+ '\t\tplayer_node = get_tree().get_first_node_in_group("player")'
		),
		"Settings prefers the world player over UI preview players"
	)
	_check(
		overlay_source.contains(
			'var world := GameState.get_world()\n'
			+ '\tif world != null:\n'
			+ '\t\tplayer_node = world.get_node_or_null("Player")\n'
			+ '\tif player_node == null:\n'
			+ '\t\tplayer_node = get_tree().get_first_node_in_group("player")'
		),
		"UI preference refresh prefers the world player over preview players"
	)

	if failures == 0:
		print("Player name visibility setting checks passed.")
	quit(failures)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failures += 1
	push_error("FAILED: %s" % label)
