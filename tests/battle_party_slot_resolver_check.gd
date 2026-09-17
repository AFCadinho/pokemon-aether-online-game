extends SceneTree

const Resolver := preload("res://scripts/battle/battle_party_slot_resolver.gd")
const SwitchFlow := preload("res://scripts/battle/battle_force_switch_flow.gd")

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check_wrong_metadata_is_repaired_by_species()
	_check_wrong_enriched_instance_does_not_override_species()
	_check_empty_species_uses_details()
	_check_duplicate_species_requires_stable_identity()
	_check_valid_declared_slot_is_preserved()
	_check_mimikyu_battle_form_resolves_to_canonical_slot()
	_check_switch_eligibility_uses_current_pokemon_not_old_card()
	_check_controller_reads_the_newer_request()
	quit(1 if failed else 0)


func _check_controller_reads_the_newer_request() -> void:
	var controller: Variant = load("res://scripts/battle/battle.gd").new()
	controller.pvp_room_code = "fixture"
	controller.action_flow.set_local_player_id("p2")
	controller.pvp_local_canonical_roster = _canonical_roster()
	controller.force_switch_flow.setup(controller.battle_state)
	var old_card := {"species": "Gardevoir", "partySlot": 4, "condition": "100/100", "active": false}
	controller.battle_state.requests = {"p1": {"forceSwitch": [true], "side": {"pokemon": [old_card]}}}
	controller.pvp_response_order.latest_response = {"requests": {"p1": {"forceSwitch": [true], "side": {"pokemon": [
		{"species": "Gardevoir", "partySlot": 4, "condition": "0 fnt"},
		{"species": "Iron Valiant", "partySlot": 1, "condition": "75/100"},
	]}}}}
	_check_equal(controller._can_switch_to_selected_pokemon(1, old_card), false, "actual controller rejects stale healthy card using the normalized p2 participant request")
	_check_equal(controller._can_switch_to_selected_pokemon(2, {"species": "Iron Valiant", "partySlot": 1}), true, "actual controller allows a different living replacement immediately")
	var diagnostic: Dictionary = controller._pvp_switch_eligibility_diagnostic(2)
	_check_equal(diagnostic.get("eligibilityReason"), "candidate_missing", "missing request candidate has a safe diagnostic reason")
	_check_equal(diagnostic.get("requestTeamPresent"), true, "diagnostic distinguishes an absent candidate from an absent team")
	controller.free()


func _check_switch_eligibility_uses_current_pokemon_not_old_card() -> void:
	var roster := _canonical_roster()
	var old_card := {"species": "Gardevoir", "partySlot": 4, "condition": "100/100", "active": false}
	var request_team := [
		{"species": "Gardevoir", "partySlot": 4, "condition": "0 fnt", "fainted": true},
		{"species": "Iron Valiant", "partySlot": 1, "condition": "70/100", "active": false},
		{"species": "Archaludon", "partySlot": 3, "condition": "50/100", "active": true},
	]
	var slot := Resolver.resolve_selected_slot(old_card, roster)
	_check_equal(SwitchFlow.is_available_switch_candidate(old_card), true, "old rendered card alone would allow the fainted switch")
	_check_equal(SwitchFlow.is_available_switch_candidate(SwitchFlow.find_switch_candidate(slot, roster, request_team)), false, "current request blocks the fainted Pokemon despite the old healthy card")
	var refreshed := SwitchFlow.refresh_switch_card(old_card, roster, request_team)
	_check_equal(refreshed.get("hp"), 0, "selector refresh shows zero HP instead of stale healthy HP")
	_check_equal(refreshed.get("fainted"), true, "selector refresh shows the fainted state")
	_check_equal(old_card.get("condition"), "100/100", "refresh does not mutate the ordered presentation card")
	_check_equal(SwitchFlow.is_available_switch_candidate(SwitchFlow.find_switch_candidate(1, roster, request_team)), true, "reordered request still allows a living replacement by canonical identity")
	_check_equal(SwitchFlow.is_available_switch_candidate(SwitchFlow.find_switch_candidate(3, roster, request_team)), false, "active Pokemon cannot be selected again")
	_check_equal(SwitchFlow.find_switch_candidate(2, roster, request_team), {}, "missing canonical Pokemon never falls back to the request index")
	for health_data: Dictionary in [{"hp": 0}, {"currentHp": 0}, {"condition": "0/100"}, {"condition": "fnt"}]:
		_check_equal(SwitchFlow.is_available_switch_candidate(health_data), false, "zero-health forms cannot be submitted")
	_check_equal(SwitchFlow.is_available_switch_candidate({"condition": "75/100", "currentHp": 0}), true, "explicit live condition takes priority over an old saved HP field")
	var duplicate_team := request_team.duplicate(true)
	duplicate_team.append(request_team[0].duplicate(true))
	_check_equal(SwitchFlow.find_switch_candidate(4, roster, duplicate_team), {}, "ambiguous request identity fails closed")


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


func _check_mimikyu_battle_form_resolves_to_canonical_slot() -> void:
	var roster := [
		{"species": "Mimikyu-Disguised", "instanceId": "mimikyu", "canonicalPartySlot": 3},
	]
	_check_equal(
		Resolver.resolve_selected_slot({"species": "Mimikyu", "instanceId": "mimikyu"}, roster),
		3,
		"Showdown base Mimikyu resolves to its canonical disguised-form slot"
	)
	_check_equal(
		Resolver.resolve_selected_slot({"species": "Mimikyu-Busted", "instanceId": "mimikyu"}, roster),
		3,
		"Mimikyu's in-battle busted form keeps the same canonical slot"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
