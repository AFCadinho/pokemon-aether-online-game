extends RefCounted

class_name OpponentPartyRevealPolicy

var team_preview_enabled := false
var revealed_slots: Dictionary = {}


func reset(show_full_team: bool = false) -> void:
	team_preview_enabled = show_full_team
	revealed_slots.clear()


func reveal_active(team: Array) -> void:
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			continue
		var pokemon_data := pokemon_value as Dictionary
		if bool(pokemon_data.get("active", false)):
			reveal_slot(_get_canonical_slot(pokemon_data, index + 1))


func reveal_slot(slot: int) -> void:
	if slot > 0:
		revealed_slots[slot] = true


func mask_team(team: Array) -> Array:
	if team_preview_enabled:
		return team.duplicate(true)

	var masked_team: Array = []
	for index in range(team.size()):
		var pokemon_value: Variant = team[index]
		if not (pokemon_value is Dictionary):
			masked_team.append(pokemon_value)
			continue

		var pokemon_data := pokemon_value as Dictionary
		var slot := _get_canonical_slot(pokemon_data, index + 1)
		if bool(revealed_slots.get(slot, false)):
			masked_team.append(pokemon_data.duplicate(true))
			continue

		masked_team.append({
			"unrevealed": true,
			"metadataSlot": slot,
			"partySlot": slot,
			"pokemonKey": "p2:slot:%d" % slot,
		})

	return masked_team


func _get_canonical_slot(pokemon_data: Dictionary, fallback_slot: int) -> int:
	for key in ["metadataSlot", "metadata_slot", "partySlot", "party_slot", "slot", "position"]:
		var slot := int(pokemon_data.get(key, 0))
		if slot > 0:
			return slot

	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", "")))
	var marker := ":slot:"
	var marker_index := pokemon_key.rfind(marker)
	if marker_index >= 0:
		var slot_text := pokemon_key.substr(marker_index + marker.length())
		if slot_text.is_valid_int() and int(slot_text) > 0:
			return int(slot_text)

	return fallback_slot
