extends RefCounted

class_name BattleRewindHelper

var hp_event_helper := BattleHpEventHelper.new()

func get_rewound_team_data_for_events(player_id: String, team: Array, events: Array) -> Array:
	var previous_conditions_by_index: Dictionary = get_previous_conditions_by_party_index_for_events(player_id, team, events)
	if previous_conditions_by_index.is_empty():
		return team

	var rewound_team: Array = []
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			rewound_team.append(pokemon_value)
			continue

		var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate()
		if previous_conditions_by_index.has(index):
			var previous_condition := str(previous_conditions_by_index.get(index, pokemon_data.get("condition", "")))
			pokemon_data["condition"] = previous_condition
			hp_event_helper.apply_condition_fields(pokemon_data, previous_condition)

		rewound_team.append(pokemon_data)

	return rewound_team


func get_previous_conditions_by_party_index_for_events(player_id: String, team: Array, events: Array) -> Dictionary:
	var previous_conditions_by_index: Dictionary = {}
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident: String = str(event.get("target", ""))
		if _get_player_id_from_ident(target_ident) != player_id:
			continue

		var previous_condition: String = str(event.get("previousCondition", ""))
		if previous_condition == "":
			continue

		var target_index := _find_party_target_index(team, target_ident, event, true)
		if target_index < 0 or previous_conditions_by_index.has(target_index):
			continue

		previous_conditions_by_index[target_index] = previous_condition

	return previous_conditions_by_index


func _find_party_target_index(team: Array, target_ident: String, source_event: Dictionary = {}, prefer_active := false) -> int:
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

	var target_name := get_ident_pokemon_name(target_ident)
	if target_name == "":
		return -1

	var species_index := _find_unique_team_index_by_pokemon_name(team, target_name)
	return species_index if species_index >= 0 else -1


func _get_event_metadata_slot(event_data: Dictionary) -> int:
	for key in ["metadataSlot", "metadata_slot", "partySlot", "party_slot", "slot", "position"]:
		if not event_data.has(key):
			continue

		var slot := _safe_int(event_data.get(key), -1)
		if slot > 0:
			return slot

	return -1


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
	var target_name := get_ident_pokemon_name(target_ident)
	var found_index := -1
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		if not bool(pokemon.get("active", false)):
			continue

		if target_name != "" and get_ident_pokemon_name(str(pokemon.get("ident", ""))) != target_name:
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
		if get_ident_pokemon_name(str(pokemon.get("ident", ""))) != target_name:
			continue

		if found_index >= 0:
			return -2

		found_index = index

	return found_index


func get_ident_pokemon_name(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges().to_lower()


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


func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""
