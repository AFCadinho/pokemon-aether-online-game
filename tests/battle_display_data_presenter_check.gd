extends SceneTree

const BattleDisplayDataPresenterScript := preload("res://scripts/battle/battle_display_data_presenter.gd")
const BattleStateScript := preload("res://scripts/battle/battle_state.gd")

var failed := false


func _init() -> void:
	_check_trainer_active_species_uses_metadata_form()

	quit(1 if failed else 0)


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


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
