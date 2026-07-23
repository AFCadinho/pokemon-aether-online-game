extends SceneTree

const Resolver := preload("res://scripts/battle/battle_party_slot_resolver.gd")

var failed := false


func _init() -> void:
	_check_wrong_metadata_is_repaired_by_species()
	_check_wrong_enriched_instance_does_not_override_species()
	_check_empty_species_uses_details()
	_check_duplicate_species_requires_stable_identity()
	_check_valid_declared_slot_is_preserved()
	quit(1 if failed else 0)


func _canonical_roster() -> Array:
	return [
		{"species": "Iron Valiant", "instanceId": "iron-valiant", "ownedPokemonId": 101, "canonicalPartySlot": 1},
		{"species": "Ogerpon-Wellspring", "instanceId": "ogerpon", "ownedPokemonId": 102, "canonicalPartySlot": 2},
		{"species": "Archaludon", "instanceId": "archaludon", "ownedPokemonId": 103, "canonicalPartySlot": 3},
		{"species": "Gardevoir", "instanceId": "gardevoir", "ownedPokemonId": 104, "canonicalPartySlot": 4},
	]


func _check_wrong_metadata_is_repaired_by_species() -> void:
	var selected := {
		"species": "Gardevoir",
		"partySlot": 2,
		"metadataSlot": 2,
		"pokemonKey": "p1:slot:2",
	}
	_check_equal(Resolver.resolve_selected_slot(selected, _canonical_roster()), 4, "Gardevoir resolves to its canonical roster slot")


func _check_wrong_enriched_instance_does_not_override_species() -> void:
	var selected := {
		"species": "Gardevoir",
		"displaySpecies": "Ogerpon-Wellspring",
		"instanceId": "ogerpon",
		"ownedPokemonId": 102,
		"partySlot": 2,
	}
	_check_equal(Resolver.resolve_selected_slot(selected, _canonical_roster()), 4, "a mismatched Ogerpon identity cannot hijack the Gardevoir selection")


func _check_empty_species_uses_details() -> void:
	var selected := {
		"species": "",
		"details": "Gardevoir, L100",
		"partySlot": 2,
	}
	_check_equal(Resolver.resolve_selected_slot(selected, _canonical_roster()), 4, "details resolve the canonical slot when species is empty")


func _check_duplicate_species_requires_stable_identity() -> void:
	var roster := [
		{"species": "Gardevoir", "instanceId": "first", "canonicalPartySlot": 1},
		{"species": "Gardevoir", "instanceId": "second", "canonicalPartySlot": 5},
	]
	_check_equal(Resolver.resolve_selected_slot({"species": "Gardevoir"}, roster), -1, "ambiguous species-only selection fails closed")
	_check_equal(Resolver.resolve_selected_slot({"species": "Gardevoir", "instanceId": "second"}, roster), 5, "stable instance identity resolves duplicate species")


func _check_valid_declared_slot_is_preserved() -> void:
	var selected := {
		"species": "Ogerpon",
		"instanceId": "ogerpon",
		"canonicalPartySlot": 2,
	}
	_check_equal(Resolver.resolve_selected_slot(selected, _canonical_roster()), 2, "compatible battle form keeps its canonical slot")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
