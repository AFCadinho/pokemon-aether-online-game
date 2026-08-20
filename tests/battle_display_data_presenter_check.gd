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
						"species": "Ogerpon-Wellspring",
						"displaySpecies": "Ogerpon-Wellspring",
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
		"Ogerpon-Wellspring",
		"the default Showdown Ogerpon ident does not hide the opponent mask forme"
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
