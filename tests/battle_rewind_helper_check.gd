extends SceneTree

const BattleRewindHelperScript := preload("res://scripts/battle/battle_rewind_helper.gd")

var failed := false
var rewind_helper := BattleRewindHelperScript.new()


func _init() -> void:
	_check_faint_event_with_previous_hp_rewinds_party_icon()
	_check_previous_condition_rewind_still_works()
	_check_npc_team_without_pokemon_keys_falls_back_to_metadata_slot()

	quit(1 if failed else 0)


func _check_faint_event_with_previous_hp_rewinds_party_icon() -> void:
	var team: Array = [{
		"ident": "p1a: Pikachu",
		"species": "Pikachu",
		"active": true,
		"condition": "0 fnt",
		"hp": 0,
		"maxHp": 100,
		"currentHp": 0,
		"fainted": true,
	}]

	var rewound_team := rewind_helper.get_rewound_team_data_for_events("p1", team, [{
		"type": "faint",
		"target": "p1a: Pikachu",
		"previousHp": 24,
		"hp": 0,
		"maxHp": 100,
	}])

	var rewound_pokemon: Dictionary = rewound_team[0]
	_check_equal(bool(rewound_pokemon.get("fainted", true)), false, "previousHp faint rewind clears fainted")
	_check_equal(int(rewound_pokemon.get("hp", 0)), 24, "previousHp faint rewind restores HP")
	_check_equal(str(rewound_pokemon.get("condition", "")), "24/100", "previousHp faint rewind restores condition")


func _check_previous_condition_rewind_still_works() -> void:
	var team: Array = [{
		"ident": "p2a: Charizard",
		"species": "Charizard",
		"active": true,
		"condition": "0 fnt",
		"hp": 0,
		"maxHp": 120,
		"fainted": true,
	}]

	var rewound_team := rewind_helper.get_rewound_team_data_for_events("p2", team, [{
		"type": "damage",
		"target": "p2a: Charizard",
		"previousCondition": "90/120 brn",
		"condition": "0 fnt",
	}])

	var rewound_pokemon: Dictionary = rewound_team[0]
	_check_equal(bool(rewound_pokemon.get("fainted", true)), false, "previousCondition rewind clears fainted")
	_check_equal(int(rewound_pokemon.get("hp", 0)), 90, "previousCondition rewind restores HP")
	_check_equal(str(rewound_pokemon.get("status", "")), "brn", "previousCondition rewind restores status")


func _check_npc_team_without_pokemon_keys_falls_back_to_metadata_slot() -> void:
	var team: Array = [
		{
			"ident": "p2: Spiritomb",
			"species": "Spiritomb",
			"active": true,
			"condition": "0 fnt",
			"hp": 0,
			"maxHp": 100,
			"metadataSlot": 1,
			"fainted": true,
		},
		{
			"ident": "p2: Roserade",
			"species": "Roserade",
			"active": false,
			"condition": "0 fnt",
			"hp": 0,
			"maxHp": 261,
			"metadataSlot": 2,
			"fainted": true,
		},
	]

	var rewound_team := rewind_helper.get_rewound_team_data_for_events("p2", team, [{
		"type": "damage",
		"target": "p2a: Spiritomb",
		"previousCondition": "100/100",
		"condition": "0 fnt",
		"pokemonKey": "p2:slot:1",
		"metadataSlot": 1,
		"targetRef": {
			"pokemonKey": "p2:slot:1",
			"metadataSlot": 1,
			"partySlot": 1,
		},
	}])

	var spiritomb: Dictionary = rewound_team[0]
	var roserade: Dictionary = rewound_team[1]
	_check_equal(bool(spiritomb.get("fainted", true)), false, "NPC empty-key team falls back to metadata slot")
	_check_equal(int(spiritomb.get("hp", 0)), 100, "NPC empty-key fallback restores previous HP")
	_check_equal(bool(roserade.get("fainted", false)), true, "NPC empty-key fallback does not rewind wrong slot")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
