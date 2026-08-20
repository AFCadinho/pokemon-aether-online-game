extends RefCounted

class_name BattleDisplayDataPresenter

const OGERPON_BATTLE_FORM := preload("res://scripts/battle/ogerpon_battle_form.gd")
const DEBUG_PAO_BATTLE_IDENTITY := false
const DEBUG_PREFIX := "[PAO Battle Identity Debug]"
const DEBUG_TRAINER_TEAM_DISPLAY := false
const TRAINER_TEAM_DEBUG_PREFIX := "[PAO Trainer Team Display Debug]"

var battle_state: BattleState
var display_metadata := preload("res://scripts/battle/battle_display_metadata.gd").new()


func setup(state: BattleState) -> void:
	battle_state = state
	display_metadata.setup(state)


func set_battle_context(type_value: int, enemy_pokemon: Pokemon) -> void:
	display_metadata.set_battle_context(type_value, enemy_pokemon)


func set_trainer_team(team: Array) -> void:
	display_metadata.set_trainer_team(team)


func get_active_display_species(player_id: String) -> String:
	if battle_state == null:
		return ""

	var active_pokemon := battle_state.get_active_player_pokemon(player_id)
	var transformed_species := str(active_pokemon.get("transformedSpecies", active_pokemon.get("displaySpecies", "")))
	if transformed_species != "":
		if player_id == "p1":
			var saved_for_form: Pokemon = display_metadata.get_player_save_pokemon_for_battle_data(active_pokemon)
			if saved_for_form != null:
				return OGERPON_BATTLE_FORM.resolve_species(
					transformed_species,
					saved_for_form.item
				)
		return transformed_species

	var mega_species := str(active_pokemon.get("megaSpecies", ""))
	if mega_species != "":
		return mega_species

	var persisted_mega_species := battle_state.resolve_persisted_mega_species_for_ident(str(active_pokemon.get("ident", "")))
	if persisted_mega_species != "":
		return persisted_mega_species

	var active_battle_form_species := battle_state.resolve_active_mega_species(player_id)
	if active_battle_form_species != "":
		return active_battle_form_species

	if player_id == "p2":
		var display_pokemon := active_pokemon.duplicate()
		display_metadata.enrich_display_data(player_id, display_pokemon)
		var enriched_species := str(display_pokemon.get("displaySpecies", display_pokemon.get("species", "")))
		if enriched_species != "":
			return enriched_species

	if player_id == "p1":
		var saved_pokemon: Pokemon = display_metadata.get_player_save_pokemon_for_battle_data(active_pokemon)
		if saved_pokemon != null:
			return OGERPON_BATTLE_FORM.resolve_species(saved_pokemon.species, saved_pokemon.item)

	return battle_state.get_active_pokemon_species(player_id)


func get_active_display_name(player_id: String) -> String:
	if battle_state == null:
		return ""

	var active_pokemon := battle_state.get_active_player_pokemon(player_id)
	if player_id == "p1":
		var saved_pokemon: Pokemon = display_metadata.get_player_save_pokemon_for_battle_data(active_pokemon)
		if saved_pokemon != null and saved_pokemon.nickname.strip_edges() != "":
			return saved_pokemon.nickname.strip_edges()

	for key: String in ["nickname", "name", "displayName"]:
		var explicit_name := str(active_pokemon.get(key, "")).strip_edges()
		if explicit_name != "":
			return explicit_name

	var ident := str(active_pokemon.get("ident", ""))
	if ident.contains(": "):
		var ident_name := ident.substr(ident.find(": ") + 2).strip_edges()
		if ident_name != "":
			return ident_name

	return get_active_display_species(player_id)


func get_active_pokemon_is_shiny(player_id: String) -> bool:
	if battle_state == null:
		return false

	var active_pokemon: Dictionary = battle_state.get_active_player_pokemon(player_id).duplicate()
	display_metadata.enrich_display_data(player_id, active_pokemon)
	if player_id == "p1":
		var instance_id := str(active_pokemon.get("instanceId", active_pokemon.get("instance_id", "")))
		var saved_by_instance: Pokemon = display_metadata.get_player_save_pokemon_by_instance_id(instance_id)
		if saved_by_instance != null:
			return saved_by_instance.shiny

		var saved_pokemon: Pokemon = display_metadata.get_player_save_pokemon_for_battle_data(active_pokemon)
		if saved_pokemon != null:
			return saved_pokemon.shiny

	if display_metadata.pokemon_data_has_shiny_value(active_pokemon):
		return display_metadata.get_pokemon_data_shiny_value(active_pokemon)

	return false


func get_display_team_data(player_id: String) -> Array:
	if battle_state == null:
		return []

	var team := battle_state.get_player_team(player_id)
	if DEBUG_PAO_BATTLE_IDENTITY:
		print(DEBUG_PREFIX, " display team raw ", {
			"playerId": player_id,
			"team": _debug_summarize_team(team),
		})

	if player_id == "p2" and display_metadata.has_trainer_team():
		return _get_trainer_display_team_data(team)

	var display_team: Array = []
	for index in range(team.size()):
		var pokemon_data: Variant = team[index]
		if not (pokemon_data is Dictionary):
			display_team.append(pokemon_data)
			continue

		var display_data: Dictionary = get_display_pokemon_data(player_id, pokemon_data as Dictionary)
		if player_id == "p1":
			_enrich_player_display_slot_from_save(display_data, index)
		display_team.append(display_data)

	var sorted_display_team := _sort_display_team_by_canonical_party_slot(display_team)
	if DEBUG_PAO_BATTLE_IDENTITY:
		print(DEBUG_PREFIX, " display team output ", {
			"playerId": player_id,
			"displayTeam": _debug_summarize_team(display_team),
			"sortedDisplayTeam": _debug_summarize_team(sorted_display_team),
		})

	return sorted_display_team


func _get_trainer_display_team_data(request_team: Array) -> Array:
	var trainer_team := display_metadata.get_trainer_team()
	var display_team: Array = []
	_debug_trainer_team_display("input", {
		"requestTeam": _debug_summarize_team(request_team),
		"trainerTeam": _debug_summarize_team(trainer_team),
	})

	for index in range(trainer_team.size()):
		var trainer_value: Variant = trainer_team[index]
		if not (trainer_value is Dictionary):
			display_team.append(trainer_value)
			continue

		var trainer_data: Dictionary = (trainer_value as Dictionary).duplicate(true)
		var canonical_slot := _get_canonical_party_slot(trainer_data)
		if canonical_slot <= 0:
			canonical_slot = index + 1
			trainer_data["metadataSlot"] = canonical_slot
			trainer_data["partySlot"] = canonical_slot
			trainer_data["pokemonKey"] = "p2:slot:%d" % canonical_slot

		var request_data: Dictionary = _find_request_data_for_trainer_slot(
			request_team,
			trainer_data,
			canonical_slot
		)
		_debug_trainer_team_display("slot match", {
			"index": index,
			"canonicalSlot": canonical_slot,
			"trainer": _debug_summarize_pokemon(trainer_data, index),
			"request": _debug_summarize_pokemon(request_data, index) if not request_data.is_empty() else {},
		})
		var display_data := trainer_data.duplicate(true)
		_apply_request_battle_state_to_trainer_display(display_data, request_data)
		display_metadata.enrich_display_data("p2", display_data)
		display_team.append(display_data)

	_debug_trainer_team_display("output", {
		"displayTeam": _debug_summarize_team(display_team),
	})
	return display_team


func _find_request_data_for_trainer_slot(
	request_team: Array,
	trainer_data: Dictionary,
	canonical_slot: int
) -> Dictionary:
	var same_slot_candidate: Dictionary = {}
	var species_candidate: Dictionary = {}
	var species_match_count := 0
	var trainer_species := str(trainer_data.get("species", trainer_data.get("displaySpecies", "")))

	for index in range(request_team.size()):
		var pokemon_value: Variant = request_team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var slot := _get_canonical_party_slot(pokemon_data)
		if slot <= 0:
			slot = index + 1

		if slot == canonical_slot and _pokemon_data_species_matches(trainer_species, pokemon_data):
			same_slot_candidate = pokemon_data

		if _pokemon_data_species_matches(trainer_species, pokemon_data):
			species_match_count += 1
			species_candidate = pokemon_data

	if not same_slot_candidate.is_empty():
		return same_slot_candidate
	if species_match_count == 1:
		return species_candidate

	return {}


func _pokemon_data_species_matches(expected_species: String, pokemon_data: Dictionary) -> bool:
	var actual_species := ""
	if battle_state != null:
		actual_species = battle_state.get_species_from_pokemon_data(pokemon_data)
	if actual_species == "":
		actual_species = str(pokemon_data.get("species", pokemon_data.get("displaySpecies", "")))

	return (
		display_metadata.normalize_species_for_compare(expected_species)
		== display_metadata.normalize_species_for_compare(actual_species)
	)


func _apply_request_battle_state_to_trainer_display(display_data: Dictionary, request_data: Dictionary) -> void:
	if request_data.is_empty():
		_apply_condition_fields_from_display_data(display_data)
		return

	for key in [
		"ident", "condition", "hp", "maxHp", "max_hp", "status", "fainted",
		"active", "activeIdent", "playerId", "level", "gender", "shiny",
		"isShiny", "is_shiny",
	]:
		if request_data.has(key):
			display_data[key] = request_data.get(key)

	_apply_condition_fields_from_display_data(display_data)


func _apply_condition_fields_from_display_data(display_data: Dictionary) -> void:
	var condition := str(display_data.get("condition", "")).strip_edges()
	if condition == "":
		return

	var hp_helper := BattleHpEventHelper.new()
	hp_helper.apply_condition_fields(display_data, condition)


func get_display_pokemon_data(player_id: String, pokemon_data: Dictionary) -> Dictionary:
	var display_data := pokemon_data.duplicate()
	display_metadata.enrich_display_data(player_id, display_data)
	return display_data

func _enrich_player_display_slot_from_save(display_data: Dictionary, index: int) -> void:
	var saved_pokemon := _get_player_save_pokemon_for_display_data(display_data, index)
	if saved_pokemon == null:
		return

	var types_value: Variant = display_data.get("types", [])
	if not display_data.has("types") or not (types_value is Array) or (types_value as Array).is_empty():
		display_data["types"] = saved_pokemon.types
	if not display_data.has("possibleAbilities"):
		display_data["possibleAbilities"] = saved_pokemon.possible_abilities
	if not display_data.has("shiny"):
		display_data["shiny"] = saved_pokemon.shiny
	if not display_data.has("instanceId") and saved_pokemon.instance_id != "":
		display_data["instanceId"] = saved_pokemon.instance_id
	if saved_pokemon.nickname.strip_edges() != "":
		display_data["nickname"] = saved_pokemon.nickname.strip_edges()

	var battle_species := str(display_data.get(
		"displaySpecies",
		display_data.get("species", saved_pokemon.species)
	))
	OGERPON_BATTLE_FORM.apply_to_display_data(display_data, battle_species, saved_pokemon.item)

func _get_player_save_pokemon_for_display_data(display_data: Dictionary, fallback_index: int) -> Pokemon:
	var instance_id := str(display_data.get("instanceId", display_data.get("instance_id", ""))).strip_edges()
	if instance_id != "":
		var pokemon_by_instance := display_metadata.get_player_save_pokemon_by_instance_id(instance_id)
		if pokemon_by_instance != null:
			return pokemon_by_instance

	var canonical_slot := _get_canonical_party_slot(display_data)
	var player_party := _get_player_save_party()
	if canonical_slot > 0:
		var slot_index := canonical_slot - 1
		if slot_index >= 0 and slot_index < player_party.size():
			var slot_pokemon: Pokemon = player_party[slot_index] as Pokemon
			return slot_pokemon

	if fallback_index >= 0 and fallback_index < player_party.size():
		var fallback_pokemon: Pokemon = player_party[fallback_index] as Pokemon
		if _saved_pokemon_matches_display_species(fallback_pokemon, display_data):
			return fallback_pokemon

	return display_metadata.get_unique_player_save_pokemon_by_battle_species(display_data)

func _get_player_save_party() -> Array:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return []

	var player_save := tree.root.get_node_or_null("PlayerSave")
	if player_save == null:
		return []

	var party_value: Variant = player_save.get("party")
	return party_value as Array if party_value is Array else []

func _saved_pokemon_matches_display_species(saved_pokemon: Pokemon, display_data: Dictionary) -> bool:
	if saved_pokemon == null:
		return false
	if battle_state == null:
		return true

	var display_species := battle_state.get_species_from_pokemon_data(display_data)
	if display_species == "":
		display_species = str(display_data.get("species", display_data.get("displaySpecies", "")))
	if display_species == "":
		return true

	return display_metadata.saved_species_is_compatible_with_battle_species(saved_pokemon, display_species)

func _sort_display_team_by_canonical_party_slot(display_team: Array) -> Array:
	if display_team.size() <= 1:
		return display_team

	var by_slot: Dictionary = {}
	for pokemon_value: Variant in display_team:
		if not (pokemon_value is Dictionary):
			return display_team

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var slot := _get_canonical_party_slot(pokemon_data)
		if slot <= 0 or by_slot.has(slot):
			return display_team

		by_slot[slot] = pokemon_data

	var sorted_team: Array = []
	var sorted_slots: Array = by_slot.keys()
	sorted_slots.sort()
	for slot_value: Variant in sorted_slots:
		sorted_team.append(by_slot.get(slot_value))

	return sorted_team

func _get_canonical_party_slot(pokemon_data: Dictionary) -> int:
	var party_slot := _get_positive_slot_from_pokemon_data(pokemon_data, ["partySlot", "party_slot"])
	if party_slot > 0:
		return party_slot

	var metadata_slot := _get_positive_slot_from_pokemon_data(pokemon_data, ["metadataSlot", "metadata_slot"])
	if metadata_slot > 0:
		return metadata_slot

	return _get_pokemon_key_canonical_party_slot(pokemon_data)

func _get_pokemon_key_canonical_party_slot(pokemon_data: Dictionary) -> int:
	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	var slot_marker := ":slot:"
	if pokemon_key.contains(slot_marker):
		var slot_text := pokemon_key.split(slot_marker)[1]
		if slot_text.is_valid_int():
			var key_slot := int(slot_text)
			if key_slot > 0:
				return key_slot

	return -1

func _get_positive_slot_from_pokemon_data(pokemon_data: Dictionary, keys: Array) -> int:
	for key in keys:
		if not pokemon_data.has(key):
			continue

		var slot_value: Variant = pokemon_data.get(key)
		if slot_value is int and int(slot_value) > 0:
			return int(slot_value)
		if slot_value is float and int(slot_value) > 0:
			return int(slot_value)

		var explicit_slot_text := str(slot_value).strip_edges()
		if explicit_slot_text.is_valid_int():
			var parsed_slot := int(explicit_slot_text)
			if parsed_slot > 0:
				return parsed_slot

	return -1

func _debug_summarize_team(team: Array) -> Array:
	var output: Array = []
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			output.append({"index": index, "value": pokemon_value})
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		output.append({
			"index": index,
			"ident": str(pokemon.get("ident", "")),
			"active": bool(pokemon.get("active", false)),
			"details": str(pokemon.get("details", "")),
			"species": str(pokemon.get("species", "")),
			"displaySpecies": str(pokemon.get("displaySpecies", "")),
			"partySlot": pokemon.get("partySlot", ""),
			"metadataSlot": pokemon.get("metadataSlot", ""),
			"pokemonKey": str(pokemon.get("pokemonKey", "")),
			"instanceId": str(pokemon.get("instanceId", pokemon.get("instance_id", ""))),
			"condition": str(pokemon.get("condition", "")),
		})

	return output


func _debug_summarize_pokemon(pokemon_data: Dictionary, index: int) -> Dictionary:
	return {
		"index": index,
		"ident": str(pokemon_data.get("ident", "")),
		"active": bool(pokemon_data.get("active", false)),
		"details": str(pokemon_data.get("details", "")),
		"species": str(pokemon_data.get("species", "")),
		"displaySpecies": str(pokemon_data.get("displaySpecies", "")),
		"condition": str(pokemon_data.get("condition", "")),
		"hp": str(pokemon_data.get("hp", "")),
		"maxHp": str(pokemon_data.get("maxHp", "")),
		"fainted": bool(pokemon_data.get("fainted", false)),
		"partySlot": str(pokemon_data.get("partySlot", pokemon_data.get("party_slot", ""))),
		"metadataSlot": str(pokemon_data.get("metadataSlot", pokemon_data.get("metadata_slot", ""))),
		"pokemonKey": str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))),
		"requestIndex": str(pokemon_data.get("requestIndex", "")),
	}


func _debug_trainer_team_display(stage: String, payload: Dictionary) -> void:
	if not DEBUG_TRAINER_TEAM_DISPLAY:
		return

	print(TRAINER_TEAM_DEBUG_PREFIX, " ", stage, " ", JSON.stringify(payload))

func _normalize_species_for_compare(species: String) -> String:
	return species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")
