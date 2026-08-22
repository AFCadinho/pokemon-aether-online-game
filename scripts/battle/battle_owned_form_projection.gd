extends RefCounted

class_name BattleOwnedFormProjection

const STAT_KEYS := ["hp", "atk", "def", "spa", "spd", "spe"]


static func merge_stats(fallback_value: Variant, live_value: Variant) -> Dictionary:
	var merged: Dictionary = {}
	_apply_positive_stats(merged, fallback_value)
	_apply_positive_stats(merged, live_value)
	return merged


static func apply_live_form_to_hover(
	hover_data: Dictionary,
	display_data: Dictionary,
	temporary_species: String
) -> void:
	if temporary_species.strip_edges() == "":
		return

	hover_data["species"] = temporary_species
	hover_data["displaySpecies"] = temporary_species

	var live_stats := merge_stats(hover_data.get("stats", {}), display_data.get("stats", {}))
	if not live_stats.is_empty():
		hover_data["stats"] = live_stats

	var live_ability := str(display_data.get(
		"ability",
		display_data.get("baseAbility", display_data.get("base_ability", ""))
	)).strip_edges()
	if live_ability != "":
		hover_data["ability"] = live_ability
		hover_data["possibleAbilities"] = [live_ability]

	var live_types_value: Variant = display_data.get("types", [])
	if live_types_value is Array and not (live_types_value as Array).is_empty():
		hover_data["types"] = (live_types_value as Array).duplicate(true)


static func apply_live_request_to_display(display_data: Dictionary, live_data: Dictionary) -> void:
	if live_data.is_empty():
		return

	for key: String in [
		"stats",
		"ability",
		"baseAbility",
		"base_ability",
		"megaSpecies",
		"transformedSpecies",
		"displaySpecies",
		"types",
	]:
		if live_data.has(key):
			display_data[key] = _duplicate_variant(live_data.get(key))


static func find_request_pokemon(
	response: Dictionary,
	player_id: String,
	canonical_slot: int
) -> Dictionary:
	if canonical_slot <= 0:
		return {}

	var requests_value: Variant = response.get("requests", {})
	if not (requests_value is Dictionary):
		return {}
	var request_value: Variant = (requests_value as Dictionary).get(player_id, {})
	if not (request_value is Dictionary):
		return {}
	var side_value: Variant = (request_value as Dictionary).get("side", {})
	if not (side_value is Dictionary):
		return {}
	var team_value: Variant = (side_value as Dictionary).get("pokemon", [])
	if not (team_value is Array):
		return {}

	var team := team_value as Array
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			continue
		var pokemon_data := pokemon_value as Dictionary
		for key: String in [
			"canonicalPartySlot",
			"canonical_party_slot",
			"partySlot",
			"party_slot",
			"metadataSlot",
			"metadata_slot",
			"slot",
		]:
			if pokemon_data.has(key) and int(pokemon_data.get(key, 0)) == canonical_slot:
				return pokemon_data.duplicate(true)

	var fallback_index := canonical_slot - 1
	if fallback_index >= 0 and fallback_index < team.size():
		var fallback_value: Variant = team[fallback_index]
		if fallback_value is Dictionary:
			return (fallback_value as Dictionary).duplicate(true)
	return {}


static func has_positive_stats(value: Variant) -> bool:
	var normalized: Dictionary = {}
	_apply_positive_stats(normalized, value)
	return not normalized.is_empty()


static func _apply_positive_stats(target: Dictionary, value: Variant) -> void:
	if not (value is Dictionary):
		return

	var source := value as Dictionary
	for stat_key: String in STAT_KEYS:
		if not source.has(stat_key):
			continue
		var stat_value := int(source.get(stat_key, 0))
		if stat_value > 0:
			target[stat_key] = stat_value


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
