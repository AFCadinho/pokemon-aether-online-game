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
	_check(is_equal_approx(indicator.sprite.scale.x, 0.56), "battle indicator uses the compact visual scale")
	var card_top: float = avatar.nameplate.position.y + avatar.nameplate_background.offset_top
	_check(
		is_equal_approx(indicator.anchor_position.y, card_top - 11.0),
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
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")
	_check(
		world_source.contains('"battleSpectate": _get_current_battle_spectate_presence()')
		and world_source.contains('active_battle_kind not in ["wild", "trainer"]'),
		"world presence only advertises active wild and NPC battles"
	)
	_check(realtime_source.contains('else "/ws/pve-live"'), "nearby spectators use the read-only PvE stream")
	var spectator_snapshot_index := battle_source.find(
		"if _is_spectator_battle():\n\t\t# A spectator entering an active battle needs the canonical state now"
	)
	var initial_summon_index := battle_source.find(
		'await _present_initial_summon_command("p1", _get_active_display_name("p1"))',
		spectator_snapshot_index
	)
	_check(
		spectator_snapshot_index >= 0
		and initial_summon_index > spectator_snapshot_index
		and battle_source.substr(spectator_snapshot_index, initial_summon_index - spectator_snapshot_index).contains(
			"_apply_spectator_late_join_snapshot(api_response)"
		)
		and battle_source.substr(spectator_snapshot_index, initial_summon_index - spectator_snapshot_index).contains(
			"\n\t\treturn\n"
		),
		"spectators render the current snapshot and return before initial summon animations"
	)
	avatar.queue_free()
	await _check_trainer_spectator_presentation()
	quit(1 if failed else 0)


func _check_trainer_spectator_presentation() -> void:
	var battle_scene := load("res://scenes/battle/battle.tscn") as PackedScene
	_check(battle_scene != null, "battle scene loads for nearby trainer spectator presentation")
	if battle_scene == null:
		return
	var battle := battle_scene.instantiate()
	root.add_child(battle)
	await process_frame
	battle.battle_type = 1 # BattleType.TRAINER
	battle.pvp_room_code = "PVE-TRAINER-TEST"
	battle.pvp_viewer_role = "spectator"
	battle.spectator_source_battle_kind = "trainer"
	battle.spectator_public_team_sizes = {"p1": 3, "p2": 2}
	battle.spectator_trainer_presentation = {
		"trainerId": "kanto_route_1_lass_zoe",
		"name": "Lass Zoe",
		"trainerClass": "Lass",
	}
	battle.player_stage_party_grid.set_empty_slots_visible(true)
	battle.opponent_party_grid.set_empty_slots_visible(true)
	var snapshot := _trainer_snapshot()
	battle.action_flow.set_local_player_id("p1")
	battle.spectator_latest_raw_response = snapshot.duplicate(true)
	battle.battle_state.load_from_api_response(snapshot, false)
	battle._show_pvp_trainers(snapshot)
	battle._update_party_slots()
	await process_frame

	_check(
		battle.player_trainer_sprite.player_avatar != null
		and battle.player_trainer_sprite.visible,
		"nearby trainer spectating stages the observed player avatar"
	)
	_check(
		battle.enemy_trainer_sprite.catalog_sprite.visible
		and battle.enemy_trainer_sprite.catalog_sprite.texture != null,
		"nearby trainer spectating resolves and stages the NPC trainer art"
	)
	_check(
		battle.player_stage_party_grid.current_party_data.size() == 3
		and bool(battle.player_stage_party_grid.current_party_data[1].get("unrevealed", false))
		and battle.opponent_party_grid.current_party_data.size() == 2
		and bool(battle.opponent_party_grid.current_party_data[1].get("unrevealed", false)),
		"public team counts create concealed reserve slots on both sides"
	)
	var opponent_reserve: Node = battle.opponent_party_grid.get_child(1)
	var opponent_reserve_icon := opponent_reserve.get("pokemon_icon") as TextureRect
	_check(
		opponent_reserve_icon != null and opponent_reserve_icon.texture == POKE_BALL,
		"concealed trainer reserves use the standard Poke Ball placeholder"
	)

	battle._on_spectator_switch_sides_pressed()
	await process_frame
	_check(
		battle.player_trainer_sprite.catalog_sprite.visible
		and battle.enemy_trainer_sprite.player_avatar != null,
		"switching spectator view keeps the NPC and player trainer art on their owning sides"
	)
	_check(
		battle.player_stage_party_grid.current_party_data.size() == 2
		and battle.opponent_party_grid.current_party_data.size() == 3,
		"switching spectator view also swaps the public team counts"
	)
	battle.queue_free()
	await process_frame


func _trainer_snapshot() -> Dictionary:
	return {
		"success": true,
		"viewerRole": "spectator",
		"battleId": "trainer-test",
		"players": {
			"p1": {"name": "Admin", "appearance": {"body": "Red", "gender": "male"}},
			"p2": {"name": "Lass Zoe"},
		},
		"requests": {
			"p1": {"wait": true, "side": {"id": "p1", "pokemon": [_public_lead("p1", "Samurott-Hisui")]}},
			"p2": {"wait": true, "side": {"id": "p2", "pokemon": [_public_lead("p2", "Nidoqueen")]}},
		},
		"state": {"turn": 1, "ended": false},
		"field": {"effects": []},
		"events": [],
		"eventBatches": [],
	}


func _public_lead(player_id: String, species: String) -> Dictionary:
	return {
		"ident": "%sa: %s" % [player_id, species],
		"details": "%s, L100" % species,
		"species": species,
		"displaySpecies": species,
		"level": 100,
		"active": true,
		"condition": "100/100",
		"hp": 100,
		"maxHp": 100,
		"fainted": false,
	}


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
