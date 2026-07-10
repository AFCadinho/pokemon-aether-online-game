extends SceneTree

const PlayerInteractionCoordinatorScript := preload("res://scripts/ui/player_interaction_coordinator.gd")
const WorldPresenceServiceScript := preload("res://scripts/services/world_presence_service.gd")

class FakeAuthService extends Node:
	var current_user: Dictionary = {}

var failed := false
var coordinator: Node
var auth_service: Node
var presence_service: Node

func _init() -> void:
	auth_service = FakeAuthService.new()
	auth_service.name = "AuthService"
	auth_service.current_user = {"id": 1, "username": "ash"}
	root.add_child(auth_service)
	presence_service = WorldPresenceServiceScript.new()
	presence_service.name = "WorldPresenceService"
	root.add_child(presence_service)
	coordinator = PlayerInteractionCoordinatorScript.new()
	root.add_child(coordinator)
	await process_frame
	_check_player_normalization()
	_check_self_exclusion_and_roster_ordering()
	_check_deterministic_player_ordering()
	_check_social_state_matching()
	_check_phase_scope_contract()
	_check_remote_avatar_interaction_contract()
	coordinator.queue_free()
	presence_service.queue_free()
	auth_service.queue_free()
	quit(1 if failed else 0)

func _check_player_normalization() -> void:
	var valid: Dictionary = coordinator._normalized_player({"userId": 7, "username": "misty"})
	_check_equal(valid.get("userId", 0), 7, "valid roster player")
	_check_equal(coordinator._normalized_player({"userId": 7}).is_empty(), true, "missing username rejected")
	_check_equal(coordinator._normalized_player({"username": "misty"}).is_empty(), true, "missing user id rejected")

func _check_deterministic_player_ordering() -> void:
	var players: Array[Dictionary] = [
		{"userId": 9, "username": "Brock", "displayName": "Brock"},
		{"userId": 4, "username": "ash", "displayName": "Ash"},
		{"userId": 2, "username": "ash2", "displayName": "Ash"},
	]
	players.sort_custom(coordinator._compare_players)
	_check_equal(players[0].get("userId", 0), 2, "same-name user id tie break")
	_check_equal(players[1].get("userId", 0), 4, "same-name deterministic order")
	_check_equal(players[2].get("userId", 0), 9, "alphabetical ordering")

func _check_self_exclusion_and_roster_ordering() -> void:
	presence_service._apply_snapshot_message({
		"rosterRevision": 1,
		"players": [
			{"userId": 1, "username": "ash"},
			{"userId": 9, "username": "brock", "displayName": "Brock"},
			{"userId": 2, "username": "misty", "displayName": "Misty"},
		],
	})
	var players: Array[Dictionary] = coordinator._current_map_players()
	_check_equal(players.size(), 2, "self excluded from roster")
	_check_equal(players[0].get("userId", 0), 9, "roster alphabetical first")
	_check_equal(players[1].get("userId", 0), 2, "roster alphabetical second")

func _check_social_state_matching() -> void:
	coordinator.social_overview = {
		"friends": [{"user": {"id": 8, "username": "misty"}}],
		"blockedUsers": [{"user": {"id": 9, "username": "brock"}}],
	}
	_check_equal(coordinator._is_friend({"userId": 8, "username": "MISTY"}), true, "friend lookup by id")
	_check_equal(coordinator._is_blocked({"userId": 9, "username": "BROCK"}), true, "block lookup by id")
	_check_equal(coordinator._is_friend({"userId": 10, "username": "gary"}), false, "non-friend lookup")

func _check_phase_scope_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/player_interaction_coordinator.gd")
	_check_equal(source.contains("trade_capabilities.get(\"enabled\""), true, "trade action is capability gated")
	_check_equal(source.contains("TradeInvitationDialog"), true, "dedicated invitation dialog")
	_check_equal(source.contains("WorldPresenceService"), true, "canonical roster dependency")
	_check_equal(source.contains("_social_action(\"load_socials\")"), true, "authoritative social refresh")
	_check_equal(source.contains("load_map_players"), false, "no secondary map-player projection")

func _check_remote_avatar_interaction_contract() -> void:
	var avatar_source := FileAccess.get_file_as_string("res://scripts/world/remote_player_avatar.gd")
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check_equal(avatar_source.contains("Area2D.new()"), true, "remote avatar hit area")
	_check_equal(avatar_source.contains("MOUSE_BUTTON_RIGHT"), true, "remote avatar right click")
	_check_equal(world_source.contains("_is_remote_interaction_candidate_above"), true, "overlap arbitration")
	_check_equal(world_source.contains("close_for_map_transition"), true, "map transition cleanup")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check_equal(overlay_source.contains("_ensure_player_interaction_coordinator()"), true, "avatar entry point initializes coordinator")

func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
