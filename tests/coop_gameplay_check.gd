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
	var coop_service_source := FileAccess.get_file_as_string("res://scripts/services/coop_service.gd")
	_expect(not coop_service_source.contains("COOP_DIAG") and coop_service_source.contains("func _partner_is_ready_for_coop()"),
		"party grass encounters fall back to solo when the partner is unavailable without console diagnostics")
	_expect(coop_service_source.contains('var member_ids: Array = party.get("memberIds", []) if party.get("memberIds") is Array else []')
		and not coop_service_source.contains('party["memberIds"].size()'),
		"co-op polling handles the empty party response immediately after leaving a party")
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
	service.set("_poll_after", 10.0)
	service.apply_view({"battleId": "coop-fixture", "revision": 4, "decisionId": "coop-1", "locked": false,
		"exitRequest": {"type": "run", "requestedBy": "p3"}, "legalActions": [{"type": "run"}, {"type": "reject-exit"}]})
	_expect(service.pending_command.is_empty() and service.view.exitRequest.type == "run"
		and float(service.get("_poll_after")) == 0.0,
		"exit consent replaces an ambiguous attack retry and checks for the partner without normal poll delay")
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
	service.party = parsed_party.party
	var host := Control.new()
	host.visible = false
	root.add_child(host)
	var mounted_world = load("res://tests/fixtures/coop_world_fixture.gd").new()
	mounted_world.battle_ui_host = host
	mounted_world.coop_world_ready = true
	var coop_world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_expect(coop_world_source.contains("CoopService.activity.get(\"status\") == \"cancelled\"")
		and coop_world_source.contains("CoopService.activity.get(\"status\") == \"finished\"")
		and coop_world_source.contains("finish_coop_activity.call_deferred()"),
		"a cancelled shared start automatically releases the battle overlay")
	var saved_escape_tile := {"mapId": "kanto_route_1", "activityState": "idle", "position": {"x": 96.0, "y": 128.0}}
	_expect(mounted_world._can_resume_coop_wild_battle_in_place(saved_escape_tile, "kanto_route_1", Vector2(96.0, 128.0))
		and not mounted_world._can_resume_coop_wild_battle_in_place(saved_escape_tile, "kanto_route_2", Vector2(96.0, 128.0))
		and not mounted_world._can_resume_coop_wild_battle_in_place(saved_escape_tile, "kanto_route_1", Vector2(126.0, 128.0)),
		"settled wild battles resume in place only on the same saved tile")
	saved_escape_tile["activityState"] = "battle"
	_expect(not mounted_world._can_resume_coop_wild_battle_in_place(saved_escape_tile, "kanto_route_1", Vector2(96.0, 128.0)),
		"unsettled co-op battle never closes through the fast return path")
	var music_manager := root.get_node("MusicManager")
	var previous_music_path: String = music_manager.current_track_path
	var activity_before_music_check: Dictionary = service.activity.duplicate(true)
	service.activity = {"reservationId": "fixture", "battleId": "coop-fixture", "status": "active",
		"activityId": "kanto_route_1_youngster_liam"}
	mounted_world._on_coop_state_changed()
	_expect(host.visible and mounted_world.active_battle_kind == "coop" and host.get_child_count() == 1, "co-op entry shows the normally hidden battle host")
	_expect(music_manager.current_track_path == music_manager.get_music_track_path("battle.trainer.kalos"),
		"trainer co-op battle replaces map music with trainer battle music")
	service.activity["activityId"] = "wild_grass:kanto_route_1"
	mounted_world._on_coop_state_changed()
	_expect(music_manager.current_track_path == music_manager.get_music_track_path("battle.wild.kanto"),
		"wild co-op battle uses wild battle music when its activity becomes known")
	service.activity["activityId"] = "kanto_route_1_youngster_liam"
	if previous_music_path.is_empty():
		music_manager.stop_music()
	else:
		music_manager.play_music(previous_music_path)
	service.activity = activity_before_music_check
	var mounted_battle := mounted_world.get("battle_instance") as Control
	_expect(mounted_battle != null and mounted_battle.get("coop_mode") == true
		and mounted_battle.get("coop_presenter") != null,
		"co-op uses the ordinary battle scene with its own server-driven presenter")
	var presenter: Control = mounted_battle.get("coop_presenter")
	var original_activity: Dictionary = service.activity.duplicate(true)
	var original_view: Dictionary = service.view.duplicate(true)
	service.view = {}
	service.activity = {"status": "starting", "canCancel": true}
	presenter._update_loading_overlay()
	presenter._action_signature = ""
	presenter._update_actions()
	_expect(presenter._loading_overlay.visible and presenter._loading_cancel.visible,
		"wild co-op start shows a clear loading state and cancel control")
	_expect(not presenter._action_scroll.visible or presenter._actions.get_child_count() == 0,
		"native loading state has no duplicate action below the battle")
	var loading_capture_path := OS.get_environment("COOP_BATTLE_LOADING_CAPTURE_PATH")
	if not loading_capture_path.is_empty():
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(loading_capture_path) == OK,
			"co-op loading state capture saved")
	service.activity = {"status": "active"}
	presenter._update_loading_overlay()
	_expect(presenter._loading_overlay.visible, "loading state stays until the first battle snapshot")
	service.activity = original_activity
	service.view = original_view
	presenter._update_loading_overlay()
	presenter._action_signature = ""
	presenter._update_actions()
	_expect(not presenter._loading_overlay.visible, "battle interface replaces loading state when ready")
	var dock_content: Control = mounted_battle.get_node("%DockContent")
	var battle_log: Control = mounted_battle.get_node("%BattleLogPanel")
	service.activity.activityId = "wild_grass:kanto_route_1"
	service.view.participant = "p1"
	for event: Dictionary in [
		{"kind": "switch", "actor": "p2", "details": "Furret, L6, M"},
		{"kind": "switch", "actor": "p4", "details": "Furret, L6, F"},
		{"kind": "switch", "actor": "p1", "details": "Jigglypuff, L6, M"},
		{"kind": "switch", "actor": "p3", "details": "Squirtle, L5, M"},
	]:
		presenter._append_event(event)
	var native_opening: String = str(battle_log.get("log_buffer"))
	_expect(native_opening.count("A wild Furret has appeared!") == 2
		and native_opening.contains("Go! Jigglypuff!")
		and native_opening.contains("afc_adinho sent out Squirtle!")
		and not native_opening.contains("Wild Pokémon 1:"),
		"native co-op battle log uses battle narration for the opening Pokémon")
	battle_log.call("clear_log")
	service.activity = original_activity
	service.view = original_view
	var calc_button: Button = mounted_battle.get_node("%CalcLogButton")
	var party_grid: PartyGrid = mounted_battle.get_node("%PlayerPartyGrid")
	_expect(battle_log.visible and calc_button.visible
		and mounted_battle.get_node("%BattleLogButton").visible,
		"co-op keeps the single-battle log, calculator button and drawer shell")
	_expect(party_grid.columns == 3 and party_grid.get_parent().name == "ContextStack"
		and party_grid.size_flags_horizontal == Control.SIZE_SHRINK_BEGIN
		and presenter._decision_overlay.get_parent() == mounted_battle.get_node("%BattleStage")
		and presenter._action_scroll.get_parent() != dock_content,
		"co-op keeps the three-slot switch row in its dock and temporary choices on the stage")
	calc_button.pressed.emit()
	_expect(mounted_battle.get_node("%CalcDrawer").visible, "co-op Damage Calc opens the normal battle drawer")
	mounted_battle.get_node("%CalcDrawerCloseButton").pressed.emit()
	_expect(not mounted_battle.get_node("%CalcDrawer").visible, "co-op Damage Calc closes back to the battle")
	_expect(presenter.get("cards").size() == 4
		and presenter.get("embedded_hosts").get("stage") == mounted_battle.get_node("%BattleStage")
		and mounted_battle.get_node("%BattleBackground").visible
		and mounted_battle.get_node("%ActionsDock").visible
		and mounted_battle.get_node("%PlayerStagePartyRail").visible
		and mounted_battle.get_node("%BattleStatusPanel").visible
		and mounted_battle.get_node("%VSPanelContainer").visible
		and mounted_battle.get_node("%PlayerSpriteBox").visible
		and mounted_battle.get_node("%EnemySpriteBox").visible
		and mounted_battle.get_node("%PlayerSpriteBox").get_node("DoubleBattleContainer").visible
		and mounted_battle.get_node("%EnemySpriteBox").get_node("DoubleBattleContainer").visible,
		"co-op reuses the native battle stage and two-sprite containers on both sides")
	_expect(mounted_battle.get_node("%PlayerHudPanel/MarginContainer/VBoxContainer").columns == 2
		and mounted_battle.get_node("%EnemyHudPanel/MarginContainer/VBoxContainer").columns == 2
		and mounted_battle.get_node("%PlayerHudPanel").custom_minimum_size.x == 460.0,
		"double battles arrange two compact HP panels beside each other")
	await process_frame
	var player_side_rail: Control = mounted_battle.get_node("%PlayerStagePartyRail")
	var battle_prompt: Control = mounted_battle.get_node("%CurrentActionPanel")
	_expect(player_side_rail.get_global_rect().end.y < battle_prompt.get_global_rect().position.y
		and mounted_battle.get_node("%BattlePlatform").offset_top > -357.0
		and mounted_battle.get_node("%BattlePlatform2").offset_top > -496.0
		and mounted_battle.get_node("%PlayerSpriteBox").offset_top > -394.0
		and mounted_battle.get_node("%EnemySpriteBox").offset_top > -201.0,
		"co-op platforms and Pokémon sit lower while all side slots clear the battle prompt")
	var baseline_snapshot: Dictionary = {"participant": "p1", "turn": 4, "opponentPartySize": 2, "positions": [
		{"controller": "p1", "details": "Jigglypuff, L6, M", "hpPercent": 77, "boosts": {"def": -1}, "types": ["Normal"]},
		{"controller": "p3", "details": "Squirtle, L5, M", "hpPercent": 100},
		{"controller": "p2", "details": "Pidgey, L2, F", "hpPercent": 100},
		{"controller": "p4", "details": "Pidgey, L2, M", "hpPercent": 55, "boosts": {"atk": 1}, "types": ["Normal", "Flying"]}],
		"ownTeam": [{"species": "Jigglypuff", "active": true, "hp": 23, "maxHp": 30},
			{"species": "Ekans", "active": false, "hp": 29, "maxHp": 29}],
		"partnerTeam": [{"species": "Squirtle", "active": true, "hp": 20, "maxHp": 20}]}
	presenter._apply_positions(baseline_snapshot)
	var allied_rail: PartyGrid = mounted_battle.get_node("%PlayerStagePartyGrid")
	_expect(allied_rail.current_party_data.size() == 6
		and allied_rail.current_party_data[0].species == "Jigglypuff"
		and allied_rail.current_party_data[1].species == "Ekans"
		and allied_rail.get_pokemon_data_for_visual_slot(3).is_empty()
		and allied_rail.current_party_data[3].species == "Squirtle",
		"leader party occupies slots 1–3 and partner party starts at slot 4")
	var partner_view_snapshot: Dictionary = baseline_snapshot.duplicate(true)
	partner_view_snapshot.participant = "p3"
	partner_view_snapshot.ownTeam = baseline_snapshot.partnerTeam
	partner_view_snapshot.partnerTeam = baseline_snapshot.ownTeam
	presenter._apply_positions(partner_view_snapshot)
	_expect(allied_rail.current_party_data[0].species == "Jigglypuff"
		and allied_rail.current_party_data[3].species == "Squirtle"
		and mounted_battle.get_node("%PlayerPartyGrid").current_party_data[0].species == "Squirtle",
		"both Trainers see the same side-rail order but only their own switch roster")
	presenter._apply_positions(baseline_snapshot)
	_expect(mounted_battle.get_node("%PlayerSpriteBox/DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite").visible
		and mounted_battle.get_node("%PlayerSpriteBox/DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2").visible
		and mounted_battle.get_node("%EnemySpriteBox/DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite").visible
		and mounted_battle.get_node("%EnemySpriteBox/DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2").visible
		and mounted_battle.get_node("%PlayerHudPanel/MarginContainer/VBoxContainer/PokemonInfoHud2").visible,
		"four co-op Pokemon and the second HP row render in the native presentation")
	var status_snapshot: Dictionary = presenter._latest.duplicate(true)
	var status_positions: Dictionary = {"p1": "brn", "p3": "par", "p2": "psn", "p4": "slp"}
	var status_test_snapshot: Dictionary = {"participant": "p1", "turn": 4, "opponentPartySize": 2,
		"positions": [
			{"controller": "p1", "details": "Jigglypuff, L6, M", "hpPercent": 77, "status": "brn"},
			{"controller": "p3", "details": "Squirtle, L5, M", "hpPercent": 100, "status": "par"},
			{"controller": "p2", "details": "Pidgey, L2, F", "hpPercent": 100, "status": "psn"},
			{"controller": "p4", "details": "Pidgey, L2, M", "hpPercent": 55, "status": "slp"}],
		"ownTeam": [{"species": "Jigglypuff", "active": true, "hp": 23, "maxHp": 30}],
		"partnerTeam": [{"species": "Squirtle", "active": true, "hp": 20, "maxHp": 20}]}
	presenter._apply_positions(status_test_snapshot)
	for controller: String in status_positions:
		var overlay: StatusConditionOverlay = presenter._status_overlays[controller]
		_expect(overlay.condition_key == {"brn": "burned", "par": "paralysis", "psn": "poisoned", "slp": "sleeping"}[status_positions[controller]]
			and overlay.get_parent() == presenter._native_sprite(controller).get_parent(),
			"co-op status overlay follows the correct " + controller + " sprite")
	var burned_sprite: AnimatedSprite2D = presenter._native_sprite("p1")
	presenter._status_overlays["p1"]._process(0.1)
	_expect(burned_sprite.modulate != Color.WHITE, "burn visibly tints the affected co-op sprite")
	presenter._animate_event({"kind": "-curestatus", "actor": "p1"})
	_expect(presenter._status_overlays["p1"].condition_key.is_empty() and burned_sprite.modulate == Color.WHITE
		and presenter._status_overlays["p3"].condition_key == "paralysis",
		"curing one co-op Pokemon clears only its sprite effect")
	presenter._animate_event({"kind": "-status", "actor": "p1", "status": "tox"})
	_expect(presenter._status_overlays["p1"].condition_key == "badly_poisoned",
		"new statuses appear on the target sprite during event playback")
	presenter._apply_positions({"participant": "p1", "turn": 4, "opponentPartySize": 2,
		"positions": [], "ownTeam": [], "partnerTeam": []})
	_expect(presenter._status_overlays["p1"].condition_key.is_empty(), "empty positions remove stale co-op sprite effects")
	presenter._apply_positions(status_test_snapshot)
	presenter._latest = status_snapshot
	presenter._apply_positions(baseline_snapshot)
	var native_router: RefCounted = presenter._native_move_router
	var native_stage: Control = mounted_battle.get_node("%BattleStage")
	var all_native_anchors_match := true
	for actor: String in ["p1", "p3", "p2", "p4"]:
		for target: String in ["p1", "p3", "p2", "p4"]:
			var pair_sprites := {actor: presenter._native_sprite(actor), target: presenter._native_sprite(target)}
			var pair_boxes := {}
			for controller: String in [actor, target]:
				pair_boxes[controller] = mounted_battle.get_node("%PlayerSpriteBox") if controller in ["p1", "p3"] else mounted_battle.get_node("%EnemySpriteBox")
			var aliases: Dictionary = native_router.call("bind_native_pair", actor, target, pair_sprites, pair_boxes)
			if aliases.is_empty():
				all_native_anchors_match = false
				continue
			for endpoint: String in [actor, target]:
				var alias: String = aliases["actor"] if endpoint == actor else aliases["target"]
				var visual_rect: Rect2 = pair_boxes[endpoint].call("_get_sprite_visual_rect_global", pair_sprites[endpoint])
				var expected: Vector2 = native_stage.get_global_transform().affine_inverse() * visual_rect.get_center()
				var actual: Vector2 = native_router.call("_get_effect_target_anchor_in_parent", alias, native_stage, "center")
				all_native_anchors_match = all_native_anchors_match and actual.distance_to(expected) <= 1.0
	_expect(all_native_anchors_match, "all 16 doubles actor-target pairs use the two actual sprite centers")
	var motion_aliases: Dictionary = native_router.call("bind_native_pair", "p3", "p4",
		{"p3": presenter._native_sprite("p3"), "p4": presenter._native_sprite("p4")},
		{"p3": mounted_battle.get_node("%PlayerSpriteBox"), "p4": mounted_battle.get_node("%EnemySpriteBox")})
	var moving_sprite: AnimatedSprite2D = presenter._native_sprite("p3")
	var motion_origin := moving_sprite.position
	var untouched_sprite_origin: Vector2 = presenter._native_sprite("p1").position
	native_router.call("_play_move_actor_motion_if_needed", {"actor_motion": {"enabled": true, "duration": 0.4,
		"points": [{"at": 0.0, "offset": [18, 0], "duration": 0.2}]}}, motion_aliases["actor"])
	await process_frame
	await create_timer(0.05).timeout
	_expect(moving_sprite.position != motion_origin and presenter._native_sprite("p1").position == untouched_sprite_origin,
		"catalog actor motion moves only the selected doubles attacker")
	await create_timer(0.12).timeout
	_expect(moving_sprite.position == motion_origin, "individual doubles actor motion restores its original pose")
	var hidden_sprites: Array = native_router.call("_hide_move_actor_sprite_if_needed", {"hide_actor_sprite": true}, motion_aliases["actor"])
	_expect(not moving_sprite.visible and hidden_sprites.size() == 1,
		"catalog hide effects conceal only the selected doubles attacker")
	native_router.call("_restore_move_actor_sprite_if_needed", {"hide_actor_sprite": true}, motion_aliases["actor"], hidden_sprites)
	_expect(moving_sprite.visible, "catalog hide effects restore the selected doubles attacker")
	var animation_catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/battle_move_animations.json"))
	var all_catalog_moves_supported := true
	for move_name: String in (animation_catalog.get("moves", {}) as Dictionary):
		all_catalog_moves_supported = all_catalog_moves_supported and native_router.call("has_move_animation", move_name)
	_expect(all_catalog_moves_supported,
		"every catalog move is available to the doubles actor-target router")
	presenter._position_coop_stat_overlays()
	var player_stat_overlay: StatStagePanel = presenter._stat_overlays["p1"]
	var enemy_stat_overlay: StatStagePanel = presenter._stat_overlays["p4"]
	_expect(player_stat_overlay.visible and enemy_stat_overlay.visible
		and player_stat_overlay.get_parent() == mounted_battle.get_node("%BattleStage")
		and enemy_stat_overlay.get_parent() == mounted_battle.get_node("%BattleStage")
		and player_stat_overlay.get_global_rect().position.y >= mounted_battle.get_node("%PlayerHudPanel").get_global_rect().end.y,
		"stat badges sit outside and below the shared HP containers")
	_expect(mounted_battle.get_node("%BattleStatusPanel").turn_label.text.contains("4")
		and mounted_battle.get_node("%PlayerStagePartyGrid").current_party_data.size() == 6
		and mounted_battle.get_node("%PlayerPartyGrid").current_party_data.size() == 2
		and mounted_battle.get_node("%OpponentPartyGrid").current_party_data.size() == 2
		and not mounted_battle.get_node("%PlayerTrainerSprite").visible
		and not presenter.get("_second_trainer").visible
		and mounted_battle.get_node("%VSPanelContainer").player_1_label.text.contains("admin")
		and presenter._role("p1") == "admin" and presenter._role("p3") == "afc_adinho",
		"field rails combine both teams while the switch bar and log names stay player-specific")
	var wild_party_rail: PartyGrid = mounted_battle.get_node("%OpponentPartyGrid")
	_expect(wild_party_rail.current_party_data[0].get("active", false)
		and wild_party_rail.current_party_data[1].get("active", false)
		and ((wild_party_rail.get_child(0) as Button).get_theme_stylebox("normal") as StyleBoxFlat).border_color == Color("#62d7ff")
		and ((wild_party_rail.get_child(1) as Button).get_theme_stylebox("normal") as StyleBoxFlat).border_color == Color("#62d7ff"),
		"both present wild Pokémon glow as active in the opponent side rail")
	var left_ally: AnimatedSprite2D = mounted_battle.get_node("%PlayerSpriteBox/DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite")
	var right_ally: AnimatedSprite2D = mounted_battle.get_node("%PlayerSpriteBox/DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2")
	var left_wild: AnimatedSprite2D = mounted_battle.get_node("%EnemySpriteBox/DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite")
	var right_wild: AnimatedSprite2D = mounted_battle.get_node("%EnemySpriteBox/DoubleBattleContainer/SpriteSlot2/AnimatedPokemonSprite2")
	service.activity.activityId = "kanto_route_1_youngster_liam"
	presenter._sync_native_trainers()
	presenter._position_native_trainers()
	for _frame in 3:
		await process_frame
	var left_rail_rect: Rect2 = mounted_battle.get_node("%PlayerStagePartyGrid").get_global_rect()
	var right_rail_rect: Rect2 = mounted_battle.get_node("%OpponentPartyGrid").get_global_rect()
	_expect(absf(left_ally.global_position.y - right_ally.global_position.y) < 24.0
		and absf(left_wild.global_position.y - right_wild.global_position.y) < 24.0
		and absf(presenter._first_trainer.global_position.x - (left_rail_rect.end.x + 68.0)) < 2.0
		and absf(presenter._second_trainer.global_position.x - (left_rail_rect.end.x + 68.0)) < 2.0
		and absf(presenter._opponent_trainer.global_position.x - (right_rail_rect.position.x - 68.0)) < 2.0
		and presenter._first_trainer.global_position.y < presenter._second_trainer.global_position.y,
		"both Pokémon pairs stay aligned while command Trainers anchor beside their party rails")
	presenter._show_trainer_for_event({"kind": "move", "actor": "p1", "move": "Tackle"})
	_expect(presenter._first_trainer.visible and not presenter._second_trainer.visible
		and presenter._first_trainer.command_callout.visible,
		"only the acting allied Trainer appears with a move command")
	presenter._hide_native_trainers()
	service.activity.activityId = "brock"
	presenter._sync_native_trainers()
	presenter._show_trainer_for_event({"kind": "move", "actor": "p2", "move": "Gust"})
	_expect(presenter._opponent_trainer.visible and not presenter._first_trainer.visible
		and presenter._opponent_trainer.command_callout.visible,
		"the opposing Trainer appears only to command its Pokémon")
	presenter._hide_native_trainers()
	service.activity.activityId = "wild_grass:kanto_route_1"
	presenter._sync_native_trainers()
	var hover_view: Dictionary = presenter._latest.duplicate(true)
	presenter._latest = {"participant": "p1", "positions": [
		{"controller": "p1", "details": "Jigglypuff, L6, M", "hpPercent": 77, "types": ["Normal"]},
		{"controller": "p2", "details": "Pidgey, L2, F", "hpPercent": 100, "types": ["Normal", "Flying"],
			"possibleAbilities": ["Keen Eye", "Tangled Feet"],
			"speed": {"min": 5, "minNeutral31Iv": 6, "maxNeutral31Iv": 7, "max": 8}}],
		"ownTeam": [{"species": "Jigglypuff", "active": true, "hp": 23, "maxHp": 30}],
		"moves": [{"name": "Pound", "pp": 35, "maxPp": 35}]}
	presenter._show_coop_active_hover("p2")
	_expect(presenter._native_pokemon_hover.visible
		and presenter._native_pokemon_hover.name_label.text.contains("Pidgey")
		and presenter._native_pokemon_hover.type_icon_1.visible
		and presenter._native_pokemon_hover.ability_value_label.text.contains("Keen Eye")
		and presenter._native_pokemon_hover.speed_row.visible,
		"co-op sprite hover shows public types, possible abilities and speed tiers")
	var move_grid: MovesGrid = mounted_battle.get_node("%MovesGrid")
	move_grid.move_hovered.emit({"name": "Pound", "type": "Normal", "category": "Physical",
		"basePower": 40, "accuracy": 100}, Rect2(Vector2(100, 100), Vector2(40, 40)))
	_expect(presenter._native_move_hover.visible and presenter._native_move_hover.name_label.text.contains("Pound"),
		"co-op move hover signal opens the regular move detail card")
	move_grid.move_unhovered.emit()
	var allied_hover_grid: PartyGrid = mounted_battle.get_node("%PlayerStagePartyGrid")
	allied_hover_grid.pokemon_hovered.emit({"species": "Squirtle", "hp": 20, "maxHp": 20},
		Rect2(Vector2(100, 100), Vector2(40, 40)))
	_expect(presenter._native_pokemon_hover.visible and presenter._native_pokemon_hover.name_label.text.contains("Squirtle"),
		"co-op side rail hover signal opens the regular Pokémon card")
	allied_hover_grid.pokemon_unhovered.emit()
	presenter._hide_coop_pokemon_hover()
	battle_log.clear_log()
	presenter._append_event({"kind": "move", "actor": "p2", "move": "Tail Whip", "target": "p1"})
	presenter._append_event({"kind": "-unboost", "actor": "p1", "stat": "def", "amount": 1})
	_expect(battle_log.log_buffer.contains("Wild Pidgey (1) used Tail Whip!")
		and battle_log.log_buffer.contains("Defense fell for admin's Jigglypuff!")
		and not battle_log.log_buffer.contains("→") and not battle_log.log_buffer.contains("DEF ↓"),
		"co-op log describes moves and stat changes as readable battle narration")
	presenter._append_event({"kind": "-damage", "actor": "p2", "hpPercent": 75, "damagePercent": 25})
	_expect(battle_log.log_buffer.contains("Wild Pidgey (1) lost 25.0% of its health!"),
		"co-op log reports the damage dealt by each hit instead of only remaining HP")
	presenter._append_event({"kind": "-status", "actor": "p2", "status": "brn"})
	presenter._append_event({"kind": "-heal", "actor": "p1", "hpPercent": 80})
	presenter._append_event({"kind": "-miss", "actor": "p2"})
	presenter._append_event({"kind": "faint", "actor": "p2"})
	_expect(battle_log.log_buffer.contains("[color=%s]Wild Pidgey (1) used Tail Whip![/color]" % BattleLogPanel.COLOR_MOVE)
		and battle_log.log_buffer.contains("[color=%s]Defense fell for admin's Jigglypuff![/color]" % BattleLogPanel.COLOR_EFFECT)
		and battle_log.log_buffer.contains("[color=%s]Wild Pidgey (1) lost 25.0%% of its health![/color]" % BattleLogPanel.COLOR_DAMAGE)
		and battle_log.log_buffer.contains("[color=%s]Wild Pidgey (1) is burned![/color]" % BattleLogPanel.COLOR_STATUS)
		and battle_log.log_buffer.contains("[color=%s]admin's Jigglypuff recovered health![/color]" % BattleLogPanel.COLOR_HEAL)
		and battle_log.log_buffer.contains("[color=%s]Wild Pidgey (1)'s attack missed![/color]" % BattleLogPanel.COLOR_WARNING)
		and battle_log.log_buffer.contains("[color=%s]Wild Pidgey (1) fainted.[/color]" % BattleLogPanel.COLOR_FAINT),
		"co-op events use the same battle-log colors as singles")
	battle_log.clear_log()
	presenter._latest = hover_view
	_expect(not mounted_battle.get_node("%PlayerTrainerSprite").visible
		and not presenter._second_trainer.visible,
		"wild doubles hide both Trainer sprites")
	presenter._show_trainer_for_event({"kind": "move", "actor": "p3", "move": "Water Gun"})
	_expect(presenter._second_trainer.visible and not presenter._first_trainer.visible
		and not presenter._opponent_trainer.visible,
		"a wild battle reveals only the allied Trainer giving a command")
	presenter._hide_native_trainers()
	var wild_layout_capture := OS.get_environment("COOP_BATTLE_WILD_LAYOUT_CAPTURE_PATH")
	if not wild_layout_capture.is_empty():
		var decision_was_visible: bool = presenter._decision_overlay.visible
		presenter._decision_overlay.visible = false
		await process_frame
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(wild_layout_capture) == OK,
			"wild battle without Trainers capture saved")
		presenter._decision_overlay.visible = decision_was_visible
	service.activity.activityId = "brock"
	presenter._sync_native_trainers()
	_expect(not mounted_battle.get_node("%PlayerTrainerSprite").visible
		and not presenter._second_trainer.visible
		and presenter._opponent_trainer.has_trainer_art()
		and not presenter._opponent_trainer.visible,
		"NPC doubles keep Trainer art ready but hidden between commands")
	service.activity = {"status": "active"}
	presenter._process(0.0)
	_expect(not mounted_battle.get_node("%BattleStatusPanel").timer_label.visible
		and not mounted_battle.get_node("%BattleStatusPanel").turn_separator_label.visible,
		"co-op PvE keeps the turn label without a decision countdown")
	service.view = {"battleId": "coop-fixture", "revision": 8, "turn": 1, "decisionId": "coop-4",
		"locked": false, "participant": "p1", "moves": [{"slot": 1, "name": "Pound", "pp": 35, "maxPp": 35}],
		"ownTeam": [{"species": "Jigglypuff", "active": true, "hp": 23, "maxHp": 30},
			{"species": "Ekans", "active": false, "hp": 29, "maxHp": 29}],
		"legalActions": [{"type": "move", "slot": 1, "target": 1}, {"type": "move", "slot": 1, "target": 2},
			{"type": "run"}, {"type": "switch", "slot": 2}],
		"captureOptions": {"balls": [{"itemId": "poke-ball", "quantity": 1}], "storageAvailable": true}}
	presenter.set("_action_signature", "")
	presenter._update_actions()
	_expect(presenter._prompt.text == "What will Jigglypuff do?",
		"co-op action prompt matches singles and names the active Pokémon")
	_expect(mounted_battle.get_node("%MovesGrid").visible
		and mounted_battle.get_node("%BagButton").visible
		and mounted_battle.get_node("%RunButton").visible
		and mounted_battle.get_node("%PlayerPartyGrid").is_slot_selectable(2)
		and not mounted_battle.get_node("%PlayerPartyGrid").is_slot_selectable(1),
		"co-op legal moves, Bag and Run use the existing battle controls")
	var layout_capture_path := OS.get_environment("COOP_BATTLE_LAYOUT_CAPTURE_PATH")
	if not layout_capture_path.is_empty():
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(layout_capture_path) == OK, "co-op battle layout capture saved")
	service.view.legalActions.append({"type": "wait"})
	presenter._action_signature = ""
	presenter._update_actions()
	await process_frame
	await process_frame
	var stage: Control = mounted_battle.get_node("%BattleStage")
	var moves: Control = mounted_battle.get_node("%MovesGrid")
	_expect(moves.get_rect().end.y <= stage.size.y
		and mounted_battle.get_node("%CurrentActionPanel").get_rect().end.y <= stage.size.y
		and not stage.get_parent().crop_to_fill,
		"doubles moves and prompt remain fully inside an uncropped stage")
	_expect(not party_grid.get_child(2).visible and not party_grid.get_child(5).visible,
		"doubles switch row hides empty slots")
	_expect(presenter._wait_button.visible
		and presenter._wait_button.get_parent() == mounted_battle.get_node("%BagButton").get_parent()
		and not presenter._action_scroll.visible,
		"co-op Wait shares the Bag action strip without consuming dock height")
	var dock: Control = mounted_battle.get_node("%ActionsDock")
	_expect(party_grid.get_global_rect().position.y >= dock.get_global_rect().position.y
		and party_grid.get_global_rect().end.y <= dock.get_global_rect().end.y,
		"co-op party slots stay inside the bottom dock below their switch label")
	var dock_height: float = dock.size.y
	service.view.exitRequest = {"type": "run", "requestedBy": "p3"}
	service.view.legalActions = [{"type": "accept-exit"}, {"type": "reject-exit"}]
	presenter._action_signature = ""
	presenter._update_actions()
	await process_frame
	await process_frame
	var dock_rect: Rect2 = dock.get_global_rect()
	var party_rect: Rect2 = party_grid.get_global_rect()
	_expect(presenter._decision_overlay.visible and presenter._actions.get_child_count() == 2
		and dock.size.y <= dock_height + 1.0
		and party_rect.position.y >= dock_rect.position.y
		and party_rect.end.y <= dock_rect.end.y,
		"co-op exit confirmation stays on the stage while switch slots remain inside the fixed dock")
	_expect(presenter._decision_eyebrow.text.contains("PARTNER REQUEST")
		and presenter._decision_title.text == "Flee together?"
		and (presenter._actions.get_child(0) as Button).text == "Agree to flee"
		and (presenter._actions.get_child(1) as Button).text == "Stay and choose again"
		and (presenter._actions.get_child(0) as Button).get_theme_stylebox("normal") is StyleBoxFlat,
		"partner exit request has a clear title and distinct styled choices")
	var decision_capture_path := OS.get_environment("COOP_BATTLE_DECISION_CAPTURE_PATH")
	if not decision_capture_path.is_empty():
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(decision_capture_path) == OK,
			"co-op exit confirmation layout capture saved")
	service.view.erase("exitRequest")
	service.view.legalActions = [{"type": "move", "slot": 1, "target": 1}, {"type": "move", "slot": 1, "target": 2},
		{"type": "run"}, {"type": "switch", "slot": 2}, {"type": "wait"}]
	presenter._bag_open = true
	presenter._action_signature = ""
	presenter._update_actions()
	await process_frame
	_expect(presenter._decision_title.text == "Choose a Poké Ball"
		and (presenter._actions.get_child(0) as Button).text.begins_with("Poke Ball")
		and (presenter._actions.get_child(1) as Button).text == "Back to battle"
		and (presenter._actions.get_child(0) as Button).get_theme_stylebox("hover") is StyleBoxFlat,
		"Poké Ball choices are styled and precede the back action")
	presenter._bag_open = false
	presenter._action_signature = ""
	presenter._update_actions()
	var wait_capture_path := OS.get_environment("COOP_BATTLE_WAIT_LAYOUT_CAPTURE_PATH")
	if not wait_capture_path.is_empty():
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(wait_capture_path) == OK, "co-op Wait layout capture saved")
	service.view.legalActions.pop_back()
	service.view.locked = true
	presenter._action_signature = ""
	presenter._update_actions()
	_expect(not presenter._wait_button.visible, "Wait cannot be selected while the decision is locked")
	service.view.locked = false
	service.view.moves.append({"slot": 2, "name": "Sing", "pp": 15, "maxPp": 15})
	service.view.legalActions.append({"type": "move", "slot": 2, "target": 1})
	presenter._action_signature = ""
	presenter._update_actions()
	presenter._select_move(1)
	_expect(presenter._cancel_target_button.visible and presenter._native_moves.input_disabled
		and not presenter._wait_button.visible
		and presenter._prompt.text == "Jigglypuff will use Pound. Choose a target.",
		"target mode disables moves and shows Cancel instead of other actions")
	presenter._select_move(2)
	_expect(presenter.get("selected_move") == 1,
		"clicking another move cannot replace the pending move selection")
	presenter._cancel_target_button.pressed.emit()
	_expect(presenter.get("selected_move") == 0 and not presenter._cancel_target_button.visible
		and not presenter._native_moves.input_disabled and presenter._native_moves.visible
		and presenter._prompt.text == "What will Jigglypuff do?",
		"Cancel returns to available moves without submitting an action")
	presenter._select_move(1)
	var target_cards: Dictionary = presenter.get("cards")
	var left_enemy_target: Rect2 = target_cards["p2"].target.get_global_rect()
	var right_enemy_target: Rect2 = target_cards["p4"].target.get_global_rect()
	var left_ally_target: Rect2 = target_cards["p1"].target.get_global_rect()
	var right_ally_target: Rect2 = target_cards["p3"].target.get_global_rect()
	_expect(not left_enemy_target.intersects(right_enemy_target)
		and not left_ally_target.intersects(right_ally_target)
		and left_enemy_target.has_point(left_wild.global_position + Vector2(0, 40))
		and right_enemy_target.has_point(right_wild.global_position + Vector2(0, 40))
		and target_cards["p4"].target.visible,
		"separate Pokémon hitboxes reach the feet without overlapping")
	_expect(presenter.get("cards")["p2"].target.visible
		and presenter.get("cards")["p4"].target.visible
		and presenter.get("selected_target") == "p2"
		and (target_cards["p2"].target as Button).get_theme_stylebox("normal") is StyleBoxEmpty
		and left_wild.material is ShaderMaterial
		and right_wild.material == null,
		"choosing a doubles move highlights the selected Pokémon sprite")
	(target_cards["p1"].target as Button).mouse_entered.emit()
	_expect(presenter.get("selected_target") == "p2",
		"a target appearing under the stationary cursor does not select the player's own Pokémon")
	var target_capture_path := OS.get_environment("COOP_BATTLE_TARGET_CAPTURE_PATH")
	if not target_capture_path.is_empty():
		await RenderingServer.frame_post_draw
		_expect(root.get_texture().get_image().save_png(target_capture_path) == OK,
			"co-op sprite target highlight capture saved")
	var foot_hover := InputEventMouseMotion.new()
	foot_hover.relative = Vector2(0, 8)
	(target_cards["p4"].target as Button).gui_input.emit(foot_hover)
	_expect(presenter.get("selected_target") == "p4"
		and right_wild.material is ShaderMaterial
		and left_wild.material == null,
		"hovering another Pokémon moves the selection glow onto its sprite")
	var target_key := InputEventKey.new()
	target_key.pressed = true
	target_key.keycode = KEY_LEFT
	presenter._input(target_key)
	_expect(presenter.get("selected_target") == "p2" and left_wild.material is ShaderMaterial
		and right_wild.material == null,
		"arrow keys move the sprite glow before Space confirms the target")
	target_key.keycode = KEY_ESCAPE
	presenter._input(target_key)
	_expect(presenter.get("selected_move") == 0 and not presenter.get("cards")["p2"].target.visible
		and left_wild.material == null and right_wild.material == null,
		"Escape cancels target selection without submitting an action")
	var capture_player: CaptureBallAnimationPlayer = mounted_battle.get_node("%CaptureBallAnimationPlayer")
	_expect(not presenter._capture_round_ready({"locked": true, "partnerReady": false, "turn": 4, "ended": false}, 4)
		and not presenter._capture_round_ready({"locked": false, "partnerReady": true, "turn": 4, "ended": false}, 4)
		and presenter._capture_round_ready({"locked": true, "partnerReady": true, "turn": 4, "ended": false}, 4)
		and presenter._capture_round_ready({"partnerReady": false, "turn": 5, "ended": false}, 4),
		"shared co-op capture event waits until both choices are locked or the turn resolves")
	_expect(presenter.embedded_hosts.get("capture_player") == capture_player and presenter._capture_status == null,
		"co-op uses the normal capture animation and has no feedback label below the party")
	presenter._capture_target_controller = "p2"
	capture_player.target_absorbed.emit()
	_expect(not left_wild.visible and right_wild.visible,
		"capture absorption hides only the Trainer's assigned wild target")
	capture_player.target_released.emit()
	_expect(left_wild.visible and right_wild.visible,
		"an escaped wild target returns without hiding its partner")
	var thrown_balls: Array = []
	var ball_shakes: Array = []
	capture_player.ball_thrown.connect(func() -> void: thrown_balls.append(true))
	capture_player.ball_shook.connect(func() -> void: ball_shakes.append(true))
	await presenter._play_native_capture_preview("poke-ball", {"shakeCount": 1, "caught": false})
	_expect(thrown_balls.size() == 1 and ball_shakes.size() == 1
		and left_wild.visible and right_wild.visible and not capture_player.visible,
		"co-op catch preview throws and shakes the selected ball, then restores an escaped target")
	var settings_manager := root.get_node("SettingsManager")
	var capture_animations_enabled: bool = settings_manager.battle_animations
	settings_manager.battle_animations = true
	await presenter._animate_event({"kind": "coopcapture", "actor": "p3", "target": "p4",
		"itemId": "poke-ball", "shakeCount": 1, "caught": false, "turn": 1})
	_expect(thrown_balls.size() == 2 and ball_shakes.size() == 2 and right_wild.visible
		and presenter._capture_target_controller == "p4",
		"partner's shared capture event animates the partner's assigned wild Pokémon")
	settings_manager.battle_animations = capture_animations_enabled
	presenter._capture_feedback_text = "The Pokémon escaped from your ball."
	presenter._capture_feedback_until_msec = Time.get_ticks_msec() + 4000
	presenter._action_signature = ""
	presenter._update_actions()
	_expect(presenter._prompt.text == presenter._capture_feedback_text,
		"capture feedback appears in the battlefield prompt instead of below party slots")
	presenter._capture_feedback_text = ""
	presenter._action_signature = ""
	presenter._update_actions()
	var native_sprite := mounted_battle.get_node("%PlayerSpriteBox/DoubleBattleContainer/SpriteSlot/AnimatedPokemonSprite") as AnimatedSprite2D
	var native_origin := native_sprite.position
	var animation_setting: bool = settings_manager.battle_animations
	settings_manager.battle_animations = true
	presenter.set("_playing", true)
	var left_enemy_hp: ProgressBar = mounted_battle.get_node("%EnemyHudPanel/MarginContainer/VBoxContainer/PokemonInfoHud/MarginContainer/VBoxContainer/HPRow/HpBar")
	var right_enemy_hp: ProgressBar = mounted_battle.get_node("%EnemyHudPanel/MarginContainer/VBoxContainer/PokemonInfoHud2/MarginContainer/VBoxContainer/HPRow/HpBar")
	left_enemy_hp.value = 100
	right_enemy_hp.value = 100
	await presenter._animate_event({"kind": "move", "actor": "p1"})
	_expect(left_enemy_hp.value == 100 and right_enemy_hp.value == 100,
		"a move animation does not apply later damage early")
	await presenter._animate_event({"kind": "-damage", "actor": "p2", "hpPercent": 62})
	_expect(left_enemy_hp.value == 62 and right_enemy_hp.value == 100,
		"the first target's HP changes before the next attack")
	await presenter._animate_event({"kind": "move", "actor": "p3"})
	_expect(left_enemy_hp.value == 62 and right_enemy_hp.value == 100,
		"the next move leaves unrelated HP unchanged")
	await presenter._animate_event({"kind": "-damage", "actor": "p4", "hpPercent": 74})
	_expect(left_enemy_hp.value == 62 and right_enemy_hp.value == 74,
		"the second target's HP changes after its own hit")
	await presenter._animate_event({"kind": "-damage", "actor": "p1"})
	var catalog_visuals: Array[Node] = []
	var move_animation_script := load("res://scripts/battle/animations/move_animation_player.gd")
	var visual_added := func(node: Node) -> void:
		if node.get_script() == move_animation_script:
			catalog_visuals.append(node)
	node_added.connect(visual_added)
	await presenter._animate_event({"kind": "move", "actor": "p1", "target": "p4", "move": "Ember", "seq": 201})
	await presenter._animate_event({"kind": "move", "actor": "p3", "target": "p2", "move": "Will-O-Wisp", "seq": 202})
	await presenter._play_native_catalog_move({"kind": "move", "actor": "p1", "move": "Ember",
		"targets": ["p2", "p4"], "seq": 203}, [])
	await presenter._play_native_catalog_move({"kind": "move", "actor": "p1", "target": "p4",
		"move": "Ember", "seq": 204}, [{"kind": "-miss", "actor": "p1", "target": "p4", "seq": 205}])
	node_added.disconnect(visual_added)
	_expect(catalog_visuals.size() == 5,
		"native doubles play catalog effects for both spread targets and a missed target")
	presenter.set("_playing", false)
	settings_manager.battle_animations = animation_setting
	_expect(native_sprite.position == native_origin and native_sprite.modulate == Color.WHITE,
		"generic double attack and hit animation restore only the affected sprite")
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
	var normal_party_style := party_hud.get_theme_stylebox("normal") as StyleBoxFlat
	var hovered_party_style := party_hud.get_theme_stylebox("hover") as StyleBoxFlat
	_expect(normal_party_style.bg_color.a < 0.5 and hovered_party_style.bg_color.a > normal_party_style.bg_color.a,
		"party HUD is translucent over the map and gains contrast on hover")
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
	service.party = {"leaderId": 2, "memberIds": [1.0, 2.0], "memberUsernames": {"1": "TrainerOne", "2": "TrainerTwo"},
		"memberAppearances": {"1": {"body": "Gen4_Base_v1", "gender": "male"}, "2": {"body": "Gen4_Base_F_v1", "gender": "female"}},
		"memberOnline": {"1": true, "2": true},
		"sharedLevelCap": 20}
	overlay_ui.call("_refresh_coop_party_hud")
	var hud_names: Array = party_hud.get("_names")
	var hud_portraits: Array = party_hud.get("_portraits")
	var hud_badges: Array = party_hud.get("_badges")
	_expect(party_hud.visible and hud_names[0].text == "TrainerTwo" and hud_names[1].text == "TrainerOne"
		and hud_badges[0].text == "LEADER · #1" and hud_badges[1].text == "#2", "party HUD keeps the leader first with stable member badges")
	overlay_ui.set_meta("battle_chat_active", true)
	overlay_ui.call("_refresh_coop_party_hud")
	_expect(not party_hud.visible, "co-op presence updates cannot reveal the party HUD over immersive battles")
	overlay_ui.remove_meta("battle_chat_active")
	overlay_ui.call("_refresh_coop_party_hud")
	_expect(party_hud.visible, "party HUD returns after the immersive battle chat closes")
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
	_expect(not service_source.contains('or OS.has_feature("web")')
		and not service_source.contains('if OS.has_feature("web") or not AuthService.is_authenticated():'),
		"browser and desktop share Adventure Party polling and encounter requests")
	_expect(world_source.contains('player.process_mode = web_player_process_mode_before_load\n\t\t\t_setup_coop_controls()')
		and not world_source.contains('if coop_world_ready or OS.has_feature("web"):')
		and not world_source.contains('if not OS.has_feature("web"):\n\t\tvar coop_result:'),
		"browser mounts the shared co-op battle controller after its saved map loads")
	_expect(overlay_source.contains('socials_adventure_party_button.visible = true')
		and not overlay_source.contains('if OS.has_feature("web") or not CoopService.available or not CoopService.activity.is_empty():'),
		"browser can open the same Adventure Party interface")
	_expect(world_source.contains('func _prefetch_coop_web_battle_sprites(')
		and FileAccess.get_file_as_string("res://scripts/battle/battle.gd").contains('player_sprite_box.web_sprite_upgrades_allowed = OS.has_feature("web")'),
		"shared battles load browser battle sprites without adding every sprite to the base export")
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
