extends SceneTree

const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"
const PLAYER_PATH := "res://scripts/world/player.gd"
const REMOTE_PLAYER_PATH := "res://scripts/world/remote_player_avatar.gd"
const WORLD_PATH := "res://scripts/world/world.gd"

var failures := 0


func _init() -> void:
	var overlay_source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	var player_source := FileAccess.get_file_as_string(PLAYER_PATH)
	var remote_player_source := FileAccess.get_file_as_string(REMOTE_PLAYER_PATH)
	var world_source := FileAccess.get_file_as_string(WORLD_PATH)
	var primary_chat_source := _function_source(overlay_source, "_get_primary_visible_chat_role")
	var chat_visibility_source := _function_source(overlay_source, "_is_selectable_chat_badge_role")
	var chat_badge_source := _function_source(overlay_source, "_get_chat_role_badge")
	var expiry_source := _function_source(overlay_source, "_is_role_badge_current")
	var public_badge_source := _function_source(overlay_source, "_get_public_trainer_badge_text")
	var local_primary_overworld_source := _function_source(player_source, "_get_primary_visible_role")
	var local_overworld_badge_source := _function_source(player_source, "_get_role_badge")
	var local_overworld_badge_width_source := _function_source(player_source, "_get_role_badge_width")
	var local_selected_overworld_source := _function_source(
		player_source,
		"_find_selected_overworld_role"
	)
	var local_overworld_source := _function_source(player_source, "_should_show_overworld_role_badge")
	var remote_primary_overworld_source := _function_source(
		remote_player_source,
		"_get_primary_visible_role"
	)
	var remote_overworld_badge_source := _function_source(
		remote_player_source,
		"_get_role_badge"
	)
	var remote_overworld_badge_width_source := _function_source(
		remote_player_source,
		"_get_role_badge_width"
	)
	var remote_selected_overworld_source := _function_source(
		remote_player_source,
		"_find_selected_overworld_role"
	)
	var remote_overworld_source := _function_source(
		remote_player_source,
		"_should_show_overworld_role_badge"
	)
	var role_presence_source := _function_source(world_source, "_get_current_role_presence_state")

	_check(
		primary_chat_source.contains('role.get("requiresSelection", false)'),
		"Blessed-style roles require an explicit Trainer Card selection"
	)
	_check(
		chat_visibility_source.contains("_is_role_badge_current(role)"),
		"chat badge selection checks entitlement expiry"
	)
	_check(
		expiry_source.contains('role.get("expiresAt", null)')
		and expiry_source.contains("expires_at_value == null")
		and expiry_source.contains("Time.get_unix_time_from_system()"),
		"permanent null-expiry roles stay current and timed roles use the server end time"
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
		player_source.contains('"gamemaster", "alpha"]')
		and remote_player_source.contains('"gamemaster", "alpha"]'),
		"legacy Alpha roles remain visible above local and remote characters"
	)
	_check(
		overlay_source.contains('"blessed":\n\t\t\treturn "Blessed"')
		and overlay_source.contains('"blessed":\n\t\t\treturn "#b980ff"'),
		"Blessed has a compact chat label and color fallback"
	)
	_check(
		overlay_source.contains('"developer":\n\t\t\treturn "DEV"')
		and overlay_source.contains("func _role_dictionary_from_value"),
		"Developer role payloads retain selectable DEV badges"
	)
	_check(
		overlay_source.contains("func _has_developer_chat_badge_entitlement")
		and overlay_source.contains("_has_user_permission(DEV_TOOLS_PERMISSION)"),
		"Developer permission exposes the optional DEV chat badge"
	)
	_check(
		overlay_source.contains("func _with_local_chat_role_state")
		and overlay_source.contains('resolved_user["roles"] = (current_roles as Array).duplicate(true)')
		and overlay_source.contains(
			'AuthService.current_user.get("selectedRoleBadge", GameState.selected_role_badge)'
		),
		"Local chat echoes use the same current roles and selected badge as the character"
	)
	_check(
		overlay_source.contains("func _get_selectable_chat_badge_roles")
		and overlay_source.contains("_is_selectable_chat_badge_role(role)"),
		"Trainer Card lists every selectable chat role without an overworld staff filter"
	)
	_check(
		chat_badge_source.contains('role.get("displayName"')
		and chat_badge_source.contains('role_id.replace("_", " ").capitalize()'),
		"every owned role has a usable chat badge label"
	)
	_check(
		local_primary_overworld_source.contains('selected_badge == "none"')
		and local_primary_overworld_source.contains("_find_selected_overworld_role")
		and local_selected_overworld_source.contains("_should_show_overworld_role_badge(role)"),
		"local character respects None and only renders the selected staff role"
	)
	_check(
		remote_primary_overworld_source.contains('normalized_selected_badge == "none"')
		and remote_primary_overworld_source.contains("_find_selected_overworld_role")
		and remote_selected_overworld_source.contains("_should_show_overworld_role_badge(role)"),
		"remote characters respect None and only render the selected staff role"
	)
	_check(
		local_overworld_badge_source.contains('role.get("displayName"')
		and remote_overworld_badge_source.contains('role.get("displayName"')
		and role_presence_source.contains('"displayName"')
		and local_overworld_badge_width_source.contains("normalized_badge.length()")
		and remote_overworld_badge_width_source.contains("normalized_badge.length()"),
		"all selected staff roles retain a nameplate label through world presence"
	)
	_check(
		local_overworld_badge_source.contains('"staff":\n\t\t\treturn "Chat Mod"')
		and remote_overworld_badge_source.contains('"staff":\n\t\t\treturn "Chat Mod"')
		and overlay_source.contains('"staff":\n\t\t\treturn "Chat Mod"'),
		"Chat Moderators use the shorter Chat Mod label above characters and in chat"
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
