extends SceneTree

const PLAYER_DATA := preload("res://scripts/data/player_data.gd")
const POKEMON := preload("res://scripts/data/pokemon.gd")

var failures := 0


func _init() -> void:
	_check_first_usable_party_slot_skips_fainted_lead()
	_check_missing_saved_hp_remains_usable()
	_check_all_fainted_party_has_no_lead()
	_check_trainer_flow_uses_resolved_lead()

	if failures == 0:
		print("Trainer fainted lead checks passed.")
		quit(0)
		return

	push_error("Trainer fainted lead checks failed: %d" % failures)
	quit(1)


func _check_first_usable_party_slot_skips_fainted_lead() -> void:
	var player := PLAYER_DATA.new() as PlayerData
	var mankey := _pokemon("Mankey", 0, true)
	var pikipek := _pokemon("Pikipek", 17, true)
	player.party = [mankey, pikipek]

	_check_equal(player.get_first_usable_party_slot(), 2, "fainted slot 1 is skipped")
	player.free()


func _check_missing_saved_hp_remains_usable() -> void:
	var player := PLAYER_DATA.new() as PlayerData
	var pokemon := _pokemon("Pikipek", 0, false)
	player.party = [pokemon]

	_check_equal(player.get_first_usable_party_slot(), 1, "missing saved HP is treated as usable")
	player.free()


func _check_all_fainted_party_has_no_lead() -> void:
	var player := PLAYER_DATA.new() as PlayerData
	player.party = [
		_pokemon("Mankey", 0, true),
		_pokemon("Pikipek", 0, true),
	]

	_check_equal(player.get_first_usable_party_slot(), -1, "all-fainted party has no usable lead")
	player.free()


func _check_trainer_flow_uses_resolved_lead() -> void:
	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var battle_source := FileAccess.get_file_as_string("res://scripts/battle/battle.gd")

	_check(
		world_source.contains("var player_lead_slot := PlayerSave.get_first_usable_party_slot()"),
		"world resolves a usable trainer lead before creating the battle"
	)
	_check(
		world_source.contains("await battle_instance.setup_trainer_battle_from_response(\n\t\tplayer_lead_pokemon,"),
		"world passes the resolved lead to the trainer battle UI"
	)
	_check(
		battle_source.contains('var player_lead_response := await _submit_lead("p1", player_lead_slot)'),
		"regular trainer lead submission uses the resolved slot"
	)
	_check(
		not battle_source.contains('var player_lead_response := await _submit_lead("p1", 1)'),
		"regular trainer lead submission is no longer hardcoded to slot 1"
	)
	_check(
		battle_source.contains("active_player_pokemon = selected_player_pokemon"),
		"trainer intro retains the server-selected saved Pokémon"
	)


func _pokemon(species: String, current_hp: int, has_saved_hp: bool) -> Pokemon:
	var pokemon := POKEMON.new(species, 10) as Pokemon
	pokemon.max_hp = 20
	pokemon.current_hp = current_hp
	pokemon.has_saved_hp_state = has_saved_hp
	return pokemon


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS: %s" % label)
		return

	failures += 1
	push_error("FAIL: %s" % label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s (expected=%s actual=%s)" % [label, str(expected), str(actual)])
