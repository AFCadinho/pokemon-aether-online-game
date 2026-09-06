extends Node

const BATTLE_SCENE := preload("res://scenes/battle/battle.tscn")

class PartySaveSpy extends PlayerPartyStateServiceNode:
	var saves := 0
	func save_current_battle_party_state_deferred(_context: Dictionary = {}) -> void:
		saves += 1

class PartyHealSpy extends PartyHealServiceNode:
	var heals := 0
	func heal_current_party_and_save(_respawn_point: Dictionary = {}, _public_service := true) -> Dictionary:
		heals += 1
		return {"success": true}

var failed := false

func _ready() -> void:
	# Intercept persistence before authentication or HTTP: any attempted save
	# is a failure, even in this deliberately unauthenticated test process.
	PlayerPartyStateService.set_script(PartySaveSpy)
	PartyHealService.set_script(PartyHealSpy)
	var own := Pokemon.new("Bulbasaur", 50)
	own.species = "Bulbasaur"
	own.instance_id = "spectator-owned"
	own.owned_pokemon_id = 901
	own.max_hp = 240
	own.current_hp = 173
	own.has_saved_hp_state = true
	own.status = "psn"
	own.moves = [{"id": "tackle", "name": "Tackle", "pp": 12, "maxPp": 35}]
	var second := Pokemon.new("Squirtle", 40)
	second.instance_id = "spectator-second"
	second.owned_pokemon_id = 903
	second.max_hp = 150
	second.current_hp = 0
	second.has_saved_hp_state = true
	PlayerSave.party.assign([own, second])
	var before := PlayerSave.to_party_state().duplicate(true)
	var battle := BATTLE_SCENE.instantiate()
	add_child(battle)
	await get_tree().process_frame
	battle.battle_type = 1
	battle.pvp_room_code = "isolation-test"
	battle.pvp_viewer_role = "spectator"
	battle.action_flow.set_local_player_id("p1")

	for condition: String in ["100/100", "35/100 brn", "0 fnt", "75/100 par"]:
		var snapshot := _snapshot(condition)
		battle.battle_state.load_from_api_response(snapshot, false)
		battle._sync_player_save_party_status_from_battle_state()
		battle._sync_player_save_from_battle_state()
		battle._apply_party_state_from_api_response({"party": [{"species": "Eevee", "condition": condition}]})
		battle._restore_pvp_authoritative_presentation(snapshot)
		_check(PlayerSave.to_party_state() == before, "snapshot/render preserves own party: " + condition)
		_check(battle.battle_state.get_player_team("p1").size() == 1, "public battle state still loads")

	battle.spectator_latest_raw_response = _snapshot("35/100 brn")
	battle._on_spectator_switch_sides_pressed()
	_check(battle.action_flow.local_player_id == "p2", "spectator perspective actually swaps")
	battle._sync_player_save_party_status_from_battle_state()
	_check(PlayerSave.to_party_state() == before, "perspective swap preserves own party")
	_check(battle._apply_api_response(_snapshot("75/100 par"), false, "reconnect"), "reconnect response is accepted")
	_check(PlayerSave.to_party_state() == before, "reconnect response preserves own party")
	battle._heal_local_party_after_pvp_battle()
	await battle._heal_party_after_pvp_battle()
	_check(PlayerSave.to_party_state() == before, "spectator cannot heal own party")

	for reason: String in ["win", "forfeit", "timeout", "disconnect", "battle_time_limit_draw", "infrastructure_no_contest", "spectator_left"]:
		battle.battle_finished = false
		var result := {"reason": reason}
		battle._finish_battle(result)
		_check(bool(result.get("skipPartyBattleSync", false)), reason + " centrally excludes party save")
		_check(not bool(result.get("localPartyDefeated", true)), reason + " cannot trigger spectator blackout")
		_check(PlayerSave.to_party_state() == before, reason + " preserves own party")
	_check(int(PlayerPartyStateService.get("saves")) == 0, "no spectator terminal path attempts persistence")
	_check(int(PartyHealService.get("heals")) == 0, "no spectator path attempts server healing")

	# Participant regression: explicit identity wins over a misleading slot;
	# foreign or contradictory identities never fall back to slot/species.
	battle.pvp_viewer_role = "participant"
	for entry: Dictionary in [
		{"instanceId": "foreign", "metadataSlot": 1},
		{"ownedPokemonId": 902, "instanceId": own.instance_id, "metadataSlot": 1},
		{"ownedPokemonId": 901, "instanceId": "foreign", "metadataSlot": 1},
	]:
		_check(battle._find_saved_party_pokemon_for_battle_data(entry, 0) == null, "foreign identity rejected by live sync")
		entry.merge({"species": "Bulbasaur", "condition": "0 fnt"})
		PlayerSave.apply_battle_team_state([entry])
		_check(PlayerSave.to_party_state() == before, "foreign identity rejected by terminal sync")
	var owned_entry := {"instanceId": own.instance_id, "metadataSlot": 6, "condition": "120/240 brn", "hp": 120, "maxHp": 240}
	_check(battle._find_saved_party_pokemon_for_battle_data(owned_entry, 5) == own, "owned identity survives reordered battle slots")
	PlayerSave.apply_battle_team_state([owned_entry])
	_check(own.current_hp == 120 and own.max_hp == 240 and own.status == "brn", "participant terminal sync still updates own Pokemon")
	_check(battle._find_saved_party_pokemon_for_battle_data({"metadataSlot": 1}, 0) == own, "legacy identity-free slot mapping still works")
	battle.battle_state.load_from_api_response(_snapshot("90/100 par"), false)
	battle._sync_player_save_party_status_from_battle_state()
	_check(own.current_hp == 90 and own.status == "par", "participant live sync still works")
	battle.battle_finished = false
	battle._finish_battle({"reason": "forfeit"})
	await get_tree().process_frame
	_check(int(PlayerPartyStateService.get("saves")) == 0, "participant PvP still skips battle-state saves")
	_check(int(PartyHealService.get("heals")) == 1, "participant terminal still invokes server healing")
	battle.pvp_room_code = ""
	battle.battle_finished = false
	battle._finish_battle({"reason": "win", "winner": "p1"})
	_check(int(PlayerPartyStateService.get("saves")) == 1, "ordinary trainer victory still invokes party persistence")
	remove_child(battle)
	battle.free()
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)

func _snapshot(condition: String) -> Dictionary:
	var requests := {}
	for side: String in ["p1", "p2"]:
		requests[side] = {"wait": true, "side": {"id": side, "pokemon": [{
			"ident": side + "a: Eevee", "species": "Eevee", "details": "Eevee, L50",
			"condition": condition, "active": true,
		}]}}
	return {
		"success": true, "viewerRole": "spectator", "battleId": "isolation-test",
		"players": {"p1": {"name": "Alpha"}, "p2": {"name": "Bravo"}},
		"requests": requests, "state": {"turn": 1}, "events": [], "field": {"effects": []},
	}

func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS " + label)
	else:
		failed = true
		push_error("FAIL " + label)
