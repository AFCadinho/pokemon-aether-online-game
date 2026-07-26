extends SceneTree

const GUILD_POPUP_SCENE_PATH := "res://scenes/interface/guild_popup.tscn"
const GUILD_POPUP_SCRIPT_PATH := "res://scripts/ui/guild_popup.gd"
const OVERLAY_SCRIPT_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var popup_scene_source := FileAccess.get_file_as_string(GUILD_POPUP_SCENE_PATH)
	var popup_source := FileAccess.get_file_as_string(GUILD_POPUP_SCRIPT_PATH)
	var overlay_source := FileAccess.get_file_as_string(OVERLAY_SCRIPT_PATH)

	_check_contains(popup_scene_source, "guild_popup.gd", "guild popup scene loads its controller")
	_check_contains(popup_source, 'heading.add_child(_label("Guilds"', "guildless interface has a clear title")
	_check_contains(popup_source, "Browse Guilds", "guildless interface exposes guild discovery")
	_check_contains(popup_source, '"Create a Guild"', "guildless interface exposes guild creation")
	_check_contains(popup_source, "func _render_guild_list", "guild directory renders a compact guild list")
	_check_contains(popup_source, "func _render_selected_guild", "selected guild has a public information panel")
	_check_contains(popup_source, "Guild Forum", "guild profile reserves the official forum action")
	_check_contains(popup_source, "An emblem is optional", "creation flow makes the emblem optional")
	_check_contains(popup_source, "CREATION_COST := 100000", "creation flow shows the Pokédollar gate")
	_check_contains(popup_source, "REQUIRED_BADGES := 3", "creation flow shows the badge gate")
	_check_contains(popup_source, "_player_badge_count() < REQUIRED_BADGES", "creation flow evaluates server badge progress")
	_check_contains(popup_source, "no Pokédollars were deducted", "interface-only creation cannot mutate the wallet")
	_check_contains(overlay_source, "GUILD_POPUP_SCENE", "main overlay loads the guild popup")
	_check_contains(overlay_source, "_open_guild_popup()", "existing guild button opens the new interface")

	quit(1 if failed else 0)


func _check_contains(source: String, expected: String, label: String) -> void:
	if source.contains(expected):
		print("PASS %s" % label)
		return
	failed = true
	push_error(label)
