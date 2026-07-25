extends SceneTree

const BattleStateScript := preload("res://scripts/battle/battle_state.gd")

var failed := false


func _init() -> void:
	var state = BattleStateScript.new()
	state.load_from_api_response({
		"battleId": "z-move-state-test",
		"requests": {
			"p1": {
				"active": [{
					"moves": [
						{"id": "tackle", "name": "Tackle", "disabled": true},
						{"id": "protect", "name": "Protect"},
						{"id": "quickattack", "name": "Quick Attack"},
					],
					"canZMove": [
						{"id": "breakneckblitz", "name": "Breakneck Blitz", "move": "Breakneck Blitz"},
						null,
						{"id": "breakneckblitz", "name": "Breakneck Blitz", "move": "Breakneck Blitz"},
					],
				}],
				"side": {"pokemon": [{
					"ident": "p1a: Eevee",
					"species": "Eevee",
					"active": true,
				}]},
			},
		},
	}, false)

	_check_equal(state.can_active_pokemon_use_z_move("p1"), true, "active Pokemon exposes Z-Move availability")
	_check_equal(state.can_active_pokemon_use_z_move_slot(1, "p1"), true, "eligible disabled base slot remains a valid Z-Move")
	_check_equal(state.can_active_pokemon_use_z_move_slot(2, "p1"), false, "null Z-Move slot is rejected")
	_check_equal(
		state.get_z_move_for_slot(3, "p1").get("name", ""),
		"Breakneck Blitz",
		"Z-Move metadata remains associated with its exact move slot"
	)
	_check_equal(state.can_active_pokemon_use_z_move_slot(4, "p1"), false, "out-of-range Z-Move slot is rejected")

	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
