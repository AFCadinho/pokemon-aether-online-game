extends RefCounted

class_name BattleState

var battle_id := ""
var format_id := ""
var players := {}
var requests := {}
var battle_log := []
var battle_status_api := {}
var field: Dictionary = {}
var hp_event_helper := BattleHpEventHelper.new()
var transformed_species_by_ident: Dictionary = {}
var mega_species_by_ident: Dictionary = {}
var hp_snapshot_by_ident: Dictionary = {}


## Laadt een volledige battle response van de API in deze state.
func load_from_api_response(response: Dictionary, apply_event_conditions: bool = true) -> void:
	var next_battle_id := str(response.get("battleId", ""))
	if battle_id != "" and next_battle_id != battle_id:
		transformed_species_by_ident.clear()
		mega_species_by_ident.clear()
		hp_snapshot_by_ident.clear()

	battle_id = next_battle_id
	format_id = str(response.get("formatId", ""))
	players = response.get("players", {})
	_remember_hp_fields_from_requests(requests)
	var next_requests: Variant = response.get("requests", {})
	if next_requests is Dictionary:
		var next_requests_dictionary: Dictionary = next_requests as Dictionary
		_preserve_missing_hp_fields_in_requests(next_requests_dictionary)
	requests = next_requests
	battle_log = response.get("log", [])
	battle_status_api = response.get("state", {})
	field = response.get("field", {})
	_debug_print_damage_response_snapshot(response, "after_assign_before_events")
	if apply_event_conditions:
		_apply_mega_species_to_requests()
		_apply_transformed_species_to_requests()
		_apply_event_conditions_to_requests(response.get("events", []))
	else:
		_apply_mega_species_to_requests()
		_remove_deferred_display_fields_from_requests(response.get("events", []))
	_remember_hp_fields_from_requests(requests)
	_debug_print_damage_response_snapshot(response, "after_events")

func apply_event_conditions(events: Array) -> void:
	_apply_event_conditions_to_requests(events)

func _debug_print_damage_response_snapshot(response: Dictionary, label: String) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var has_damage := false
	var events: Array = events_value as Array
	for event_value: Variant in events:
		if event_value is Dictionary and str((event_value as Dictionary).get("type", "")) == "damage":
			has_damage = true
			break

	if not has_damage:
		return

	print("[pvp-damage-debug] state.load %s battle=%s eventSeq=%s p1=%s p2=%s events=%s" % [
		label,
		str(response.get("battleId", "")),
		str(response.get("eventSeq", "")),
		JSON.stringify(_debug_team_identity_snapshot(get_player_team("p1"))),
		JSON.stringify(_debug_team_identity_snapshot(get_player_team("p2"))),
		JSON.stringify(events),
	])

func _preserve_missing_hp_fields_in_requests(next_requests: Dictionary) -> void:
	if requests.is_empty() or next_requests.is_empty():
		return

	for player_id_value: Variant in next_requests.keys():
		var player_id: String = str(player_id_value)
		var next_request_value: Variant = next_requests.get(player_id, {})
		var previous_request_value: Variant = requests.get(player_id, {})
		if not (next_request_value is Dictionary) or not (previous_request_value is Dictionary):
			continue

		var next_request_dictionary: Dictionary = next_request_value as Dictionary
		var previous_request_dictionary: Dictionary = previous_request_value as Dictionary
		_preserve_missing_hp_fields_in_request(
			next_request_dictionary,
			previous_request_dictionary
		)

func _preserve_missing_hp_fields_in_request(next_request: Dictionary, previous_request: Dictionary) -> void:
	var next_side_value: Variant = next_request.get("side", {})
	var previous_side_value: Variant = previous_request.get("side", {})
	if not (next_side_value is Dictionary) or not (previous_side_value is Dictionary):
		return

	var next_team_value: Variant = (next_side_value as Dictionary).get("pokemon", [])
	var previous_team_value: Variant = (previous_side_value as Dictionary).get("pokemon", [])
	if not (next_team_value is Array) or not (previous_team_value is Array):
		return

	var next_team: Array = next_team_value as Array
	var previous_team: Array = previous_team_value as Array
	var previous_by_key: Dictionary = {}
	for previous_index in range(previous_team.size()):
		var previous_value: Variant = previous_team[previous_index]
		if not (previous_value is Dictionary):
			continue

		var previous_pokemon: Dictionary = previous_value as Dictionary
		var previous_key := _get_party_hp_snapshot_key(previous_pokemon, previous_index)
		if previous_key == "":
			continue

		previous_by_key[previous_key] = previous_pokemon

	for next_index in range(next_team.size()):
		var next_value: Variant = next_team[next_index]
		if not (next_value is Dictionary):
			continue

		var next_pokemon: Dictionary = next_value as Dictionary
		var next_key := _get_party_hp_snapshot_key(next_pokemon, next_index)
		if next_key == "":
			continue

		var previous_pokemon: Dictionary = previous_by_key[next_key] as Dictionary if previous_by_key.has(next_key) else {}
		_preserve_missing_hp_fields_in_pokemon(next_pokemon, previous_pokemon, next_key)

func _preserve_missing_hp_fields_in_pokemon(next_pokemon: Dictionary, previous_pokemon: Dictionary, memory_key := "") -> void:
	var snapshot_key := memory_key if memory_key != "" else _get_party_hp_snapshot_key(next_pokemon)
	var memory_snapshot_value: Variant = hp_snapshot_by_ident.get(snapshot_key, {})
	var memory_snapshot: Dictionary = memory_snapshot_value as Dictionary if memory_snapshot_value is Dictionary else {}
	if _should_preserve_remembered_hp_snapshot(next_pokemon, memory_snapshot):
		var remembered_hp := int(memory_snapshot.get("hp", 0))
		var remembered_max_hp: int = max(int(memory_snapshot.get("max_hp", 1)), 1)
		var remembered_condition := str(memory_snapshot.get("condition", ""))
		if remembered_condition == "":
			remembered_condition = "0 fnt" if remembered_hp <= 0 else "%s/%s" % [remembered_hp, remembered_max_hp]

		next_pokemon["hp"] = remembered_hp
		next_pokemon["maxHp"] = remembered_max_hp
		next_pokemon["condition"] = remembered_condition
		next_pokemon["fainted"] = remembered_hp <= 0
		return

	if bool(next_pokemon.get("fainted", false)):
		next_pokemon["hp"] = 0
		var fainted_previous_snapshot: Dictionary = _get_pokemon_hp_snapshot(previous_pokemon)
		var fainted_previous_max_hp: int = int(previous_pokemon.get("maxHp", fainted_previous_snapshot.get("max_hp", 0)))
		if fainted_previous_max_hp <= 0 and not memory_snapshot.is_empty():
			fainted_previous_max_hp = int(memory_snapshot.get("max_hp", 0))
		if fainted_previous_max_hp > 0:
			next_pokemon["maxHp"] = fainted_previous_max_hp
		next_pokemon["condition"] = "0 fnt"
		return

	var previous_condition: String = str(previous_pokemon.get("condition", ""))
	var previous_snapshot: Dictionary = _get_pokemon_hp_snapshot(previous_pokemon)
	var previous_hp: int = int(previous_pokemon.get("hp", previous_snapshot.get("hp", 0)))
	var previous_max_hp: int = int(previous_pokemon.get("maxHp", previous_snapshot.get("max_hp", 0)))
	if not memory_snapshot.is_empty():
		previous_hp = int(memory_snapshot.get("hp", previous_hp))
		previous_max_hp = int(memory_snapshot.get("max_hp", previous_max_hp))
		if previous_condition == "":
			previous_condition = str(memory_snapshot.get("condition", ""))
	if previous_max_hp <= 0:
		return

	if _pokemon_has_valid_hp_snapshot(next_pokemon) and not _pokemon_uses_percentage_hp_snapshot(next_pokemon, previous_max_hp):
		return

	next_pokemon["hp"] = previous_hp
	next_pokemon["maxHp"] = previous_max_hp
	if previous_condition != "" and (
		not _condition_has_valid_hp_snapshot(str(next_pokemon.get("condition", "")))
		or _pokemon_uses_percentage_hp_snapshot(next_pokemon, previous_max_hp)
	):
		next_pokemon["condition"] = previous_condition

func _pokemon_has_valid_hp_snapshot(pokemon_data: Dictionary) -> bool:
	if _condition_has_valid_hp_snapshot(str(pokemon_data.get("condition", ""))):
		return true

	return int(pokemon_data.get("maxHp", 0)) > 0

func _pokemon_uses_percentage_hp_snapshot(pokemon_data: Dictionary, previous_max_hp: int) -> bool:
	if previous_max_hp <= 100:
		return false

	var snapshot: Dictionary = _get_pokemon_hp_snapshot(pokemon_data)
	if snapshot.is_empty():
		return false

	return int(snapshot.get("max_hp", 0)) == 100

func _should_preserve_remembered_hp_snapshot(pokemon_data: Dictionary, memory_snapshot: Dictionary) -> bool:
	if memory_snapshot.is_empty():
		return false

	var remembered_max_hp := int(memory_snapshot.get("max_hp", 0))
	if remembered_max_hp <= 0:
		return false

	var remembered_hp := int(memory_snapshot.get("hp", remembered_max_hp))
	if remembered_hp >= remembered_max_hp:
		return false

	var incoming_snapshot: Dictionary = _get_pokemon_hp_snapshot(pokemon_data)
	if incoming_snapshot.is_empty():
		return true

	var incoming_hp := int(incoming_snapshot.get("hp", 0))
	var incoming_max_hp := int(incoming_snapshot.get("max_hp", 0))
	if incoming_hp >= incoming_max_hp and incoming_max_hp > 0:
		return true

	if incoming_max_hp == remembered_max_hp and incoming_hp < remembered_hp:
		return true

	return false

func _get_pokemon_hp_snapshot(pokemon_data: Dictionary) -> Dictionary:
	var condition_snapshot: Dictionary = hp_event_helper.parse_condition_hp_snapshot(str(pokemon_data.get("condition", "")))
	if not condition_snapshot.is_empty():
		return condition_snapshot

	var max_hp := int(pokemon_data.get("maxHp", 0))
	if max_hp <= 0:
		return {}

	return {
		"hp": int(pokemon_data.get("hp", 0)),
		"max_hp": max_hp,
	}

func _condition_has_valid_hp_snapshot(condition: String) -> bool:
	return not hp_event_helper.parse_condition_hp_snapshot(condition).is_empty()

func _remember_hp_fields_from_requests(requests_value: Variant) -> void:
	if not (requests_value is Dictionary):
		return

	for request_value: Variant in (requests_value as Dictionary).values():
		if not (request_value is Dictionary):
			continue

		var side_value: Variant = (request_value as Dictionary).get("side", {})
		if not (side_value is Dictionary):
			continue

		var team_value: Variant = (side_value as Dictionary).get("pokemon", [])
		if not (team_value is Array):
			continue

		for pokemon_index in range((team_value as Array).size()):
			var pokemon_value: Variant = (team_value as Array)[pokemon_index]
			if not (pokemon_value is Dictionary):
				continue

			var pokemon: Dictionary = pokemon_value as Dictionary
			var snapshot_key := _get_party_hp_snapshot_key(pokemon, pokemon_index)
			if snapshot_key == "":
				continue

			if bool(pokemon.get("fainted", false)):
				var previous_snapshot_value: Variant = hp_snapshot_by_ident.get(snapshot_key, {})
				var previous_snapshot: Dictionary = previous_snapshot_value as Dictionary if previous_snapshot_value is Dictionary else {}
				var previous_max_hp := int(previous_snapshot.get("max_hp", int(pokemon.get("maxHp", 0))))
				hp_snapshot_by_ident[snapshot_key] = {
					"hp": 0,
					"max_hp": previous_max_hp,
					"condition": "0 fnt",
				}
				continue

			var snapshot: Dictionary = _get_pokemon_hp_snapshot(pokemon)
			if snapshot.is_empty():
				continue

			var max_hp := int(snapshot.get("max_hp", 0))
			if max_hp <= 0:
				continue

			var previous_memory_value: Variant = hp_snapshot_by_ident.get(snapshot_key, {})
			var previous_memory: Dictionary = previous_memory_value as Dictionary if previous_memory_value is Dictionary else {}
			if max_hp == 100 and int(previous_memory.get("max_hp", 0)) > 100:
				continue

			hp_snapshot_by_ident[snapshot_key] = {
				"hp": int(snapshot.get("hp", 0)),
				"max_hp": max_hp,
				"condition": str(pokemon.get("condition", "")),
			}

func resolve_active_mega_species(player_id: String = "p1") -> String:
	var request_mega_species := _get_active_mega_species_from_request_slot(player_id)
	if request_mega_species != "":
		return request_mega_species

	return _get_mega_species_for_pokemon_data(get_active_player_pokemon(player_id))

func resolve_persisted_mega_species_for_ident(ident: String) -> String:
	var mega_key := _get_transform_key_from_ident(ident)
	if mega_key == "":
		return ""

	return str(mega_species_by_ident.get(mega_key, "")).strip_edges()

func resolve_mega_species_for_event(event: Dictionary) -> String:
	var event_species := str(event.get("species", "")).strip_edges()
	if _is_mega_species(event_species):
		return event_species

	var target_ident := str(event.get("target", ""))
	if target_ident == "":
		return ""

	var pokemon_data: Dictionary = _get_side_pokemon_by_ident(target_ident)
	if pokemon_data.is_empty():
		pokemon_data = _get_active_side_pokemon(_get_player_id_from_ident(target_ident))
	if pokemon_data.is_empty():
		return ""

	var base_species := _strip_mega_suffix(event_species)
	if base_species == "":
		base_species = _strip_mega_suffix(get_species_from_pokemon_data(pokemon_data))

	var event_item := str(event.get("item", ""))
	var species_from_event_item := _get_mega_species_for_base_and_item(base_species, event_item)
	if species_from_event_item != "":
		return species_from_event_item

	var species_from_pokemon_data := _get_mega_species_for_pokemon_data(pokemon_data)
	if species_from_pokemon_data != "":
		return species_from_pokemon_data

	return _get_active_mega_species_from_request_slot(_get_player_id_from_ident(target_ident))

## Geeft de laatste request-state voor een speler terug.
func get_player_request(player_id: String = "p1") -> Dictionary:
	return requests.get(player_id, {})

## Geeft de side-data voor een speler terug.
func get_player_side(player_id: String = "p1") -> Dictionary:
	return get_player_request(player_id).get("side", {})

func _apply_event_conditions_to_requests(events_value: Variant) -> void:
	if not (events_value is Array):
		return

	for event_value in events_value:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type := str(event.get("type", ""))
		if event_type == "switch":
			_apply_switch_event_to_requests(event)
			_clear_transform_event_from_requests(event)
			continue

		if event_type == "transform":
			_apply_transform_event_to_requests(event)
			continue

		if event_type == "mega":
			_apply_mega_event_to_requests(event)
			continue

		if event_type == "faint":
			_clear_transformed_species_for_ident(str(event.get("target", "")))

		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident := str(event.get("target", ""))
		var condition := _get_condition_from_event(event)
		if target_ident == "" or condition == "":
			continue

		_set_pokemon_condition(target_ident, condition, event)

func _apply_switch_event_to_requests(event: Dictionary) -> void:
	var switch_ident := _get_switch_event_ident(event)
	if switch_ident == "":
		return

	var player_id := _get_player_id_from_ident(switch_ident)
	if player_id == "":
		return

	var team := get_player_team(player_id)
	var target_index := _find_party_target_index(team, switch_ident, event, false)
	if target_index < 0 or target_index >= team.size():
		return

	var condition := _get_condition_from_event(event)
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var is_target := index == target_index
		pokemon_data["active"] = is_target
		if not is_target or condition == "":
			continue

		pokemon_data["condition"] = condition
		_apply_condition_fields(pokemon_data, condition)
		pokemon_data["fainted"] = false
		_remember_hp_snapshot_for_condition_event(switch_ident, pokemon_data, condition, index)

func _get_switch_event_ident(event: Dictionary) -> String:
	for key in ["toIdent", "target", "pokemon", "ident"]:
		var ident := str(event.get(key, ""))
		if _get_player_id_from_ident(ident) != "":
			return ident

	var player_id := str(event.get("playerId", ""))
	var species := str(event.get("species", event.get("to", event.get("pokemon", "")))).strip_edges()
	if player_id == "" or species == "":
		return ""

	return "%sa: %s" % [player_id, species]

func _get_condition_from_event(event: Dictionary) -> String:
	if _has_percentage_only_condition(event):
		return ""

	if event.has("hp") and event.has("maxHp"):
		var hp := int(event.get("hp", 0))
		var max_hp: int = max(int(event.get("maxHp", 1)), 1)
		if hp <= 0:
			return "0 fnt"

		return _format_hp_condition(hp, max_hp, str(event.get("condition", "")))

	var event_condition := str(event.get("condition", ""))
	if event_condition != "":
		return event_condition

	if str(event.get("type", "")) == "faint":
		return "0 fnt"

	return ""

func _format_hp_condition(hp: int, max_hp: int, fallback_condition: String) -> String:
	var suffix := _get_condition_status_suffix(fallback_condition)
	if suffix == "":
		return "%s/%s" % [hp, max_hp]

	return "%s/%s %s" % [hp, max_hp, suffix]

func _get_condition_status_suffix(condition: String) -> String:
	var parts: PackedStringArray = condition.split(" ", false)
	for part_value: String in parts:
		var part := part_value.strip_edges().to_lower()
		match part:
			"psn", "tox", "brn", "par", "slp", "frz":
				return part

	return ""

func _has_percentage_only_condition(event: Dictionary) -> bool:
	if event.has("hp"):
		return false

	return hp_event_helper.is_percentage_only_condition_event(event, false)

func _set_pokemon_condition(target_ident: String, condition: String, source_event: Dictionary = {}) -> void:
	var player_id := _get_player_id_from_ident(target_ident)
	if player_id == "":
		print("[pvp-damage-debug] state.condition skipped: no player id target=%s condition=%s event=%s" % [
			target_ident,
			condition,
			JSON.stringify(source_event),
		])
		return

	var team := get_player_team(player_id)
	var target_index := _find_party_target_index(team, target_ident, source_event, true)
	if target_index < 0 or target_index >= team.size():
		print("[pvp-damage-debug] state.condition skipped: no target index player=%s target=%s condition=%s eventKey=%s eventSlot=%s team=%s event=%s" % [
			player_id,
			target_ident,
			condition,
			_get_event_pokemon_key(source_event),
			str(_get_event_metadata_slot(source_event)),
			JSON.stringify(_debug_team_identity_snapshot(team)),
			JSON.stringify(source_event),
		])
		return

	var pokemon_value: Variant = team[target_index]
	if not (pokemon_value is Dictionary):
		print("[pvp-damage-debug] state.condition skipped: target is not dictionary player=%s target=%s index=%d event=%s" % [
			player_id,
			target_ident,
			target_index,
			JSON.stringify(source_event),
		])
		return

	var pokemon_data: Dictionary = pokemon_value as Dictionary
	print("[pvp-damage-debug] state.condition apply before player=%s target=%s index=%d key=%s slot=%s previous=%s next=%s event=%s" % [
		player_id,
		target_ident,
		target_index,
		str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))),
		str(pokemon_data.get("partySlot", pokemon_data.get("metadataSlot", ""))),
		str(pokemon_data.get("condition", "")),
		condition,
		JSON.stringify(source_event),
	])
	pokemon_data["condition"] = condition
	_apply_condition_fields(pokemon_data, condition)
	_remember_hp_snapshot_for_condition_event(target_ident, pokemon_data, condition, target_index)
	print("[pvp-damage-debug] state.condition apply after player=%s index=%d pokemon=%s" % [
		player_id,
		target_index,
		JSON.stringify(pokemon_data),
	])

func _remember_hp_snapshot_for_condition_event(target_ident: String, pokemon_data: Dictionary, condition: String, team_index := -1) -> void:
	var snapshot: Dictionary = hp_event_helper.parse_condition_hp_snapshot(condition)
	if snapshot.is_empty():
		return

	var snapshot_key := _get_party_hp_snapshot_key(pokemon_data, team_index, target_ident)
	if snapshot_key == "":
		return

	var hp := int(snapshot.get("hp", 0))
	var max_hp := int(snapshot.get("max_hp", 0))
	if condition.contains("fnt"):
		var previous_snapshot_value: Variant = hp_snapshot_by_ident.get(snapshot_key, hp_snapshot_by_ident.get(target_ident, {}))
		var previous_snapshot: Dictionary = previous_snapshot_value as Dictionary if previous_snapshot_value is Dictionary else {}
		var previous_max_hp := int(previous_snapshot.get("max_hp", int(pokemon_data.get("maxHp", max_hp))))
		if previous_max_hp > 0:
			max_hp = previous_max_hp
	elif max_hp == 100:
		var previous_memory_value: Variant = hp_snapshot_by_ident.get(snapshot_key, hp_snapshot_by_ident.get(target_ident, {}))
		var previous_memory: Dictionary = previous_memory_value as Dictionary if previous_memory_value is Dictionary else {}
		if int(previous_memory.get("max_hp", 0)) > 100:
			return

	if max_hp <= 0:
		return

	var remembered_condition := condition
	if condition.contains("fnt"):
		remembered_condition = "0 fnt"
	hp_snapshot_by_ident[snapshot_key] = {
		"hp": hp,
		"max_hp": max_hp,
		"condition": remembered_condition,
	}
	if target_ident != "" and target_ident != snapshot_key and _should_remember_collapsed_hp_snapshot_alias(target_ident):
		hp_snapshot_by_ident[target_ident] = hp_snapshot_by_ident[snapshot_key]

func _should_remember_collapsed_hp_snapshot_alias(target_ident: String) -> bool:
	var player_id := _get_player_id_from_ident(target_ident)
	var target_name := _get_pokemon_name_from_ident(target_ident)
	if player_id == "" or target_name == "":
		return true

	var team := get_player_team(player_id)
	var matches := 0
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if _get_pokemon_name_from_ident(str(pokemon.get("ident", ""))) != target_name:
			continue

		matches += 1
		if matches > 1:
			return false

	return true

func _apply_transform_event_to_requests(event: Dictionary) -> void:
	var target_ident := str(event.get("target", ""))
	var species := str(event.get("species", ""))
	if target_ident == "" or species == "":
		return

	var transform_key := _get_transform_key_from_ident(target_ident)
	if transform_key != "":
		transformed_species_by_ident[transform_key] = species

	var pokemon_data: Dictionary = _get_side_pokemon_by_ident(target_ident)
	if pokemon_data.is_empty():
		return

	pokemon_data["displaySpecies"] = species
	pokemon_data["transformedSpecies"] = species

func _apply_mega_event_to_requests(event: Dictionary) -> void:
	var target_ident := str(event.get("target", ""))
	if target_ident == "":
		return

	var pokemon_data: Dictionary = _get_side_pokemon_by_ident(target_ident)
	if pokemon_data.is_empty():
		pokemon_data = _get_active_side_pokemon(_get_player_id_from_ident(target_ident))
	if pokemon_data.is_empty():
		return

	var species := resolve_mega_species_for_event(event)
	if species == "":
		species = _get_mega_species_for_pokemon_data(pokemon_data)
	if species == "":
		return

	var mega_key := _get_transform_key_from_ident(target_ident)
	if mega_key != "":
		mega_species_by_ident[mega_key] = species

	pokemon_data["displaySpecies"] = species
	pokemon_data["megaSpecies"] = species

func _get_mega_species_for_pokemon_data(pokemon_data: Dictionary) -> String:
	var base_species := _strip_mega_suffix(get_species_from_pokemon_data(pokemon_data))
	return _get_mega_species_for_base_and_item(base_species, str(pokemon_data.get("item", "")))

func _get_mega_species_for_base_and_item(base_species: String, item: String) -> String:
	var cleaned_base_species := _strip_mega_suffix(base_species)
	if cleaned_base_species == "":
		return ""

	var item_key := item.to_lower().replace(" ", "").replace("-", "").replace("_", "")
	if item_key == "":
		return ""

	if item_key == "charizarditex":
		return "Charizard-Mega-X"
	if item_key == "charizarditey":
		return "Charizard-Mega-Y"
	if item_key == "mewtwonitex":
		return "Mewtwo-Mega-X"
	if item_key == "mewtwonitey":
		return "Mewtwo-Mega-Y"
	if item_key.ends_with("ite"):
		return "%s-Mega" % cleaned_base_species

	return ""

func _is_mega_species(species: String) -> bool:
	return species.to_lower().contains("mega")

func _get_active_mega_species_from_request_slot(player_id: String, active_index := 0) -> String:
	var active_slots: Array = get_player_request(player_id).get("active", [])
	if active_index < 0 or active_index >= active_slots.size():
		return ""

	var active_data: Variant = active_slots[active_index]
	if not (active_data is Dictionary):
		return ""

	var can_mega_value: Variant = (active_data as Dictionary).get("canMegaEvo", "")
	var active_pokemon := get_active_player_pokemon(player_id)
	var active_species := _strip_mega_suffix(get_species_from_pokemon_data(active_pokemon)).to_lower().strip_edges()
	var mega_species := _get_mega_species_for_pokemon_data(active_pokemon)
	var can_mega_species := str(can_mega_value).strip_edges()

	if can_mega_value is bool:
		if can_mega_value:
			return mega_species
		return ""

	if can_mega_value is int:
		return mega_species if can_mega_value != 0 else ""

	if can_mega_value is float:
		return mega_species if not is_equal_approx(can_mega_value, 0.0) else ""

	var normalized_can_mega := can_mega_species.to_lower()
	if normalized_can_mega in ["false", "0", "off", "no"]:
		return ""

	if normalized_can_mega in ["true", "1", "on", "yes"]:
		return mega_species

	if normalized_can_mega == "":
		return ""

	if _is_mega_species(can_mega_species):
		var canonical_can_mega := _strip_mega_suffix(can_mega_species).to_lower().strip_edges()
		if active_species == "" or canonical_can_mega == active_species:
			return can_mega_species
		return ""

	if mega_species != "":
		return mega_species

	return ""

func _remove_deferred_display_fields_from_requests(events_value: Variant) -> void:
	if not (events_value is Array):
		return

	for event_value in events_value:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type := str(event.get("type", ""))
		match event_type:
			"transform":
				_remove_deferred_transform_fields_from_requests(event)
			"mega":
				_remove_deferred_mega_fields_from_requests(event)

func _remove_deferred_transform_fields_from_requests(event: Dictionary) -> void:
	var target_ident := str(event.get("target", ""))
	var original_species := _get_original_species_from_ident(target_ident)
	var pokemon_data := _get_side_pokemon_by_ident(target_ident)
	if pokemon_data.is_empty():
		return

	pokemon_data.erase("transformedSpecies")
	pokemon_data.erase("displaySpecies")
	if original_species != "":
		pokemon_data["species"] = original_species

func _remove_deferred_mega_fields_from_requests(event: Dictionary) -> void:
	var target_ident := str(event.get("target", ""))
	var original_species := _get_original_species_from_ident(target_ident)
	var pokemon_data := _get_side_pokemon_by_ident(target_ident)
	if pokemon_data.is_empty():
		pokemon_data = _get_active_side_pokemon(_get_player_id_from_ident(target_ident))
	if pokemon_data.is_empty():
		return
	if original_species != "":
		original_species = _strip_mega_suffix(original_species)
	if original_species == "":
		original_species = _strip_mega_suffix(str(pokemon_data.get("species", pokemon_data.get("displaySpecies", ""))))

	pokemon_data.erase("megaSpecies")
	pokemon_data.erase("displaySpecies")
	if original_species != "":
		pokemon_data["species"] = original_species

func _clear_transform_event_from_requests(event: Dictionary) -> void:
	_clear_transformed_species_for_ident(str(event.get("fromIdent", "")))
	_clear_transformed_species_for_ident(str(event.get("toIdent", event.get("pokemon", ""))))

func _clear_transformed_species_for_ident(ident: String) -> void:
	var transform_key := _get_transform_key_from_ident(ident)
	if transform_key == "":
		return

	var transformed_species := str(transformed_species_by_ident.get(transform_key, ""))
	var pokemon_data := _get_side_pokemon_by_transform_key(transform_key)
	if not pokemon_data.is_empty():
		pokemon_data.erase("transformedSpecies")
		if transformed_species != "" and str(pokemon_data.get("displaySpecies", "")) == transformed_species:
			pokemon_data.erase("displaySpecies")

	transformed_species_by_ident.erase(transform_key)

func _apply_transformed_species_to_requests() -> void:
	for transform_key in transformed_species_by_ident.keys():
		var species := str(transformed_species_by_ident.get(transform_key, ""))
		if species == "":
			continue

		var pokemon_data := _get_side_pokemon_by_transform_key(str(transform_key))
		if pokemon_data.is_empty():
			continue

		pokemon_data["displaySpecies"] = species
		pokemon_data["transformedSpecies"] = species

func _apply_mega_species_to_requests() -> void:
	for mega_key in mega_species_by_ident.keys():
		var species := str(mega_species_by_ident.get(mega_key, ""))
		if species == "":
			continue

		var pokemon_data := _get_side_pokemon_by_transform_key(str(mega_key))
		if pokemon_data.is_empty():
			continue

		pokemon_data["displaySpecies"] = species
		pokemon_data["megaSpecies"] = species

func _get_side_pokemon_by_ident(target_ident: String) -> Dictionary:
	var player_id := _get_player_id_from_ident(target_ident)
	if player_id == "":
		return {}

	var team := get_player_team(player_id)
	var target_index := _find_party_target_index(team, target_ident, {}, true)
	if target_index < 0 or target_index >= team.size():
		return {}

	var pokemon_value: Variant = team[target_index]
	if not (pokemon_value is Dictionary):
		return {}

	return pokemon_value as Dictionary


func _find_party_target_index(team: Array, target_ident: String, source_event: Dictionary = {}, prefer_active := false) -> int:
	var event_pokemon_key := _get_event_pokemon_key(source_event)
	if event_pokemon_key != "":
		var pokemon_key_index := _find_unique_team_index_by_pokemon_key(team, event_pokemon_key)
		if pokemon_key_index >= 0:
			return pokemon_key_index
		return -1

	var event_slot := _get_event_metadata_slot(source_event)
	if event_slot > 0:
		var slot_index := _find_unique_team_index_by_metadata_slot(team, event_slot)
		if slot_index >= 0:
			return slot_index
		return -1

	var normalized_ident := _normalize_battle_ident(target_ident)
	if normalized_ident != "":
		var ident_index := _find_unique_team_index_by_ident(team, normalized_ident)
		if ident_index >= 0:
			return ident_index

	if prefer_active:
		var active_index := _find_unique_active_team_index(team, target_ident)
		if active_index >= 0:
			return active_index

	var target_name := _get_pokemon_name_from_ident(target_ident)
	if target_name == "":
		return -1

	var species_index := _find_unique_team_index_by_pokemon_name(team, target_name)
	return species_index if species_index >= 0 else -1


func _get_event_pokemon_key(event_data: Dictionary) -> String:
	for key in ["pokemonKey", "pokemon_key"]:
		var value := str(event_data.get(key, "")).strip_edges()
		if value != "":
			return value

	for ref_key in ["targetRef", "target_ref", "toRef", "to_ref"]:
		var ref_value: Variant = event_data.get(ref_key, {})
		if not (ref_value is Dictionary):
			continue

		var ref_key_value := _get_event_pokemon_key(ref_value as Dictionary)
		if ref_key_value != "":
			return ref_key_value

	return ""


func _get_event_metadata_slot(event_data: Dictionary) -> int:
	for key in ["metadataSlot", "metadata_slot", "partySlot", "party_slot", "slot", "position"]:
		if not event_data.has(key):
			continue

		var slot := _safe_int(event_data.get(key), -1)
		if slot > 0:
			return slot

	for ref_key in ["targetRef", "target_ref", "toRef", "to_ref"]:
		var ref_value: Variant = event_data.get(ref_key, {})
		if not (ref_value is Dictionary):
			continue

		var ref_slot := _get_event_metadata_slot(ref_value as Dictionary)
		if ref_slot > 0:
			return ref_slot

	return -1


func _find_unique_team_index_by_pokemon_key(team: Array, pokemon_key: String) -> int:
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		var current_key := str(pokemon.get("pokemonKey", pokemon.get("pokemon_key", ""))).strip_edges()
		if current_key == "" or current_key != pokemon_key:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func _find_unique_team_index_by_metadata_slot(team: Array, metadata_slot: int) -> int:
	var found_index := -1
	var any_explicit_slot := false
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		for key in ["metadataSlot", "metadata_slot", "partySlot", "party_slot", "slot", "position"]:
			if not pokemon.has(key):
				continue

			any_explicit_slot = true
			if _safe_int(pokemon.get(key), -1) != metadata_slot:
				continue

			if found_index >= 0:
				return -2

			found_index = index

	if found_index < 0 and not any_explicit_slot:
		var slot_index := metadata_slot - 1
		if slot_index >= 0 and slot_index < team.size():
			return slot_index

	return found_index


func _find_unique_team_index_by_ident(team: Array, normalized_ident: String) -> int:
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if _normalize_battle_ident(str(pokemon.get("ident", ""))) != normalized_ident:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func _find_unique_active_team_index(team: Array, target_ident: String) -> int:
	var target_name := _get_pokemon_name_from_ident(target_ident)
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if not bool(pokemon.get("active", false)):
			continue

		if target_name != "" and _get_pokemon_name_from_ident(str(pokemon.get("ident", ""))) != target_name:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func _find_unique_team_index_by_pokemon_name(team: Array, target_name: String) -> int:
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if _get_pokemon_name_from_ident(str(pokemon.get("ident", ""))) != target_name:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func _debug_team_identity_snapshot(team: Array) -> Array:
	var snapshot: Array = []
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		snapshot.append({
			"key": str(pokemon.get("pokemonKey", pokemon.get("pokemon_key", ""))),
			"slot": pokemon.get("partySlot", pokemon.get("metadataSlot", "")),
			"ident": str(pokemon.get("ident", "")),
			"active": bool(pokemon.get("active", false)),
			"condition": str(pokemon.get("condition", "")),
			"hp": pokemon.get("hp", ""),
			"maxHp": pokemon.get("maxHp", ""),
			"fainted": bool(pokemon.get("fainted", false)),
		})

	return snapshot


func _get_party_hp_snapshot_key(pokemon_data: Dictionary, team_index := -1, fallback_ident := "") -> String:
	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	if pokemon_key != "":
		return "pokemonKey:%s" % pokemon_key

	for key in ["metadataSlot", "metadata_slot", "partySlot", "party_slot", "slot", "position"]:
		if not pokemon_data.has(key):
			continue

		var slot := _safe_int(pokemon_data.get(key), -1)
		if slot >= 0:
			return "slot:%s" % slot

	for key in ["instanceId", "instance_id", "ownedPokemonId", "owned_pokemon_id", "pokemonId", "pokemon_id"]:
		var value := str(pokemon_data.get(key, "")).strip_edges()
		if value != "":
			return "%s:%s" % [key, value]

	if team_index >= 0:
		return "index:%s" % team_index

	var ident := _normalize_battle_ident(str(pokemon_data.get("ident", fallback_ident)))
	if ident != "":
		return "ident:%s" % ident

	return ""


func _normalize_battle_ident(ident: String) -> String:
	var cleaned := ident.strip_edges()
	if cleaned.contains(": "):
		var player_id := cleaned.split(": ")[0].substr(0, 2)
		var pokemon_name := cleaned.split(": ")[1]
		return "%s:%s" % [player_id, pokemon_name.to_lower()]

	return cleaned.to_lower()


func _safe_int(value: Variant, fallback := 0) -> int:
	if value == null:
		return fallback

	if value is int:
		return int(value)

	if value is float:
		return int(value)

	var text := str(value).strip_edges()
	if text == "":
		return fallback

	if not text.is_valid_int():
		return fallback

	return int(text)

func _get_side_pokemon_by_transform_key(transform_key: String) -> Dictionary:
	var normalized_transform_key := _normalize_transform_key(transform_key)
	if normalized_transform_key == "":
		return {}

	for player_id in ["p1", "p2"]:
		var request_value: Variant = requests.get(player_id, {})
		if not (request_value is Dictionary):
			continue

		var request: Dictionary = request_value as Dictionary
		var side_value: Variant = request.get("side", {})
		if not (side_value is Dictionary):
			continue

		var side: Dictionary = side_value as Dictionary
		var team_value: Variant = side.get("pokemon", [])
		if not (team_value is Array):
			continue

		var team: Array = team_value as Array
		for pokemon_value in team:
			if not (pokemon_value is Dictionary):
				continue

			var pokemon_data: Dictionary = pokemon_value as Dictionary
			if _get_transform_key_from_ident(str(pokemon_data.get("ident", ""))) == normalized_transform_key:
				return pokemon_data

	return {}

func _get_active_side_pokemon(player_id: String) -> Dictionary:
	if player_id == "":
		return {}

	var request_value: Variant = requests.get(player_id, {})
	if not (request_value is Dictionary):
		return {}

	var request: Dictionary = request_value as Dictionary
	var side_value: Variant = request.get("side", {})
	if not (side_value is Dictionary):
		return {}

	var side: Dictionary = side_value as Dictionary
	var team_value: Variant = side.get("pokemon", [])
	if not (team_value is Array):
		return {}

	var team: Array = team_value as Array
	for pokemon_value in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if bool(pokemon_data.get("active", false)):
			return pokemon_data

	return {}

func _get_transform_key_from_ident(ident: String) -> String:
	var player_id := _get_player_id_from_ident(ident)
	var pokemon_name := _get_base_pokemon_name_from_ident(ident)
	if player_id == "" or pokemon_name == "":
		return ""

	return "%s:%s" % [player_id, pokemon_name]

func _normalize_transform_key(transform_key: String) -> String:
	var parts := transform_key.split(":", false, 1)
	if parts.size() != 2:
		return ""

	var player_id := str(parts[0]).strip_edges()
	var pokemon_name := _normalize_transform_key_pokemon_name(str(parts[1]))
	if player_id == "" or pokemon_name == "":
		return ""

	return "%s:%s" % [player_id, pokemon_name]

func _get_original_species_from_ident(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges()

func _strip_mega_suffix(species: String) -> String:
	var cleaned := species.strip_edges()
	var mega_suffixes: Array[String] = ["-Mega-X", "-Mega-Y", "-Mega"]
	for suffix: String in mega_suffixes:
		if cleaned.ends_with(suffix):
			return cleaned.substr(0, cleaned.length() - suffix.length())

	return cleaned

func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""

func _get_pokemon_name_from_ident(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges().to_lower()

func _get_base_pokemon_name_from_ident(ident: String) -> String:
	return _normalize_transform_key_pokemon_name(_get_pokemon_name_from_ident(ident))

func _normalize_transform_key_pokemon_name(pokemon_name: String) -> String:
	var normalized := pokemon_name.strip_edges().to_lower()
	normalized = normalized.replace("-mega-x", "")
	normalized = normalized.replace("-mega-y", "")
	normalized = normalized.replace("-mega", "")
	return normalized

## Geeft alle Pokemon op de side van een speler terug.
func get_player_team(player_id: String = "p1") -> Array:
	return get_player_side(player_id).get("pokemon", [])

## Geeft de actieve Pokemon op de side van een speler terug.
func get_active_player_pokemon(player_id: String = "p1") -> Dictionary:
	for pokemon in get_player_team(player_id):
		if pokemon.get("active", false):
			return pokemon

	return {}

## Geeft de beschikbare moves voor een actieve Pokemon terug.
func get_available_moves(player_id: String = "p1", active_index=0) -> Array:
	var active_moves_slots: Array = get_player_request(player_id).get("active", [])

	if active_index >= active_moves_slots.size() or active_index < 0:
		return []

	return active_moves_slots[active_index].get("moves", [])

func can_active_pokemon_mega_evolve(player_id: String = "p1", active_index := 0) -> bool:
	var active_slots: Array = get_player_request(player_id).get("active", [])
	if active_index < 0 or active_index >= active_slots.size():
		return false

	var active_data: Variant = active_slots[active_index]
	if not (active_data is Dictionary):
		return false

	return _get_active_mega_species_from_request_slot(player_id, active_index) != ""

## Geeft terug of de speler nog in team preview zit.
func is_team_preview(player_id: String = "p1") -> bool:
	var request = get_player_request(player_id)
	return request.get("teamPreview", false)

## Geeft terug of de battle afgelopen is.
func is_battle_ended() -> bool:
	return bool(battle_status_api.get("ended", false))

## Geeft de winnaar terug als de battle afgelopen is.
func get_winner() -> String:
	return str(battle_status_api.get("winner", ""))

## Geeft de ident-string van de actieve Pokemon terug.
func get_active_pokemon_ident(player_id: String = "p1") -> String:
	return str(get_active_player_pokemon(player_id).get("ident", ""))

func get_active_pokemon_status(player_id: String = "p1") -> String:
	var pokemon_data := get_active_player_pokemon(player_id)
	return str(pokemon_data.get("status", ""))

func get_active_pokemon_gender(player_id: String = "p1") -> String:
	var pokemon_data := get_active_player_pokemon(player_id)
	return str(pokemon_data.get("gender", ""))

## Geeft de speciesnaam van de actieve Pokemon terug.
func get_active_pokemon_species(player_id: String = "p1") -> String:
	return get_species_from_pokemon_data(get_active_player_pokemon(player_id))

func get_species_from_pokemon_data(pokemon_data: Dictionary) -> String:
	var display_species := str(pokemon_data.get("displaySpecies", ""))
	if display_species != "":
		return display_species

	var species := str(pokemon_data.get("species", ""))
	if species != "":
		return species

	var ident := str(pokemon_data.get("ident", ""))
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()

	return ""

## Geeft het level van de actieve pokemon terug.
func get_active_pokemon_level(player_id: String) -> int:
	var pokemon_data := get_active_player_pokemon(player_id)
	if pokemon_data.has("level"):
		return int(pokemon_data.get("level", 100))

	return 100

## Geeft de huidige HP van de actieve Pokemon terug.
func get_active_pokemon_current_hp(player_id: String) -> int:
	var pokemon_data := get_active_player_pokemon(player_id)
	if pokemon_data.has("hp"):
		return int(pokemon_data.get("hp", 0))

	return 0

## Geef de huidige HP van de pokemon terug.
func get_active_pokemon_max_hp(player_id: String) -> int:
	var pokemon_data := get_active_player_pokemon(player_id)
	if pokemon_data.has("maxHp"):
		return int(pokemon_data.get("maxHp", 0))

	return 0

func is_active_pokemon_fainted(player_id: String = "p1") -> bool:
	var pokemon_data := get_active_player_pokemon(player_id)
	if bool(pokemon_data.get("fainted", false)):
		return true

	var condition := str(pokemon_data.get("condition", "")).strip_edges().to_lower()
	if condition == "0 fnt" or condition.ends_with(" fnt"):
		return true

	return int(pokemon_data.get("hp", 1)) <= 0 and int(pokemon_data.get("maxHp", 0)) > 0

func _apply_condition_fields(pokemon_data: Dictionary, condition: String) -> void:
	hp_event_helper.apply_condition_fields(pokemon_data, condition)

## Geeft huidige turn terug
func get_turn() -> int:
	return int(battle_status_api.get("turn", 0))

func get_field_effects() -> Array:
	var effects: Variant = field.get("effects", [])
	if effects is Array:
		return effects as Array

	return []

func is_active_trapped(player_id: String = "p1", active_index: int = 0) -> bool:
	var active_slots: Array = get_player_request(player_id).get("active", [])

	if active_index < 0 or active_index >= active_slots.size():
		return false

	var active_data: Dictionary = active_slots[active_index]
	return bool(active_data.get("trapped", false))

func is_active_maybe_trapped(player_id: String = "p1", active_index: int = 0) -> bool:
	var active_slots: Array = get_player_request(player_id).get("active", [])

	if active_index < 0 or active_index >= active_slots.size():
		return false

	var active_data: Dictionary = active_slots[active_index]
	return bool(active_data.get("maybeTrapped", false))

func needs_force_switch(player_id: String = "p1", active_index: int = 0) -> bool:
	var force_switch: Array = get_player_request(player_id).get("forceSwitch", [])

	if active_index < 0 or active_index >= force_switch.size():
		return false

	return bool(force_switch[active_index])
