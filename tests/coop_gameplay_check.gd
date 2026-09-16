extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := root.get_node("CoopService")
	service.set_process(false)
	service.reset()
	var gateway_config := root.get_node("GatewayApiConfig")
	var previous_gateway_url: String = gateway_config.get("cached_url")
	gateway_config.set("cached_url", "http://localhost:8000")
	var missing_profile_sources: Array[String] = []
	service.party_profile_missing.connect(func(source: String) -> void: missing_profile_sources.append(source))
	var incomplete_party := {"party": {"memberIds": [1, 2]}, "invitations": [], "activity": {}}
	service.apply_state(incomplete_party)
	service.apply_state(incomplete_party)
	_expect(missing_profile_sources == ["local development"], "missing member profiles identify the connected server once")
	var parsed_party: Dictionary = JSON.parse_string('{"party":{"leaderId":2,"memberIds":[2,7],"memberUsernames":{"2":"admin","7":"afc_adinho"},"memberAppearances":{"2":{"body":"Gen4_Base_v1"},"7":{"body":"Gen4_Base_F_v1"}}},"invitations":[],"activity":{}}')
	service.apply_state(parsed_party)
	_expect(typeof(service.party["memberIds"][0]) == TYPE_INT and service.party["memberIds"] == [2, 7], "JSON float member IDs normalize to integer IDs")
	_expect(missing_profile_sources.size() == 1, "canonical member keys find both names and portraits after JSON parsing")
	gateway_config.set("cached_url", previous_gateway_url)
	_expect(service.ORDINARY_TRAINERS.size() == 10, "ordinary trainer slice is explicitly bounded")
	for trainer: String in service.ORDINARY_TRAINERS:
		_expect(service.trainer_entity(trainer) == trainer, "ordinary trainer uses its own canonical entity")
	_expect(service.trainer_entity("kanto_route_3_youngster").is_empty(), "later trainers remain unsupported")
	var activity := {"reservationId": "fixture", "battleId": "coop-fixture", "status": "active"}
	service.apply_state({"party": {"leaderId": 1}, "invitations": [], "activity": activity,
		"view": {"battleId": "coop-fixture", "revision": 2, "decisionId": "coop-1", "locked": false,
			"legalActions": [{"type": "move", "slot": 1, "target": 1}]}})
	service.apply_view({"battleId": "coop-fixture", "revision": 1, "decisionId": "coop-1", "locked": true})
	_expect(service.view["revision"] == 2, "out-of-order snapshots do not roll back the client")
	service.pending_command = {"decisionId": "coop-1", "idempotencyKey": "retry"}
	service.apply_view({"battleId": "coop-fixture", "revision": 3, "decisionId": "coop-1", "locked": true})
	_expect(service.pending_command.is_empty(), "a locked own choice confirms an uncertain submission")
	service.pending_command = {"decisionId": "coop-1", "idempotencyKey": "attack", "action": {"type": "move", "slot": 1, "target": 1}}
	service.apply_view({"battleId": "coop-fixture", "revision": 4, "decisionId": "coop-1", "locked": false,
		"exitRequest": {"type": "run", "requestedBy": "p3"}, "legalActions": [{"type": "run"}, {"type": "reject-exit"}]})
	_expect(service.pending_command.is_empty() and service.view.exitRequest.type == "run", "reconnect replaces an ambiguous attack retry with the partner exit response")
	service.apply_view({"battleId": "coop-fixture", "revision": 5, "decisionId": "coop-2", "locked": false, "exitRequest": null})
	_expect(service.view.decisionId == "coop-2", "refusal reopens the same battle with a fresh decision ID")
	service.apply_view({"battleId": "coop-fixture", "revision": 6, "decisionId": "coop-2", "locked": false,
		"pendingCapture": {"decisionId": "coop-2", "idempotencyKey": "saved-throw", "itemId": "poke-ball"}})
	_expect(service.pending_command.get("idempotencyKey") == "saved-throw" and service.pending_command.action.type == "capture", "reconnect reuses a prepared throw request without receiving its hidden roll")
	service.apply_view({"battleId": "coop-fixture", "revision": 7, "decisionId": "coop-3", "locked": true,
		"lastCapture": {"caught": true, "shakeCount": 3}})
	_expect(service.pending_command.is_empty() and service.view.lastCapture.caught, "an accepted throw clears its retry and keeps the durable result")
	service.apply_view({"battleId": "someone-else", "revision": 99})
	_expect(service.view["revision"] == 7, "another battle cannot replace the current snapshot")
	service.apply_state({"activity": {"reservationId": "fixture", "battleId": "coop-fixture", "status": "finished"}})
	service.apply_state({"activity": activity})
	_expect(service.activity["status"] == "finished", "late active snapshots cannot reopen a completed battle")
	var first: String = service.new_id()
	var second: String = service.new_id()
	_expect(first.length() == 36 and first != second and first[14] == "4", "request keys are independent UUIDs")
	var controls = load("res://scripts/battle/coop_controls.gd").new()
	controls.battle_mode = true
	root.add_child(controls)
	_expect(controls.get_child_count() > 0, "functional battle controls mount")
	service.view = {"positions": [{"controller": "p1", "details": "Leader"}, {"controller": "p3", "details": "Partner"}]}
	_expect(controls._target_label(-1, "p3") == "Leader" and controls._target_label(-2, "p1") == "Partner", "target locations keep the same meaning for both players")
	var host := Control.new()
	host.visible = false
	root.add_child(host)
	var mounted_world = load("res://tests/fixtures/coop_world_fixture.gd").new()
	mounted_world.battle_ui_host = host
	mounted_world.coop_world_ready = true
	mounted_world._on_coop_state_changed()
	_expect(host.visible and mounted_world.active_battle_kind == "coop" and host.get_child_count() == 1, "co-op entry shows the normally hidden battle host")
	var mounted_battle: Control = host.get_child(0)
	_expect(bool(mounted_battle.get("coop_mode")) and mounted_battle.get("coop_presenter") != null,
		"co-op uses the ordinary battle scene with its own server-driven presenter")
	var presenter: Control = mounted_battle.get("coop_presenter")
	_expect(presenter.get("cards").size() == 4
		and presenter.get("embedded_hosts").get("stage") == mounted_battle.get_node("%BattleStage")
		and mounted_battle.get_node("%BattleBackground").visible
		and not mounted_battle.get_node("%PlayerSpriteBox").visible,
		"four co-op positions use the regular battle stage without overlapping single-battle sprites")
	mounted_world._on_coop_state_changed()
	_expect(host.get_child_count() == 1, "repeated snapshots do not mount duplicate battle scenes")
	mounted_world.free()
	host.queue_free()
	var story := root.get_node("StoryService")
	story.apply_story({"quests": [{"questId": "oaks_parcel", "status": "completed"}, {"questId": "reach_viridian_city", "status": "completed"}]})
	var gary = load("res://scripts/world/npcs/base_npc.gd").new()
	gary.npc_id = "kanto_route_22_gary_oak"
	gary.visibility_required_quest_id = "oaks_parcel"
	gary.visibility_hidden_quest_id = "reach_viridian_city"
	service.party = {"leaderId": 1}
	_expect(gary._is_story_visibility_active(), "progressed helpers can still interact with Gary while in a party")
	service.party = {}
	_expect(not gary._is_story_visibility_active(), "solo Gary visibility remains unchanged")
	story.reset_story()
	service.party = {"leaderId": 1}
	_expect(not gary._is_story_visibility_active(), "co-op visibility does not skip Gary's prerequisite")
	gary.free()
	service.reset()
	_expect(service.party.is_empty() and service.view.is_empty() and service.pending_command.is_empty(), "logout drops another account's view and retry keys")
	controls.queue_free()
	var party_popup: Control = load("res://scripts/ui/coop_party_popup.gd").new()
	root.add_child(party_popup)
	service.available = true
	service.activity = {}
	party_popup.call("open", "TrainerTwo")
	party_popup.call("_show_error", "coop_partner_too_far")
	_expect((party_popup.get("_status") as Label).text == str(root.get_node("LocalizationManager").call("text", "ui.coop.wild.partner_too_far")),
		"partner distance rejection is explained in the party popup")
	service.party = {"sharedLevelCap": 20}
	party_popup.call("_show_error", "coop_shared_level_cap_exceeded")
	_expect((party_popup.get("_status") as Label).text.contains("20"), "shared level-cap rejection names the actual cap")
	service.party = {}
	_expect(party_popup.visible and party_popup.get("_recipient").text == "TrainerTwo", "social and right-click entry reuse a prefilled username popup")
	var focused_recipient: LineEdit = party_popup.get("_recipient")
	focused_recipient.grab_focus()
	focused_recipient.text = "TrainerTwoMore"
	party_popup.call("_refresh")
	_expect(party_popup.get("_recipient") == focused_recipient and focused_recipient.has_focus() and focused_recipient.text == "TrainerTwoMore", "party polling keeps username input and focus while typing")
	var observed_invitations: Array[Dictionary] = []
	service.invitation_received.connect(func(invitation: Dictionary) -> void: observed_invitations.append(invitation))
	var incoming := {"invitationId": "invite-one", "senderId": 2, "senderUsername": "TrainerTwo", "sharedLevelCap": 20}
	service.apply_state({"party": {}, "invitations": [incoming], "activity": {}})
	service.apply_state({"party": {}, "invitations": [incoming], "activity": {}})
	_expect(observed_invitations.size() == 1, "incoming invitation notifies exactly once across polling")
	party_popup.call("open_invitation", incoming)
	_expect(party_popup.visible and party_popup.get("_focused_invitation_id") == "invite-one", "incoming invitation opens focused accept/decline popup")
	_expect(party_popup.get("_content").get_children().any(func(child: Node) -> bool: return child is Label and child.text == "Shared level cap: Lv. 20"), "invitation shows the server-provided shared story cap")
	var invitation_visual_path := OS.get_environment("COOP_INVITE_VISUAL_CAPTURE_PATH")
	if not invitation_visual_path.is_empty():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(invitation_visual_path) == OK, "invitation visual capture saved")
	service.apply_state({"party": {}, "invitations": [], "activity": {}})
	_expect(not party_popup.visible, "resolved invitation closes its focused popup")
	party_popup.call("open", "TrainerTwo")
	var visual_path := OS.get_environment("COOP_PARTY_VISUAL_CAPTURE_PATH")
	if not visual_path.is_empty():
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(visual_path) == OK, "styled party visual capture saved")
	party_popup.call("_on_header_input", _mouse_button(true))
	party_popup.call("_input", _mouse_motion(Vector2(24, 12)))
	_expect(party_popup.position != ((party_popup.get_viewport_rect().size - party_popup.size) / 2.0).max(Vector2.ZERO), "party popup drags within the viewport")
	party_popup.call("close")
	_expect(not party_popup.visible, "party popup closes without a fixed world button")
	party_popup.queue_free()
	_expect(load("res://scripts/ui/ui_overlay.gd") != null, "Socials overlay compiles with the party launcher")
	var overlay_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	_expect(overlay_source.contains("CoopService.request_failed.connect(_on_coop_request_failed)")
		and overlay_source.contains('key = "ui.coop.wild.partner_too_far"')
		and overlay_source.contains('key = "ui.coop.wild.level_cap_exceeded"')
		and overlay_source.contains("add_system_message(LocalizationManager.text(key,"),
		"co-op admission rejection reaches System chat")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var translations: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))
		_expect(translations is Dictionary and not str((translations as Dictionary).get("ui.coop.wild.partner_too_far", "")).is_empty()
			and not str((translations as Dictionary).get("ui.coop.wild.level_cap_exceeded", "")).is_empty(),
			"co-op admission notices have %s translations" % locale)
	var overlay_scene: PackedScene = load("res://scenes/interface/ui_overlay.tscn")
	var overlay_ui := overlay_scene.instantiate()
	_expect(overlay_ui.get_node_or_null("Control/SocialsMenu/MarginContainer/VBoxContainer/AdventurePartyButton") != null, "Socials menu contains an Adventure Party launcher")
	var party_hud: Button = load("res://scripts/ui/coop_party_hud.gd").new()
	party_hud.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	party_hud.offset_left = -304.0
	party_hud.offset_right = -64.0
	party_hud.offset_top = -314.0
	party_hud.offset_bottom = -210.0
	root.add_child(party_hud)
	overlay_ui.set("coop_party_hud", party_hud)
	var buffs_panel: PanelContainer = overlay_ui.get_node("Control/PersonalBuffsPanel")
	overlay_ui.set("personal_buffs_panel", buffs_panel)
	overlay_ui.call("_position_coop_party_hud")
	_expect(is_equal_approx(party_hud.offset_left, buffs_panel.offset_left) and is_equal_approx(party_hud.offset_right, buffs_panel.offset_right), "party HUD matches personal-buffs width")
	_expect(is_equal_approx(party_hud.offset_bottom, buffs_panel.offset_top - 8.0), "party HUD sits directly above personal buffs")
	buffs_panel.offset_top -= 60.0
	overlay_ui.call("_position_coop_party_hud")
	_expect(is_equal_approx(party_hud.offset_bottom, buffs_panel.offset_top - 8.0), "party HUD follows expanded buffs")
	service.available = true
	service.party = {"memberIds": [1.0, 2.0], "memberUsernames": {"1": "TrainerOne", "2": "TrainerTwo"},
		"memberAppearances": {"1": {"body": "Gen4_Base_v1", "gender": "male"}, "2": {"body": "Gen4_Base_F_v1", "gender": "female"}},
		"sharedLevelCap": 20}
	overlay_ui.call("_refresh_coop_party_hud")
	var hud_names: Array = party_hud.get("_names")
	var hud_portraits: Array = party_hud.get("_portraits")
	_expect(party_hud.visible and hud_names[0].text == "TrainerOne" and hud_names[1].text == "TrainerTwo", "party HUD shows both member names")
	_expect(hud_portraits[0].visible and hud_portraits[1].visible and not party_hud.text.contains("cap"), "party HUD shows both portraits without a level cap")
	var hud_visual_path := OS.get_environment("COOP_PARTY_HUD_VISUAL_CAPTURE_PATH")
	if not hud_visual_path.is_empty():
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(hud_visual_path) == OK, "party HUD visual capture saved")
	var auth_service := root.get_node("AuthService")
	var previous_user: Dictionary = (auth_service.get("current_user") as Dictionary).duplicate(true)
	auth_service.set("current_user", {"id": 1, "username": "SelfTrainer"})
	var active_party_popup: Control = load("res://scripts/ui/coop_party_popup.gd").new()
	root.add_child(active_party_popup)
	active_party_popup.call("open")
	var active_content: VBoxContainer = active_party_popup.get("_content")
	var party_labels: Array = active_content.find_children("*", "Label", true, false)
	_expect(active_content.get_child_count() == 5 and party_labels.any(func(label: Label) -> bool: return label.text == "TrainerOne")
		and party_labels.any(func(label: Label) -> bool: return label.text == "TrainerTwo")
		and party_labels.any(func(label: Label) -> bool: return label.text == "SHARED LEVEL CAP"), "active party popup separates both trainers and the shared cap")
	var active_visual_path := OS.get_environment("COOP_PARTY_ACTIVE_VISUAL_CAPTURE_PATH")
	if not active_visual_path.is_empty():
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(active_visual_path) == OK, "active party popup visual capture saved")
	active_party_popup.free()
	service.party = {"memberIds": [1, 2]}
	overlay_ui.call("_refresh_coop_party_hud")
	_expect(hud_names[0].text == "SelfTrainer" and hud_names[1].text == "Trainer #2", "older party responses still show own name and identify the partner")
	auth_service.set("current_user", previous_user)
	service.party = {}
	overlay_ui.call("_refresh_coop_party_hud")
	_expect(not party_hud.visible, "party HUD hides when the party is dissolved")
	party_hud.free()
	overlay_ui.free()
	var interaction_script: Script = load("res://scripts/ui/player_interaction_coordinator.gd")
	_expect(interaction_script != null and interaction_script.get_script_signal_list().any(func(entry: Dictionary) -> bool: return entry.get("name") == "coop_invitation_requested"), "nearby Trainer context offers party invitation routing")
	var world = load("res://scripts/world/world.gd")
	_expect(world != null and world.can_instantiate(), "world compiles with co-op entry and recovery hooks")
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var wild_step_source := world_source.get_slice("func start_triggered_wild_battle_for_area(", 1).get_slice("\nfunc ", 0)
	_expect(wild_step_source.contains("coop_wild_step_pending") and not wild_step_source.contains("GameState.lock_overworld_input()"),
		"co-op grass checks cannot freeze movement for network round trips")
	var service_source := FileAccess.get_file_as_string("res://scripts/services/coop_service.gd")
	var grass_request_source := service_source.get_slice("func try_wild_step(", 1).get_slice("\nfunc ", 0)
	_expect(not grass_request_source.get_slice('var world := GameState.get_world()', 1).get_slice('var result := await _request("grass-step"', 0).contains("await refresh()")
		and grass_request_source.contains('result.get("body", {}).get("status") != "miss"'),
		"grass misses avoid redundant status requests while starts still refresh")
	await process_frame
	quit(1 if failed else 0)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)


func _mouse_button(pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	return event


func _mouse_motion(delta: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	return event
