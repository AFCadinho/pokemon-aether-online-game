extends SceneTree

const POKE_BALL := preload("res://assets/items/icons/POKEBALL.png")
const GREAT_BALL := preload("res://assets/items/icons/GREATBALL.png")

var failed := false


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	var remote_player_avatar_script := load("res://scripts/world/remote_player_avatar.gd") as Script
	_check(remote_player_avatar_script != null, "remote player avatar script loads")
	if remote_player_avatar_script == null:
		quit(1)
		return
	var avatar: Node2D = remote_player_avatar_script.new() as Node2D
	root.add_child(avatar)
	avatar.apply_state(_player_state("wild", "wild-1"))
	await process_frame
	var indicator := avatar.nearby_battle_indicator as Node2D
	_check(indicator != null and indicator.visible, "wild battle creates a clickable indicator")
	_check(indicator.sprite.texture == POKE_BALL, "wild battle uses a Poke Ball")
	var card_top: float = avatar.nameplate.position.y + avatar.nameplate_background.offset_top
	_check(
		is_equal_approx(indicator.anchor_position.y, card_top - 14.0),
		"battle indicator sits directly above a nameplate without a role badge"
	)

	var badge_state := _player_state("wild", "wild-1")
	badge_state["roles"] = [{
		"id": "developer", "displayName": "Developer", "color": "#00d8b4",
		"priority": 100, "display": {},
	}]
	badge_state["selectedRoleBadge"] = "developer"
	avatar.apply_state(badge_state)
	await process_frame
	indicator = avatar.nearby_battle_indicator as Node2D
	var badge_center: float = avatar.nameplate.position.y + (
		(avatar.role_badge_icon.offset_top + avatar.role_badge_icon.offset_bottom) * 0.5
	)
	_check(
		avatar.role_badge_icon.visible
		and is_equal_approx(indicator.anchor_position.y, badge_center),
		"battle indicator overlaps the visible role badge instead of floating above it"
	)

	avatar.apply_state(_player_state("trainer", "trainer-1"))
	await process_frame
	indicator = avatar.nearby_battle_indicator as Node2D
	_check(indicator != null and indicator.sprite.texture == GREAT_BALL, "NPC battle uses a Great Ball")

	avatar.apply_state(_player_state("pvp", "room-1"))
	await process_frame
	_check(avatar.nearby_battle_indicator == null, "PvP presence cannot create a nearby PvE indicator")

	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var realtime_source := FileAccess.get_file_as_string("res://scripts/services/pvp_battle_realtime_service.gd")
	_check(
		world_source.contains('"battleSpectate": _get_current_battle_spectate_presence()')
		and world_source.contains('active_battle_kind not in ["wild", "trainer"]'),
		"world presence only advertises active wild and NPC battles"
	)
	_check(realtime_source.contains('else "/ws/pve-live"'), "nearby spectators use the read-only PvE stream")
	avatar.queue_free()
	quit(1 if failed else 0)


func _player_state(kind: String, battle_id: String) -> Dictionary:
	return {
		"userId": 7, "username": "Admin", "displayName": "Admin",
		"mapId": "route_25", "position": {"x": 64.0, "y": 64.0},
		"facingDirection": "down", "appearance": {"body": "Red"},
		"activityState": "battle", "battleSpectate": {"kind": kind, "battleId": battle_id},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return
	failed = true
	push_error("FAIL: %s" % label)
