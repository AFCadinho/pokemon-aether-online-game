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
	await _check_trade_context_action()
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

func _check_trade_context_action() -> void:
	var host := Control.new()
	host.size = Vector2(1152, 648)
	root.add_child(host)
	coordinator.setup(host)
	coordinator.trade_capabilities = {"enabled": true}
	coordinator.trade_capabilities_loaded = true
	coordinator.open_context_for_player(
		{"userId": 7, "username": "misty", "displayName": "Misty"},
		Vector2(400, 200)
	)
	await process_frame
	await process_frame
	await process_frame
	_check_equal(
		is_equal_approx(
			coordinator.context_menu.size.y,
			coordinator.context_menu.get_combined_minimum_size().y
		),
		true,
		"collapsed trainer context card fits its rendered content on first open"
	)

	var trade_button := _find_player_action("Trade")
	_check_equal(trade_button != null, true, "enabled trade capability renders a Trade action")
	if trade_button != null:
		var viewport_rect := get_root().get_visible_rect()
		_check_equal(viewport_rect.encloses(trade_button.get_global_rect()), true, "Trade action remains inside the viewport")

	coordinator.trade_capabilities.clear()
	coordinator.trade_capabilities_loaded = false
	coordinator.trade_capabilities_loading = true
	coordinator.trade_capabilities_error = ""
	coordinator._render_context_menu()
	await process_frame
	trade_button = _find_player_action("Trade")
	_check_equal(trade_button != null and trade_button.disabled, true, "loading capabilities keeps a disabled Trade action visible")

	coordinator.trade_capabilities_loading = false
	coordinator.trade_capabilities_error = "temporary failure"
	coordinator._render_context_menu()
	await process_frame
	trade_button = _find_player_action("Trade")
	_check_equal(trade_button != null and not trade_button.disabled, true, "failed capability check leaves Trade available for retry")

	coordinator.trade_capabilities_loaded = true
	coordinator.trade_capabilities_error = ""
	coordinator.trade_capabilities = {"enabled": false}
	coordinator._render_context_menu()
	await process_frame
	trade_button = _find_player_action("Trade")
	_check_equal(trade_button != null and trade_button.disabled, true, "authoritatively disabled trading remains visible but cannot start")

	await _check_guild_invite_context_action()
	_check_chat_moderation_context_action()
	await _check_live_localization()
	coordinator.close_context_menu()
	host.queue_free()

func _check_live_localization() -> void:
	var manager := root.get_node_or_null("LocalizationManager")
	if manager == null:
		_check_equal(false, true, "localization manager is available")
		return
	manager.set_locale("nl")
	await process_frame
	var nearby_title := _find_label_with_text(coordinator.players_panel, "Trainers in de buurt")
	_check_equal(nearby_title != null, true, "Nearby title refreshes in Dutch")
	coordinator.trade_capabilities = {"enabled": true}
	coordinator.trade_capabilities_loaded = true
	coordinator.current_target = {"userId": 7, "username": "misty", "displayName": "Misty"}
	coordinator.context_more_actions_expanded = false
	coordinator._render_context_menu()
	var trade_button := _find_player_action("Trade")
	_check_equal(
		trade_button != null and _find_label_with_text(trade_button, "Ruilen") != null,
		true,
		"Nearby actions display Dutch without changing their canonical action id"
	)
	manager.set_locale("en")
	await process_frame

func _find_label_with_text(node: Node, expected: String) -> Label:
	if node is Label and (node as Label).text == expected:
		return node as Label
	for child: Node in node.get_children():
		var match := _find_label_with_text(child, expected)
		if match != null:
			return match
	return null

func _find_player_action(action_name: String) -> Button:
	for child: Node in coordinator.context_actions.get_children():
		if child is Button and str(child.get_meta("player_action", "")) == action_name:
			return child as Button
	return null

func _check_guild_invite_context_action() -> void:
	coordinator.guild_membership = {"guildId": 4, "role": "officer"}
	coordinator.guild_membership_loaded = true
	coordinator.guild_members.clear()
	coordinator.guild_members.append({"userId": 9, "username": "brock"})
	coordinator.guild_members_loaded = true
	coordinator.social_state_loading = false
	coordinator._render_context_menu()
	coordinator._toggle_context_more_actions()
	await process_frame
	_check_equal(
		_find_player_action("Invite to Guild") != null,
		true,
		"guild leaders and officers receive the right-click guild invite action"
	)
	coordinator.guild_members.clear()
	coordinator.guild_members.append({"userId": 7, "username": "misty"})
	coordinator._render_context_menu()
	await process_frame
	_check_equal(
		_find_player_action("Invite to Guild") == null,
		true,
		"Trainers who already belong to the current Guild cannot be invited again"
	)
	coordinator.guild_members.clear()
	coordinator.guild_members_loaded = false
	coordinator._render_context_menu()
	await process_frame
	_check_equal(
		_find_player_action("Invite to Guild") == null,
		true,
		"Guild invitations stay hidden until the current roster is known"
	)
	coordinator.guild_membership = {"guildId": 4, "role": "member"}
	coordinator._render_context_menu()
	await process_frame
	_check_equal(
		_find_player_action("Invite to Guild") == null,
		true,
		"regular guild members do not receive the invite action"
	)


func _check_chat_moderation_context_action() -> void:
	auth_service.current_user = {
		"id": 1,
		"username": "ash",
		"roles": [{"id": "owner"}],
		"permissions": [],
	}
	coordinator.current_target = {"userId": 7, "username": "misty", "displayName": "Misty"}
	coordinator.context_more_actions_expanded = true
	coordinator.social_state_loading = true
	coordinator.chat_moderation_state_loading = true
	coordinator.chat_target_is_muted = false
	coordinator._render_context_menu()
	var requested_actions: Array[String] = []
	var requested_players: Array[Dictionary] = []
	coordinator.chat_moderation_requested.connect(
		func(action: String, player: Dictionary) -> void:
			requested_actions.append(action)
			requested_players.append(player)
	)
	var mute_button := _find_player_action("Mute Player")
	_check_equal(
		mute_button != null and not mute_button.disabled,
		true,
		"Owner can use direct-player mute while unrelated social state is loading"
	)
	if mute_button != null:
		mute_button.pressed.emit()
	_check_equal(requested_actions, ["mute"], "direct-player mute emits the moderation request")
	_check_equal(
		int(requested_players[0].get("userId", 0)) if not requested_players.is_empty() else 0,
		7,
		"direct-player mute keeps the selected target"
	)
	coordinator.current_target = {"userId": 7, "username": "misty", "displayName": "Misty"}
	coordinator.context_more_actions_expanded = true
	coordinator.social_state_loading = false
	coordinator.chat_target_is_muted = true
	coordinator._render_context_menu()
	_check_equal(
		_find_player_action("Unmute Player") != null,
		true,
		"Muted players expose the direct-player unmute action"
	)

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
	_check_equal(source.contains("GuildInvitationDialog"), true, "dedicated guild invitation dialog")
	_check_equal(source.contains("load_invitations"), true, "incoming guild invitations are polled independently")
	_check_equal(source.contains("WorldPresenceService"), true, "canonical roster dependency")
	_check_equal(source.contains("_social_action(\"load_socials\")"), true, "authoritative social refresh")
	_check_equal(source.contains("service.invite_member(username)"), true, "guild action uses the authoritative invitation endpoint")
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
