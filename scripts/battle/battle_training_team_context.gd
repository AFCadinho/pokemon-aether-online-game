extends RefCounted

class_name BattleTrainingTeamContext

const BATTLE_STATE_FIELDS := [
	"ident",
	"details",
	"species",
	"displaySpecies",
	"nickname",
	"name",
	"condition",
	"hp",
	"currentHp",
	"maxHp",
	"max_hp",
	"status",
	"fainted",
	"active",
	"activeIdent",
	"playerId",
	"level",
	"gender",
	"shiny",
	"isShiny",
	"is_shiny",
	"ability",
	"item",
	"megaSpecies",
	"transformedSpecies",
]


static func build_canonical_roster(private_team_value: Variant, player_id := "p1") -> Array:
	if not (private_team_value is Array):
		return []

	var private_team: Array = private_team_value as Array
	var roster: Array = []
	for index in range(private_team.size()):
		var pokemon_value: Variant = private_team[index]
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = (pokemon_value as Dictionary).duplicate(true)
		var canonical_slot := get_canonical_slot(pokemon_data)
		if canonical_slot <= 0:
			canonical_slot = index + 1
		apply_canonical_identity(pokemon_data, canonical_slot, player_id)
		roster.append(pokemon_data)

	return sort_by_canonical_slot(roster)


static func build_display_team(canonical_roster: Array, request_team_value: Variant, player_id := "p1") -> Array:
	var request_team: Array = request_team_value as Array if request_team_value is Array else []
	var display_team: Array = []
	for index in range(canonical_roster.size()):
		var roster_value: Variant = canonical_roster[index]
		if not (roster_value is Dictionary):
			continue

		var display_data: Dictionary = (roster_value as Dictionary).duplicate(true)
		var canonical_slot := get_canonical_slot(display_data)
		if canonical_slot <= 0:
			canonical_slot = index + 1
		var request_data := _find_request_pokemon(request_team, display_data, canonical_slot)
		for field_name: String in BATTLE_STATE_FIELDS:
			if request_data.has(field_name):
				display_data[field_name] = request_data.get(field_name)
		apply_canonical_identity(display_data, canonical_slot, player_id)
		display_team.append(display_data)

	return sort_by_canonical_slot(display_team)


static func apply_canonical_identity(pokemon_data: Dictionary, canonical_slot: int, player_id := "p1") -> void:
	pokemon_data["canonicalPartySlot"] = canonical_slot
	pokemon_data["partySlot"] = canonical_slot
	pokemon_data["metadataSlot"] = canonical_slot
	pokemon_data["pokemonKey"] = "%s:slot:%d" % [player_id, canonical_slot]


static func get_canonical_slot(pokemon_data: Dictionary) -> int:
	for key in [
		"canonicalPartySlot",
		"canonical_party_slot",
		"partySlot",
		"party_slot",
		"metadataSlot",
		"metadata_slot",
	]:
		var slot := _positive_int(pokemon_data.get(key, null))
		if slot > 0:
			return slot

	var pokemon_key := str(pokemon_data.get("pokemonKey", pokemon_data.get("pokemon_key", ""))).strip_edges()
	if pokemon_key.contains(":slot:"):
		return _positive_int(pokemon_key.rsplit(":slot:", true, 1)[1])

	return -1


static func sort_by_canonical_slot(team: Array) -> Array:
	if team.size() <= 1:
		return team

	var by_slot: Dictionary = {}
	for pokemon_value: Variant in team:
		if not (pokemon_value is Dictionary):
			return team
		var pokemon_data: Dictionary = pokemon_value as Dictionary
		var canonical_slot := get_canonical_slot(pokemon_data)
		if canonical_slot <= 0 or by_slot.has(canonical_slot):
			return team
		by_slot[canonical_slot] = pokemon_data

	var slots: Array = by_slot.keys()
	slots.sort()
	var sorted_team: Array = []
	for slot_value: Variant in slots:
		sorted_team.append(by_slot[slot_value])
	return sorted_team


static func _find_request_pokemon(
	request_team: Array,
	roster_pokemon: Dictionary,
	canonical_slot: int
) -> Dictionary:
	var same_index_candidate: Dictionary = {}
	var unique_species_candidate: Dictionary = {}
	var species_match_count := 0
	var roster_species := _species_key(roster_pokemon)

	for index in range(request_team.size()):
		var request_value: Variant = request_team[index]
		if not (request_value is Dictionary):
			continue
		var request_data: Dictionary = request_value as Dictionary
		var request_slot := get_canonical_slot(request_data)
		if request_slot == canonical_slot:
			return request_data
		if index + 1 == canonical_slot:
			same_index_candidate = request_data
		if roster_species != "" and _species_key(request_data) == roster_species:
			species_match_count += 1
			unique_species_candidate = request_data

	if not same_index_candidate.is_empty() and _pokemon_species_are_compatible(roster_pokemon, same_index_candidate):
		return same_index_candidate
	if species_match_count == 1:
		return unique_species_candidate
	return {}


static func _pokemon_species_are_compatible(first: Dictionary, second: Dictionary) -> bool:
	var first_species := _species_key(first)
	var second_species := _species_key(second)
	return first_species == "" or second_species == "" or first_species == second_species


static func _species_key(pokemon_data: Dictionary) -> String:
	var species := str(pokemon_data.get("displaySpecies", pokemon_data.get("species", ""))).strip_edges()
	if species == "":
		species = str(pokemon_data.get("details", "")).split(",", false, 1)[0].strip_edges()
	return species.to_lower().replace(" ", "-").replace("_", "-")


static func _positive_int(value: Variant) -> int:
	if value == null or value is bool:
		return -1
	if value is int:
		return int(value) if int(value) > 0 else -1
	if value is float:
		var float_value := float(value)
		return int(float_value) if float_value > 0.0 and float_value == floor(float_value) else -1
	var text := str(value).strip_edges()
	return int(text) if text.is_valid_int() and int(text) > 0 else -1
