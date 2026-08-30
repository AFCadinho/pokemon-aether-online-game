extends SceneTree


const DUEL_SCENE := "res://scenes/overworld/aether_clash/aether_clash_duel.tscn"

var failed := false


class FakeLocalActor extends Node2D:
	var restored_zoom_count := 0

	func _init() -> void:
		var camera := Camera2D.new()
		camera.name = "Camera2D"
		camera.zoom = Vector2(1.5, 1.5)
		add_child(camera)

	func _apply_world_pixel_scale() -> void:
		restored_zoom_count += 1
		var camera := get_node("Camera2D") as Camera2D
		camera.zoom = Vector2(1.5, 1.5)


class FakeRemoteActor extends Node2D:
	var user_id := 0

	func set_gameplay_nameplate_visible(_visible: bool) -> void:
		pass

	func set_gameplay_identity_masked(_masked: bool, _placeholder := "???") -> void:
		pass

	func clear_gameplay_identity_mask_override() -> void:
		pass

	func clear_gameplay_nameplate_visibility_override() -> void:
		pass


class FakeOverlay extends Node:
	var requested_room_codes: Array[String] = []

	func start_aether_clash_pvp_spectate(room_code: String) -> bool:
		requested_room_codes.append(room_code)
		return true


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(DUEL_SCENE) as PackedScene
	_check(packed != null, "Guild Duel spectator scene loads")
	if packed == null:
		quit(1)
		return
	var duel := packed.instantiate()
	root.add_child(duel)
	await process_frame
	duel.set("instance_session_id", "spectator-runtime-test")

	var player_save := root.get_node("PlayerSave")
	var original_player_id := str(player_save.get("player_id"))
	player_save.set("player_id", "1")
	var local_actor := FakeLocalActor.new()
	local_actor.name = "FakeLocalSpectator"
	local_actor.global_position = Vector2(2224, 2416)
	local_actor.add_to_group("player")
	root.add_child(local_actor)
	var remote_blue := _remote_actor(2, Vector2(1200, 2200))
	var remote_red := _remote_actor(3, Vector2(1300, 2200))
	var remote_jail_spectator := _remote_actor(4, Vector2(2288, 2416))
	root.add_child(remote_blue)
	root.add_child(remote_red)
	root.add_child(remote_jail_spectator)
	var overlay := FakeOverlay.new()
	overlay.add_to_group("ui_overlay")
	root.add_child(overlay)

	var upper_orb := duel.get_node_or_null("Entities/Interactables/Guild1SpectatorOrb")
	var lower_orb := duel.get_node_or_null("Entities/Interactables/Guild2SpectatorOrb")
	_check(upper_orb != null and lower_orb != null, "Both editable jail areas contain a spectator orb")
	_check(
		upper_orb.global_position == Vector2(2144, 2416)
		and lower_orb.global_position == Vector2(2144, 2672),
		"Spectator orb positions remain editable scene coordinates"
	)

	duel.call("_apply_arena_state", _spectator_payload())
	var jail_engagement_requests := {"count": 0}
	duel.engagement_contact_requested.connect(func(_source: int, _target: int, _method: String) -> void:
		jail_engagement_requests["count"] = int(jail_engagement_requests["count"]) + 1
	)
	_check(
		not bool(duel.call(
			"is_world_actor_step_blocked",
			Vector2(2224, 2416),
			Vector2(2256, 2416)
		)),
		"Jail spectators can move through each other"
	)
	_check(
		not bool(duel.call(
			"is_world_actor_step_blocked",
			Vector2(2224, 2416),
			Vector2(2192, 2416)
		)),
		"An overlapping jail spectator can still move away"
	)
	_check(jail_engagement_requests["count"] == 0, "Overlapping jail spectators never start an engagement")
	var blue_indicator := remote_blue.get_node_or_null("AetherClashBattleIndicator")
	var red_indicator := remote_red.get_node_or_null("AetherClashBattleIndicator")
	_check(blue_indicator != null and red_indicator != null, "Every engaged player receives a rotating battle indicator")
	_check(
		blue_indicator != null
		and str(blue_indicator.get("room_code")) == "ACROOM123"
		and not bool(blue_indicator.get("clickable")),
		"Master Balls use the authoritative room and wait for Aether View before accepting clicks"
	)

	var orb_result: Dictionary = duel.call("request_spectator_orb", local_actor, upper_orb)
	_check(bool(orb_result.get("success", false)), "A jail spectator can activate the orb")
	var spectator_camera := duel.get_node("SpectatorCamera") as Camera2D
	var spectator_hud := duel.get_node("SpectatorCameraHud")
	var player_camera := local_actor.get_node("Camera2D") as Camera2D
	_check(spectator_camera.enabled and not player_camera.enabled, "The free camera takes over without moving the jailed player")
	_check(spectator_hud.visible, "Aether View shows its movement and return controls")
	_check(spectator_camera.zoom.is_equal_approx(Vector2(0.75, 0.75)), "Aether View starts with a wider arena overview")
	var zoom_slider := spectator_hud.get_node_or_null("Root/Panel/Margin/Content/Copy/ZoomRow/Slider") as HSlider
	var return_button := spectator_hud.get_node_or_null("Root/Panel/Margin/Content/ReturnButton") as Button
	var navigation_grid := spectator_hud.get_node_or_null("Root/Panel/Margin/Content/Navigation/Grid") as GridContainer
	_check(zoom_slider != null and is_equal_approx(float(zoom_slider.value), 0.75), "A styled zoom slider mirrors the spectator camera")
	_check(navigation_grid != null and navigation_grid.get_child_count() == 9, "Aether View offers all nine arena region shortcuts")
	_check(
		return_button != null
		and return_button.get_theme_stylebox("normal") != return_button.get_theme_stylebox("hover"),
		"Return to Jail has a distinct hover state"
	)
	_check(bool(root.get_node("GameState").call("is_overworld_input_locked")), "Aether View locks character movement")
	_check(
		int(spectator_camera.limit_left) == 0
		and int(spectator_camera.limit_top) == 0
		and int(spectator_camera.limit_right) == 2560
		and int(spectator_camera.limit_bottom) == 5120,
		"The free camera is constrained to the complete duel arena"
	)
	_check(
		duel.call("_clamp_spectator_camera_position", Vector2(-200, 9000)) == Vector2(0, 5120),
		"Free-camera movement cannot escape the arena bounds"
	)
	var north_west_button := navigation_grid.get_node_or_null("NorthWest") as Button
	north_west_button.emit_signal("pressed")
	_check(
		spectator_camera.global_position.is_equal_approx(Vector2(435.2, 870.4)),
		"Region buttons move the Aether viewport to the requested arena section"
	)
	zoom_slider.value = 1.1
	_check(
		spectator_camera.zoom.is_equal_approx(Vector2(1.1, 1.1))
		and is_equal_approx(float(zoom_slider.value), 1.1),
		"The zoom slider and camera stay synchronized"
	)
	var before_drag := spectator_camera.global_position
	var mouse_press := InputEventMouseButton.new()
	mouse_press.button_index = MOUSE_BUTTON_LEFT
	mouse_press.pressed = true
	duel.call("_unhandled_input", mouse_press)
	var mouse_drag := InputEventMouseMotion.new()
	mouse_drag.relative = Vector2(55, 30)
	duel.call("_unhandled_input", mouse_drag)
	_check(
		spectator_camera.global_position.is_equal_approx(
			before_drag - mouse_drag.relative / spectator_camera.zoom.x
		),
		"Holding the left mouse button and dragging pans the Aether viewport"
	)
	var before_touch_drag := spectator_camera.global_position
	var touch_drag := InputEventScreenDrag.new()
	touch_drag.relative = Vector2(-22, 11)
	duel.call("_unhandled_input", touch_drag)
	_check(
		spectator_camera.global_position.is_equal_approx(
			before_touch_drag - touch_drag.relative / spectator_camera.zoom.x
		),
		"Touch dragging uses the same mobile-friendly camera movement"
	)
	blue_indicator = remote_blue.get_node_or_null("AetherClashBattleIndicator")
	_check(blue_indicator != null and bool(blue_indicator.get("clickable")), "Master Balls become clickable for an active jail spectator")
	await duel.call("_on_battle_indicator_spectate_requested", 2, "ACROOM123")
	_check(overlay.requested_room_codes == ["ACROOM123"], "Clicking a Master Ball opens the existing PvP spectator flow")

	return_button.emit_signal("pressed")
	_check(not spectator_camera.enabled and player_camera.enabled, "Returning to jail restores the player camera")
	_check(not duel.get_node("SpectatorCameraHud").visible, "Returning to jail closes the Aether View controls")
	_check(not bool(root.get_node("GameState").call("is_overworld_input_locked")), "Returning to jail restores overworld input")

	duel.call("_apply_arena_state", _participant_payload())
	duel.call("_sync_local_camera_mode")
	var canvas_scale := player_camera.get_viewport().get_screen_transform().get_scale()
	var expected_participant_zoom := Vector2(
		2.0 / maxf(canvas_scale.x, 0.001),
		2.0 / maxf(canvas_scale.y, 0.001)
	)
	_check(
		player_camera.zoom.is_equal_approx(expected_participant_zoom),
		"Active Guild Duel participants are forced to a 2× output zoom"
	)
	duel.call("_apply_arena_state", _spectator_payload())
	duel.call("_sync_local_camera_mode")
	_check(
		local_actor.restored_zoom_count == 1
		and player_camera.zoom.is_equal_approx(Vector2(1.5, 1.5)),
		"Elimination restores the player's normal world zoom before spectating"
	)

	var indicator_source := FileAccess.get_file_as_string("res://scripts/world/aether_clash_battle_indicator.gd")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_check(
		indicator_source.contains("MASTERBALL.png")
		or FileAccess.file_exists("res://assets/items/icons/MASTERBALL.png"),
		"Battle indicators use the requested Master Ball asset"
	)
	_check(
		overlay_source.contains("func start_aether_clash_pvp_spectate(")
		and overlay_source.contains("BattleApiClient.spectate_pvp_room("),
		"Arena battle clicks reuse the existing authoritative PvP spectator endpoint"
	)

	duel.queue_free()
	await process_frame
	_check(
		remote_blue.get_node_or_null("AetherClashBattleIndicator") == null
		and remote_red.get_node_or_null("AetherClashBattleIndicator") == null,
		"Leaving the duel removes all Master Ball indicators"
	)
	_check(not bool(root.get_node("GameState").call("is_overworld_input_locked")), "Duel cleanup cannot leave spectator camera input locked")
	player_save.set("player_id", original_player_id)
	local_actor.queue_free()
	remote_blue.queue_free()
	remote_red.queue_free()
	remote_jail_spectator.queue_free()
	overlay.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _remote_actor(user_id: int, position: Vector2) -> FakeRemoteActor:
	var actor := FakeRemoteActor.new()
	actor.name = "FakeRemoteSpectatorTarget%d" % user_id
	actor.user_id = user_id
	actor.global_position = position
	actor.add_to_group("remote_player_avatar")
	return actor


func _spectator_payload() -> Dictionary:
	return _payload("spectator", "", [
		{
			"userId": 2,
			"side": "blue",
			"engagementId": "engagement-room-123",
			"engagementRoomCode": "ACROOM123",
		},
		{
			"userId": 3,
			"side": "red",
			"engagementId": "engagement-room-123",
			"engagementRoomCode": "ACROOM123",
		},
	])


func _participant_payload() -> Dictionary:
	return _payload("participant", "blue", [
		{"userId": 1, "side": "blue"},
		{"userId": 3, "side": "red"},
	])


func _payload(role: String, side: String, players: Array) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {
		"success": true,
		"serverNow": Time.get_datetime_string_from_unix_time(now, true) + "Z",
		"viewerRole": role,
		"viewerSide": side,
		"identifiedEnemyUserIds": [],
		"visibleIdentityUserIds": [],
		"arenaPlayers": players,
		"session": {
			"id": "spectator-runtime-test",
			"status": "active",
			"startedAt": Time.get_datetime_string_from_unix_time(now - 20, true) + "Z",
			"challengerGuild": {"id": 1, "name": "North Stars"},
			"challengedGuild": {"id": 2, "name": "South Guard"},
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
