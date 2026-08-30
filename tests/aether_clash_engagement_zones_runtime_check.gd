extends SceneTree


const DUEL_SCENE := "res://scenes/overworld/aether_clash/aether_clash_duel.tscn"

var failed := false


class FakeRemoteActor extends Node2D:
	var user_id := 0
	var gameplay_nameplate_visibility_override_active := false
	var gameplay_nameplate_visible := true
	var gameplay_identity_mask_override_active := false
	var gameplay_identity_masked := false
	var displayed_name := "Opponent"
	var guild_emblem_visible := true
	var role_badge_visible := true

	func set_gameplay_nameplate_visible(visible: bool) -> void:
		gameplay_nameplate_visibility_override_active = true
		gameplay_nameplate_visible = visible

	func clear_gameplay_nameplate_visibility_override() -> void:
		gameplay_nameplate_visibility_override_active = false
		gameplay_nameplate_visible = true

	func set_gameplay_identity_masked(masked: bool, placeholder := "???") -> void:
		gameplay_identity_mask_override_active = true
		gameplay_identity_masked = masked
		displayed_name = str(placeholder) if masked else "Opponent"
		role_badge_visible = not masked

	func clear_gameplay_identity_mask_override() -> void:
		gameplay_identity_mask_override_active = false
		gameplay_identity_masked = false
		displayed_name = "Opponent"
		role_badge_visible = true


class FakeLocalActor extends Node2D:
	func teleport_within_current_map(world_position: Vector2, _facing := Vector2.ZERO) -> void:
		global_position = world_position


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(DUEL_SCENE) as PackedScene
	_check(packed != null, "Aether Clash engagement scene loads")
	if packed == null:
		quit(1)
		return
	var duel := packed.instantiate()
	root.add_child(duel)
	await process_frame
	duel.set("instance_session_id", "engagement-runtime-test")

	var zones = duel.get_node_or_null("ArenaZones")
	_check(zones != null, "Duel owns visible staging and exit zones")
	var arena_hud = duel.get_node_or_null("ArenaHud")
	_check(arena_hud != null and int(arena_hud.get("layer")) < 10, "Battle UI renders above the Guild Duel arena HUD")
	var blue_zone: Rect2 = zones.call("get_zone_rect", "blue")
	var red_zone: Rect2 = zones.call("get_zone_rect", "red")
	_check(blue_zone.get_center() == Vector2(1456, 176), "Blue staging zone follows its editable spawn marker")
	_check(red_zone.get_center() == Vector2(1072, 4816), "Red staging zone follows its editable spawn marker")

	var player_save := root.get_node("PlayerSave")
	var original_player_id := str(player_save.get("player_id"))
	player_save.set("player_id", "1")
	var local_actor := FakeLocalActor.new()
	local_actor.name = "FakeLocalClashPlayer"
	local_actor.global_position = Vector2(512, 512)
	local_actor.add_to_group("player")
	root.add_child(local_actor)
	var remote_actor := FakeRemoteActor.new()
	remote_actor.name = "FakeRemoteClashPlayer"
	remote_actor.user_id = 2
	remote_actor.global_position = Vector2(576, 512)
	remote_actor.add_to_group("remote_player_avatar")
	root.add_child(remote_actor)

	duel.call("_apply_arena_state", _payload("entry_open", "blue"))
	_check(
		remote_actor.gameplay_nameplate_visible
		and not remote_actor.gameplay_identity_masked
		and remote_actor.displayed_name == "Opponent",
		"Own Guild identities stay visible during staging"
	)
	arena_hud.call("set_battle_overlay_active", true)
	duel.call("_apply_arena_state", _payload("entry_open", "blue"))
	_check(not arena_hud.visible, "Arena HUD stays hidden while a local battle overlay is active")
	arena_hud.call("set_battle_overlay_active", false)
	_check(arena_hud.visible, "Arena HUD returns after the local battle overlay closes")
	_check(
		not bool(duel.call("is_world_actor_step_blocked", Vector2(512, 512), Vector2(544, 512))),
		"Players may overlap while the staging countdown is open"
	)

	duel.call("_apply_arena_state", _payload("active", "blue"))
	_check(
		bool(duel.call("is_world_actor_step_blocked", Vector2(512, 512), Vector2(544, 512))),
		"Friendly engagement circles block movement after the countdown"
	)
	_check(local_actor.get_node_or_null("AetherClashEngagementRing") != null, "Local active player receives an engagement circle")
	_check(remote_actor.get_node_or_null("AetherClashEngagementRing") != null, "Remote active player receives an engagement circle")

	var contact := {"count": 0, "method": ""}
	duel.engagement_contact_requested.connect(func(_source: int, _target: int, method: String) -> void:
		contact["count"] = int(contact["count"]) + 1
		contact["method"] = method
	)
	duel.call("_apply_arena_state", _payload("active", "red"))
	_check(
		remote_actor.gameplay_nameplate_visible
		and remote_actor.gameplay_identity_masked
		and remote_actor.displayed_name == "???",
		"An undiscovered enemy keeps a masked nameplate in the arena"
	)
	_check(
		remote_actor.guild_emblem_visible and not remote_actor.role_badge_visible,
		"A masked enemy keeps its Guild emblem without revealing role information"
	)
	_check(not bool(duel.call("can_view_overworld_identity", 2)), "Undiscovered enemies are hidden from other overworld identity surfaces")
	_check(
		bool(duel.call("is_world_actor_step_blocked", Vector2(512, 512), Vector2(544, 512))),
		"Enemy engagement circles stop the movement step"
	)
	_check(contact["count"] == 1 and contact["method"] == "player_contact", "Enemy circle contact emits the shared engagement request")
	_check(
		bool(duel.call("is_world_actor_step_blocked", Vector2(512, 512), Vector2(544, 512))),
		"Continued enemy-circle contact still blocks movement"
	)
	_check(contact["count"] == 1, "Continued contact does not repeat the engagement request")
	local_actor.global_position = Vector2(480, 512)
	duel.call("_release_separated_player_contact_pairs")
	local_actor.global_position = Vector2(512, 512)
	duel.call("is_world_actor_step_blocked", Vector2(512, 512), Vector2(544, 512))
	_check(contact["count"] == 2, "Separating from an opponent rearms contact engagement")
	duel.set("engaged_player_ids", {1: "engagement-1", 2: "engagement-1"})
	_check(
		bool(duel.call("is_world_actor_step_blocked", Vector2(512, 512), Vector2(544, 512))),
		"Reserved players continue to block movement"
	)
	_check(contact["count"] == 2, "Reserved players cannot emit a second contact challenge")
	duel.set("engaged_player_ids", {})
	var projectile_target := int(duel.call(
		"request_projectile_engagement",
		Vector2(512, 512),
		Vector2(608, 512),
		1
	))
	_check(projectile_target == 2, "Projectile paths target the same enemy engagement circle")
	_check(contact["count"] == 3 and contact["method"] == "projectile", "Projectile contact uses the shared engagement request")

	var discovered_payload := _payload("active", "red", [1, 2], [2])
	duel.call("_apply_arena_state", discovered_payload)
	_check(
		remote_actor.gameplay_nameplate_visible
		and not remote_actor.gameplay_identity_masked
		and remote_actor.displayed_name == "Opponent"
		and remote_actor.role_badge_visible,
		"A battled enemy identity becomes visible for the viewer's Guild"
	)
	_check(bool(duel.call("can_view_overworld_identity", 2)), "Discovered enemies regain overworld trainer interactions")
	var neutral_payload := discovered_payload.duplicate(true)
	neutral_payload["viewerRole"] = "spectator"
	neutral_payload["viewerSide"] = ""
	neutral_payload["identifiedEnemyUserIds"] = []
	neutral_payload["visibleIdentityUserIds"] = []
	duel.call("_apply_arena_state", neutral_payload)
	_check(
		remote_actor.gameplay_nameplate_visible
		and remote_actor.gameplay_identity_masked
		and remote_actor.displayed_name == "???"
		and remote_actor.guild_emblem_visible,
		"A public spectator sees Guild emblems but no undiscovered Trainer identity"
	)
	duel.call("_apply_arena_state", discovered_payload)

	_check(
		bool(duel.call(
			"is_world_actor_step_blocked",
			red_zone.position - Vector2(0, 32),
			red_zone.get_center()
		)),
		"The opposite-colored exit zone stops the movement step"
	)
	await process_frame
	_check(
		duel.get_node_or_null("ArenaHud/AetherClashLeaveConfirmation") == null,
		"Exit-zone borders wait for an intentional portal interaction"
	)
	var red_exit_portal := duel.get_node_or_null("Entities/Interactables/RedStagingExitPortal")
	duel.call("request_portal_exit", "guild_duel", local_actor, red_exit_portal)
	var red_exit_dialog := duel.get_node_or_null("ArenaHud/AetherClashLeaveConfirmation")
	_check(red_exit_dialog != null and red_exit_dialog.visible, "Either team may use the opposite staging portal")
	_check(red_exit_dialog != null and red_exit_dialog.get_parent() == duel.get_node("ArenaHud"), "Leave confirmation renders in the HUD canvas")
	if red_exit_dialog != null:
		red_exit_dialog.call("_cancel")
	await process_frame
	local_actor.global_position = blue_zone.get_center()
	duel.set("staging_ejection_deadline_msec", Time.get_ticks_msec() - 1)
	duel.call("_process_staging_ejection")
	_check(
		local_actor.global_position == Vector2(1456, 304),
		"A player still in staging after the grace period is moved onto the arena side"
	)
	_check(
		bool(duel.call(
			"is_world_actor_step_blocked",
			local_actor.global_position,
			blue_zone.get_center()
		)),
		"Entering the own active exit zone stops the movement step"
	)
	await process_frame
	_check(
		duel.get_node_or_null("ArenaHud/AetherClashLeaveConfirmation") == null,
		"Blocked staging re-entry does not open a leave dialog by itself"
	)
	var blue_exit_portal := duel.get_node_or_null("Entities/Interactables/BlueStagingExitPortal")
	duel.call("request_portal_exit", "guild_duel", local_actor, blue_exit_portal)
	var leave_dialog := duel.get_node_or_null("ArenaHud/AetherClashLeaveConfirmation")
	_check(leave_dialog != null and leave_dialog.visible, "Own staging portal opens the themed leave confirmation")
	if leave_dialog != null:
		leave_dialog.call("_cancel")
	await process_frame
	_check(not bool(root.get_node("GameState").call("is_overworld_input_locked")), "Canceling the exit dialog restores arena movement")

	var player_source := FileAccess.get_file_as_string("res://scripts/world/player.gd")
	_check(
		player_source.contains("_is_world_actor_step_blocked(global_position, movement_target_position)"),
		"Grid movement consults Aether Clash actor and exit-zone rules"
	)
	var duel_source := FileAccess.get_file_as_string("res://scripts/world/aether_clash_duel.gd")
	_check(
		duel_source.contains("GuildService.leave_aether_clash_arena(instance_session_id)"),
		"Arena portal confirmation uses the authoritative leave operation"
	)
	_check(
		duel_source.contains("func request_portal_exit(")
		and duel_source.contains('"ui.aether_clash.leave.staging_message"')
		and duel_source.contains('"ui.aether_clash.leave.spectator_message"'),
		"Staging players and spectators receive portal-specific leave confirmation"
	)
	_check(
		duel_source.contains("GuildService.create_aether_clash_engagement(")
		and duel_source.contains('"aether_clash.engagement.started"')
		and duel_source.contains('player_state.get("engagementMatchId")'),
		"Enemy contact, realtime delivery, and reconnect recovery share the authoritative engagement flow"
	)
	_check(
		duel_source.contains('"engagement_contact_emitted"')
		and duel_source.contains('"engagement_request_completed"')
		and duel_source.contains('"arena_state_failed"'),
		"Collision requests and arena-state failures emit structured Aether Clash traces"
	)
	_check(
		duel_source.contains("var engagement_battle_attempts: Dictionary")
		and duel_source.contains('"engagement_already_started_locally"'),
		"Arena refreshes cannot repeatedly start the same local engagement"
	)
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(
		overlay_source.contains("func start_aether_clash_pvp_match(")
		and overlay_source.contains("BattleApiClient.start_pvp_match_battle(")
		and overlay_source.contains('aether_clash_started_engagements[normalized_engagement_id] = "failed"')
		and not overlay_source.contains("aether_clash_started_engagements.erase(normalized_engagement_id)"),
		"Aether Clash engagements reuse PvP start once without an automatic failure loop"
	)
	_check(
		overlay_source.contains('"battle_start_response"')
		and overlay_source.contains('"authorized_teleport_received"'),
		"Battle-start responses and authoritative Aether Clash teleports are traced"
	)
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check(
		world_source.contains('"position_save_failed"')
		and world_source.contains('"remote_teleport_received"')
		and world_source.contains('"teleport_apply_finished"'),
		"Arena position-save failures and teleport application emit structured traces"
	)
	_check(
		world_source.contains('state.get("aetherClashResult", {})')
		and world_source.contains('"show_aether_clash_result"'),
		"Completed Clash teleports forward their authoritative result to the HUD"
	)
	var zone_source := FileAccess.get_file_as_string("res://scripts/world/aether_clash_arena_zones.gd")
	_check(
		zone_source.contains('for side: String in ["blue", "red"]')
		and zone_source.contains("BLUE_COLOR")
		and zone_source.contains("RED_COLOR"),
		"Staging and exit areas use explicit Blue Side and Red Side colors"
	)
	var ring_source := FileAccess.get_file_as_string("res://scripts/world/aether_clash_engagement_ring.gd")
	_check(
		ring_source.contains("const RADIUS := 28.0")
		and duel_source.contains("const ENGAGEMENT_RADIUS := 28.0"),
		"Visible and mechanical engagement circles share the larger radius"
	)

	player_save.set("player_id", original_player_id)
	duel.queue_free()
	await process_frame
	_check(
		local_actor.get_node_or_null("AetherClashEngagementRing") == null
		and remote_actor.get_node_or_null("AetherClashEngagementRing") == null,
		"Engagement circles are removed when the duel map closes"
	)
	_check(
		not remote_actor.gameplay_nameplate_visibility_override_active
		and remote_actor.gameplay_nameplate_visible
		and not remote_actor.gameplay_identity_mask_override_active
		and not remote_actor.gameplay_identity_masked
		and remote_actor.displayed_name == "Opponent",
		"Duel identity masking is cleared when the arena closes"
	)
	local_actor.queue_free()
	remote_actor.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _payload(
	status: String,
	remote_side: String,
	visible_ids_value: Variant = null,
	identified_ids: Array = []
) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	var visible_ids: Array = [1, 2] if remote_side == "blue" else [1]
	if visible_ids_value is Array:
		visible_ids = (visible_ids_value as Array).duplicate(true)
	return {
		"success": true,
		"serverNow": Time.get_datetime_string_from_unix_time(now, true) + "Z",
		"viewerRole": "participant",
		"viewerSide": "blue",
		"identifiedEnemyUserIds": identified_ids.duplicate(true),
		"visibleIdentityUserIds": visible_ids,
		"arenaPlayers": [
			{"userId": 1, "side": "blue"},
			{"userId": 2, "side": remote_side},
		],
		"session": {
			"id": "engagement-runtime-test",
			"status": status,
			"entryClosesAt": Time.get_datetime_string_from_unix_time(now + 90, true) + "Z",
			"challengerGuild": {"id": 1, "name": "North Stars"},
			"challengedGuild": {"id": 2, "name": "South Guard"},
			"entryCounts": {"challenger": 1, "challenged": 1},
			"participantCounts": {"challenger": 1, "challenged": 1},
			"activeCounts": {"challenger": 1, "challenged": 1},
		},
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
		return
	failed = true
	push_error("FAIL %s" % label)
