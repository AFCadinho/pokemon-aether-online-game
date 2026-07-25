extends SceneTree

const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const PLAYER_PATH := "res://scripts/world/player.gd"
const REMOTE_PLAYER_PATH := "res://scripts/world/remote_player_avatar.gd"

var failures := 0


func _init() -> void:
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var remote_player_source := FileAccess.get_file_as_string(REMOTE_PLAYER_PATH)
	var primary_chat_source := _function_source(overlay_source, "_get_primary_visible_chat_role")
	var chat_visibility_source := _function_source(overlay_source, "_should_show_chat_role_badge")
	var expiry_source := _function_source(overlay_source, "_is_role_badge_current")
	var public_badge_source := _function_source(overlay_source, "_get_public_trainer_badge_text")
	var local_overworld_source := _function_source(player_source, "_should_show_overworld_role_badge")
	var remote_overworld_source := _function_source(
		remote_player_source,
		"_should_show_overworld_role_badge"
	)

	_check(
		primary_chat_source.contains('role.get("requiresSelection", false)'),
		"Blessed-style roles require an explicit Trainer Card selection"
	)
	_check(
		chat_visibility_source.contains("_is_role_badge_current(role)"),
		"chat badge visibility checks entitlement expiry"
	)
	_check(
		expiry_source.contains('role.get("expiresAt", "")')
		and expiry_source.contains("Time.get_unix_time_from_system()"),
		"role expiry uses the server-provided end time"
	)
	_check(
		public_badge_source.contains('display.get("profileBadge", true)')
		and public_badge_source.contains("_is_role_badge_current(role)"),
		"Blessed can stay hidden on public Trainer Cards and cannot survive expiry"
	)
	_check(
		local_overworld_source.contains("category != STAFF_ROLE_CATEGORY")
		and local_overworld_source.contains('display.get("overworldBadge", true)'),
		"non-staff Blessed roles stay hidden above the local character"
	)
	_check(
		remote_overworld_source.contains("category != STAFF_ROLE_CATEGORY")
		and remote_overworld_source.contains('display.get("overworldBadge", true)'),
		"non-staff Blessed roles stay hidden above remote characters"
	)
	_check(
		overlay_source.contains('"blessed":\n\t\t\treturn "Blessed"')
		and overlay_source.contains('"blessed":\n\t\t\treturn "#b980ff"'),
		"Blessed has a compact chat label and color fallback"
	)

	quit(1 if failures > 0 else 0)


func _function_source(source: String, function_name: String) -> String:
	var start := source.find("func %s(" % function_name)
	if start < 0:
		return ""
	var next_function := source.find("\nfunc ", start + 1)
	if next_function < 0:
		return source.substr(start)
	return source.substr(start, next_function - start)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failures += 1
	push_error("FAIL %s" % label)
