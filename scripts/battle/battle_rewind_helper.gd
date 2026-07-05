extends RefCounted

class_name BattleRewindHelper

var hp_event_helper := BattleHpEventHelper.new()

func get_rewound_team_data_for_events(player_id: String, team: Array, events: Array) -> Array:
	var previous_snapshots_by_index: Dictionary = get_previous_snapshots_by_party_index_for_events(player_id, team, events)
	if previous_snapshots_by_index.is_empty():
		return team

	var rewound_team: Array = []
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			rewound_team.append(pokemon_value)
			continue

		var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate()
		if previous_snapshots_by_index.has(index):
			_apply_previous_snapshot(pokemon_data, previous_snapshots_by_index.get(index, {}))

		rewound_team.append(pokemon_data)

	return rewound_team


func get_previous_conditions_by_party_index_for_events(player_id: String, team: Array, events: Array) -> Dictionary:
	var previous_conditions_by_index: Dictionary = {}
	var previous_snapshots_by_index := get_previous_snapshots_by_party_index_for_events(player_id, team, events)
	for index_value: Variant in previous_snapshots_by_index.keys():
		var snapshot_value: Variant = previous_snapshots_by_index.get(index_value, {})
		if not (snapshot_value is Dictionary):
			continue

		var condition := str((snapshot_value as Dictionary).get("condition", ""))
		if condition != "":
			previous_conditions_by_index[index_value] = condition

	return previous_conditions_by_index


func get_previous_snapshots_by_party_index_for_events(player_id: String, team: Array, events: Array) -> Dictionary:
	var previous_snapshots_by_index: Dictionary = {}
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

		var previous_snapshot := _get_previous_snapshot_from_event(event)
		if previous_snapshot.is_empty():
			continue

		var target_index := _find_party_target_index(team, target_ident, event, true)
		if target_index < 0 or previous_snapshots_by_index.has(target_index):
			continue

		previous_snapshots_by_index[target_index] = previous_snapshot

	return previous_snapshots_by_index


func _get_previous_snapshot_from_event(event: Dictionary) -> Dictionary:
	var previous_condition := str(event.get("previousCondition", ""))
	if previous_condition != "":
		return {"condition": previous_condition}

	if not event.has("previousHp"):
		return {}

	var previous_hp := int(event.get("previousHp", 0))
	var max_hp := int(event.get("maxHp", 0))
	if max_hp <= 0:
		return {}

	return {
		"condition": "0 fnt" if previous_hp <= 0 else "%s/%s" % [previous_hp, max_hp],
		"hp": previous_hp,
		"maxHp": max_hp,
		"currentHp": previous_hp,
		"fainted": previous_hp <= 0,
	}


func _apply_previous_snapshot(pokemon_data: Dictionary, snapshot: Variant) -> void:
	if not (snapshot is Dictionary):
		return

	var snapshot_data: Dictionary = snapshot as Dictionary
	var previous_condition := str(snapshot_data.get("condition", ""))
	if previous_condition != "":
		pokemon_data["condition"] = previous_condition
		hp_event_helper.apply_condition_fields(pokemon_data, previous_condition)

	if snapshot_data.has("hp"):
		pokemon_data["hp"] = int(snapshot_data.get("hp", 0))
	if snapshot_data.has("maxHp"):
		pokemon_data["maxHp"] = int(snapshot_data.get("maxHp", 1))
	if snapshot_data.has("currentHp"):
		pokemon_data["currentHp"] = int(snapshot_data.get("currentHp", 0))
	if snapshot_data.has("fainted"):
		pokemon_data["fainted"] = bool(snapshot_data.get("fainted", false))


func _find_party_target_index(team: Array, target_ident: String, source_event: Dictionary = {}, prefer_active := false) -> int:
	var event_pokemon_key := _get_event_pokemon_key(source_event)
	if event_pokemon_key != "":
		var pokemon_key_index := _find_unique_team_index_by_pokemon_key(team, event_pokemon_key)
		if pokemon_key_index >= 0:
			return pokemon_key_index
		if _team_has_any_pokemon_key(team):
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

	var target_name := get_ident_pokemon_name(target_ident)
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
		if not event_data.has(ref_key):
			continue

		var ref_value: Variant = event_data.get(ref_key)
		if not (ref_value is Dictionary):
			continue
		if (ref_value as Dictionary).is_empty():
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
		if not event_data.has(ref_key):
			continue

		var ref_value: Variant = event_data.get(ref_key)
		if not (ref_value is Dictionary):
			continue
		if (ref_value as Dictionary).is_empty():
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


func _team_has_any_pokemon_key(team: Array) -> bool:
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			continue

		var pokemon: Dictionary = pokemon_value as Dictionary
		var current_key := str(pokemon.get("pokemonKey", pokemon.get("pokemon_key", ""))).strip_edges()
		if current_key != "":
			return true

	return false


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
