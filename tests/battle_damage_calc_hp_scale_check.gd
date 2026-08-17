extends SceneTree

const DamageCalcPanel := preload("res://scripts/battle/battle_ui/battle_damage_calc_panel.gd")


func _init() -> void:
	var panel := DamageCalcPanel.new()
	panel.set_knowledge_snapshot({
		"viewerPokemon": [{
			"pokemonRef": "viewer:public-slot-1",
			"active": true,
			"identity": {"state": "known", "value": "Conkeldurr"},
		}],
		"opponentPokemon": [{
			"pokemonRef": "opponent:public-slot-1",
			"active": true,
			"identity": {"state": "known", "value": "Nidoran-F"},
			"hp": {"percent": 100.0},
		}],
	})
	panel.last_response = {
		"direction": "own-to-opponent",
		"results": [{
			"minDamage": 11,
			"minPercent": 50.0,
		}],
	}

	var dealt_hp := panel._get_battle_state_hp_display("opponent")
	_check_equal(dealt_hp.get("current"), 22, "damage dealt current HP")
	_check_equal(dealt_hp.get("maximum"), 22, "damage dealt maximum HP")

	panel.active_subtab = panel.SUBTAB_THEIR_DAMAGE
	panel.last_response = {}
	var taken_hp := panel._get_battle_state_hp_display("opponent")
	_check_equal(taken_hp.get("current"), 22, "damage taken current HP")
	_check_equal(taken_hp.get("maximum"), 22, "damage taken maximum HP")

	panel.free()
	print("PASS battle_damage_calc_hp_scale_check")
	quit(0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	push_error("%s: expected %s, got %s" % [label, expected, actual])
	quit(1)
