extends SceneTree

const BattleDisplayDataPresenterScript := preload("res://scripts/battle/battle_display_data_presenter.gd")
const BattleStateScript := preload("res://scripts/battle/battle_state.gd")

var failed := false

class FakePlayerSave:
	extends Node
	var party: Array = []


func _init() -> void:
	call_deferred("_run_checks")


func _run_checks() -> void:
	_check_local_ogerpon_uses_mask_battle_form()
	_check_opponent_ogerpon_default_ident_uses_mask_form_name()
	_check_opponent_default_name_follows_public_mega_form()
	_check_opponent_default_name_follows_snapshot_mega_form()
	_check_opponent_custom_nickname_survives_public_mega_form()
	_check_known_trainer_team_keeps_public_mega_form()
	_check_training_ai_public_mega_event_updates_all_opponent_display_data()
	_check_training_ai_mega_event_uses_canonical_slot_after_form_ident_changes()
	_check_training_ai_canonical_slot_keeps_live_state_across_form_identity_change()
	_check_trainer_active_species_uses_metadata_form()
	_check_trainer_team_display_keeps_roster_species_during_ambiguous_switch_state()
	_check_trainer_team_display_ignores_request_slot_identity_for_species_match()

	quit(1 if failed else 0)


func _check_local_ogerpon_uses_mask_battle_form() -> void:
	var player_save := root.get_node_or_null("PlayerSave")
	var owns_player_save := player_save == null
	if owns_player_save:
		player_save = FakePlayerSave.new()
		player_save.name = "PlayerSave"
		root.add_child(player_save)
	var original_party: Array[Pokemon] = []
	original_party.append_array(player_save.get("party") as Array)
	var test_party: Array[Pokemon] = [Pokemon.new(
		"Ogerpon",
		100,
		"Wellspring Mask",
		"defiant",
		"Jolly",
		{},
		{},
		{},
		[],
		"ogerpon-instance",
		1,
		false,
		false,
		["grass"],
		["defiant"]
	)]
	player_save.party = test_party
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "local-ogerpon-mask-display-test",
		"requests": {
			"p1": {
				"side": {
					"pokemon": [{
						"ident": "p1: Ogerpon",
						"species": "Ogerpon",
						"displaySpecies": "Ogerpon",
						"instanceId": "ogerpon-instance",
						"metadataSlot": 1,
						"active": true,
					}],
				},
			},
		},
	}, false)

	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	_check_equal(
		presenter.get_active_display_species("p1"),
		"Ogerpon Wellspring",
		"local Ogerpon active display species follows its held mask"
	)
	_check_equal(
		presenter.get_active_display_name("p1"),
		"Ogerpon Wellspring",
		"an unnicknamed local Ogerpon uses its mask forme on the battle HUD"
	)
	var display_team := presenter.get_display_team_data("p1")
	_check_equal(display_team[0].get("species", ""), "Ogerpon Wellspring", "party display uses the Wellspring forme")
	_check_equal(display_team[0].get("types", []), ["grass", "water"], "party display uses Wellspring types")
	_check_equal(display_team[0].get("ability", ""), "water-absorb", "party display uses Water Absorb")

	player_save.party = original_party
	if owns_player_save:
		root.remove_child(player_save)
		player_save.free()


func _check_opponent_ogerpon_default_ident_uses_mask_form_name() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "opponent-ogerpon-mask-display-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: Ogerpon",
						"name": "Ogerpon",
						"species": "Ogerpon",
						"displaySpecies": "Ogerpon",
						"details": "Ogerpon-Wellspring, F",
						"active": true,
					}],
				},
			},
		},
	}, false)

	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	_check_equal(
		presenter.get_active_display_species("p2"),
		"Ogerpon Wellspring",
		"public switch details repair a generic opponent Ogerpon species"
	)
	_check_equal(
		presenter.get_active_display_name("p2"),
		"Ogerpon Wellspring",
		"the default Showdown Ogerpon ident does not hide the opponent mask forme"
	)


func _build_opponent_mega_presenter(display_name: String):
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "opponent-mega-display-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: %s" % display_name,
						"name": display_name,
						"species": "Dragonite",
						"item": "Dragoniteite",
						"active": true,
					}],
				},
			},
		},
	}, false)
	state.apply_event_conditions([{
		"type": "mega",
		"target": "p2a: %s" % display_name,
		"species": "Dragonite-Mega",
	}])
	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	return presenter


func _check_opponent_default_name_follows_public_mega_form() -> void:
	var presenter = _build_opponent_mega_presenter("Dragonite")
	_check_equal(
		presenter.get_active_display_species("p2"),
		"Dragonite-Mega",
		"the opponent's publicly revealed Mega species is retained"
	)
	_check_equal(
		presenter.get_active_display_name("p2"),
		"Dragonite-Mega",
		"an unnicknamed opponent uses its revealed Mega species in the HUD and battle log"
	)


func _check_opponent_custom_nickname_survives_public_mega_form() -> void:
	var presenter = _build_opponent_mega_presenter("Puff")
	_check_equal(
		presenter.get_active_display_name("p2"),
		"Puff",
		"a custom opponent nickname remains visible after Mega Evolution"
	)


func _check_known_trainer_team_keeps_public_mega_form() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "trainer-sableye-mega-display-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: Sableye",
						"species": "Sableye",
						"item": "Sablenite",
						"condition": "93/100",
						"active": true,
						"partySlot": 1,
					}],
				},
			},
		},
	}, false)
	state.apply_event_conditions([{
		"type": "mega",
		"target": "p2a: Sableye",
		"species": "Sableye-Mega",
	}])
	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	presenter.set_battle_context(1, null)
	presenter.set_trainer_team([{
		"ident": "p2: Sableye",
		"species": "Sableye",
		"item": "Sablenite",
		"moves": ["Knock Off", "Will-O-Wisp", "Recover", "Protect"],
		"partySlot": 1,
	}])

	_check_equal(presenter.get_active_display_species("p2"), "Sableye-Mega", "active AI field presentation uses Mega Sableye")
	var display_team: Array = presenter.get_display_team_data("p2")
	_check_equal(display_team.size(), 1, "known AI team keeps one canonical Sableye slot after Mega Evolution")
	var display_sableye: Dictionary = display_team[0] as Dictionary
	_check_equal(display_sableye.get("displaySpecies", ""), "Sableye-Mega", "known AI party slot adopts the public Mega forme")
	_check_equal(display_sableye.get("megaSpecies", ""), "Sableye-Mega", "known AI hover data retains the public Mega species")
	_check_equal(display_sableye.get("condition", ""), "93/100", "known AI Mega slot retains its live condition")
	_check_equal((display_sableye.get("moves", []) as Array).size(), 4, "known AI Mega hover retains its known moveset")


func _check_training_ai_public_mega_event_updates_all_opponent_display_data() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "training-ai-public-mega-display-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: Latios",
						"species": "Latios",
						"name": "Latios",
						"active": true,
						"metadataSlot": 1,
					}],
				},
			},
		},
	}, false)
	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	presenter.set_battle_context(1, null)
	presenter.set_trainer_team([{
		"species": "Latios",
		"name": "Latios",
		"metadataSlot": 1,
	}], true)
	# The current response still reports the base form. The public Mega event
	# must nevertheless update the field HUD and trainer roster immediately.
	presenter.remember_public_trainer_mega_species({
		"type": "mega",
		"target": "p2a: Latios",
		"species": "Latios-Mega",
		"metadataSlot": 1,
		"targetRef": {"metadataSlot": 1, "pokemonKey": "p2:slot:1"},
	})
	_check_equal(presenter.get_active_display_species("p2"), "Latios-Mega", "AI Mega event updates the opponent field species before the next request")
	_check_equal(presenter.get_active_display_name("p2"), "Latios-Mega", "AI Mega event updates the opponent HUD name before the next request")
	var display_team: Array = presenter.get_display_team_data("p2")
	var display_latios: Dictionary = display_team[0] as Dictionary
	_check_equal(display_latios.get("displaySpecies", ""), "Latios-Mega", "AI Mega event updates the opponent party-rail icon before the next request")


func _check_training_ai_mega_event_uses_canonical_slot_after_form_ident_changes() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "training-ai-mega-canonical-slot-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: Sableye",
						"species": "Sableye",
						"name": "Sableye",
						"item": "Sablenite",
						"active": true,
						"metadataSlot": 1,
					}],
				},
			},
		},
	}, false)
	# The public event can already use the transformed ident, but its targetRef
	# points at the immutable imported team slot. Persisting the Mega form there
	# keeps the opponent HUD name and field sprite on the same form after the
	# Mega animation's final refresh.
	state.apply_event_conditions([{
		"type": "mega",
		"target": "p2a: Sableye-Mega",
		"species": "Sableye-Mega",
		"metadataSlot": 1,
		"pokemonKey": "p2:slot:1",
		"targetRef": {
			"metadataSlot": 1,
			"pokemonKey": "p2:slot:1",
		},
	}])
	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	_check_equal(
		presenter.get_active_display_species("p2"),
		"Sableye-Mega",
		"AI Mega event persists its public form through the canonical imported slot"
	)
	_check_equal(
		presenter.get_active_display_name("p2"),
		"Sableye-Mega",
		"AI Mega event keeps the opponent HUD name on the public Mega form"
	)


func _check_training_ai_canonical_slot_keeps_live_state_across_form_identity_change() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "training-ai-canonical-form-state-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: Ditto",
						"species": "Ditto",
						"displaySpecies": "Dragonite",
						"transformedSpecies": "Dragonite",
						"condition": "71/100 brn",
						"hp": 71,
						"maxHp": 100,
						"status": "brn",
						"active": true,
						"partySlot": 1,
					}],
				},
			},
		},
	}, false)
	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	presenter.set_battle_context(1, null)
	# AI Sparring owns an immutable imported slot identity. Even if an imported
	# form label and Showdown's live form label diverge, the slot's live HP and
	# status must remain authoritative.
	presenter.set_trainer_team([{
		"species": "Ditto",
		"condition": "100/100",
		"hp": 100,
		"maxHp": 100,
		"metadataSlot": 1,
	}], true)

	var display_team: Array = presenter.get_display_team_data("p2")
	var display_ditto: Dictionary = display_team[0] as Dictionary
	_check_equal(display_ditto.get("displaySpecies", ""), "Dragonite", "AI canonical slot keeps the live transformed species")
	_check_equal(display_ditto.get("condition", ""), "71/100 brn", "AI canonical slot cannot restore imported full HP")
	_check_equal(int(display_ditto.get("hp", 0)), 71, "AI canonical slot keeps live damaged HP")
	_check_equal(display_ditto.get("status", ""), "brn", "AI canonical slot keeps live status")


func _check_opponent_default_name_follows_snapshot_mega_form() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "opponent-mega-snapshot-display-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: Zeraora",
						"species": "Zeraora",
						"displaySpecies": "Zeraora-Mega",
						"active": true,
					}],
				},
			},
		},
	}, false)
	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	_check_equal(
		presenter.get_active_display_name("p2"),
		"Zeraora-Mega",
		"a canonical public Mega snapshot updates the ordinary opponent HUD name"
	)


func _check_trainer_active_species_uses_metadata_form() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "trainer-form-display-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [{
						"ident": "p2a: Landorus",
						"species": "Landorus",
						"metadataSlot": 1,
						"active": true,
					}],
				},
			},
		},
	}, false)

	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	presenter.set_battle_context(1, null)
	presenter.set_trainer_team([{
		"species": "Landorus-Therian",
		"metadataSlot": 1,
	}])

	_check_equal(
		presenter.get_active_display_species("p2"),
		"Landorus-Therian",
		"trainer active display species uses metadata form before initial events"
	)


func _check_trainer_team_display_keeps_roster_species_during_ambiguous_switch_state() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "trainer-team-display-stability-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [
						{
							"ident": "p2: Caterpie",
							"species": "Caterpie",
							"metadataSlot": 1,
							"condition": "0 fnt",
							"active": false,
						},
						{
							"ident": "p2: Caterpie",
							"species": "Caterpie",
							"metadataSlot": 2,
							"condition": "20/20",
							"active": true,
						},
					],
				},
			},
		},
	}, false)

	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	presenter.set_battle_context(1, null)
	presenter.set_trainer_team([
		{
			"species": "Weedle",
			"metadataSlot": 1,
		},
		{
			"species": "Caterpie",
			"metadataSlot": 2,
		},
	])

	var display_team := presenter.get_display_team_data("p2")
	_check_equal(display_team.size(), 2, "trainer display team keeps roster size")
	_check_equal(display_team[0].get("species", ""), "Weedle", "trainer display slot 1 keeps roster species")
	_check_equal(display_team[1].get("species", ""), "Caterpie", "trainer display slot 2 keeps roster species")


func _check_trainer_team_display_ignores_request_slot_identity_for_species_match() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "trainer-team-display-wrong-request-slot-test",
		"requests": {
			"p2": {
				"side": {
					"pokemon": [
						{
							"ident": "p2: Caterpie",
							"species": "Caterpie",
							"metadataSlot": 2,
							"partySlot": 2,
							"pokemonKey": "p2:slot:2",
							"condition": "100/100",
							"active": true,
						},
						{
							"ident": "p2: Weedle",
							"species": "Weedle",
							"condition": "0 fnt",
							"active": false,
						},
					],
				},
			},
		},
	}, false)

	var presenter = BattleDisplayDataPresenterScript.new()
	presenter.setup(state)
	presenter.set_battle_context(1, null)
	presenter.set_trainer_team([
		{
			"species": "Caterpie",
			"metadataSlot": 1,
		},
		{
			"species": "Weedle",
			"metadataSlot": 2,
		},
	])

	var display_team := presenter.get_display_team_data("p2")
	_check_equal(display_team[0].get("species", ""), "Caterpie", "trainer display slot 1 ignores wrong request slot species overwrite")
	_check_equal(display_team[0].get("metadataSlot", 0), 1, "trainer display slot 1 keeps roster metadata slot")
	_check_equal(display_team[0].get("active", false), true, "trainer display slot 1 keeps active state from species request")
	_check_equal(display_team[1].get("species", ""), "Weedle", "trainer display slot 2 remains Weedle")
	_check_equal(display_team[1].get("metadataSlot", 0), 2, "trainer display slot 2 keeps roster metadata slot")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
