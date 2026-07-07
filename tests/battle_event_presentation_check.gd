extends SceneTree

const BattleEventPresentationScript := preload("res://scripts/battle/battle_event_presentation.gd")
const BattleEventTextFormatterScript := preload("res://scripts/battle/battle_event_text_formatter.gd")
const BattleHpEventHelperScript := preload("res://scripts/battle/battle_hp_event_helper.gd")

var failed := false


func _init() -> void:
	_check_previous_condition_uses_visible_scale()
	_check_full_hp_reveal_damage_has_no_damage_target()
	_check_real_damage_keeps_damage_target()
	_check_damage_after_hazard_uses_numeric_delta_when_previous_condition_is_stale()
	_check_damage_after_hazard_logs_when_conditions_repeat()
	_check_damage_after_hazard_logs_mixed_visible_and_exact_conditions()
	_check_booster_energy_quark_drive_messages()
	_check_paralysis_status_event_uses_status_effect_animation()
	_check_paralysis_cant_event_replays_status_effect_animation()
	quit(1 if failed else 0)


func _make_presentation():
	var presentation = BattleEventPresentationScript.new()
	presentation.setup(
		BattleEventTextFormatterScript.new(),
		BattleHpEventHelperScript.new(),
		Callable(self, "_format_actor"),
		Callable(self, "_get_player_display_name")
	)
	return presentation


func _check_previous_condition_uses_visible_scale() -> void:
	var helper = BattleHpEventHelperScript.new()
	var snapshot: Dictionary = helper.get_event_hp_snapshot({
		"type": "damage",
		"target": "p2a: Garchomp",
		"previousCondition": "100/100",
		"condition": "357/357",
		"previousHp": 100,
		"hp": 357,
		"maxHp": 357,
	}, true)

	_check_equal(snapshot.get("hp", 0), 100, "previous snapshot keeps visible HP")
	_check_equal(snapshot.get("max_hp", 0), 100, "previous snapshot keeps visible max HP")


func _check_full_hp_reveal_damage_has_no_damage_target() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"previousCondition": "100/100",
		"condition": "357/357",
		"previousHp": 100,
		"hp": 357,
		"maxHp": 357,
	})

	_check_equal(str(result.get("damage_target_ident", "")), "", "full HP reveal does not animate damage")
	_check_equal(str(result.get("log_message", "")), "", "full HP reveal has no damage log")


func _check_real_damage_keeps_damage_target() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"previousCondition": "357/357",
		"condition": "0 fnt",
		"previousHp": 357,
		"hp": 0,
		"maxHp": 357,
	})

	_check_equal(str(result.get("damage_target_ident", "")), "p2a: Garchomp", "real damage still animates")


func _check_damage_after_hazard_uses_numeric_delta_when_previous_condition_is_stale() -> void:
	var presentation = _make_presentation()
	presentation.build({
		"type": "move",
		"actor": "p1a: Pikachu",
		"move": "Thunderbolt",
		"target": "p2a: Charizard",
	})
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Charizard",
		"previousCondition": "100/100",
		"condition": "230/400",
		"previousHp": 350,
		"hp": 230,
		"maxHp": 400,
		"amount": 120,
	})

	_check_equal(str(result.get("log_message", "")), "(Charizard lost 30% of its health!)", "damage after hazard ignores stale previous condition")


func _check_damage_after_hazard_logs_when_conditions_repeat() -> void:
	var presentation = _make_presentation()
	presentation.build({
		"type": "move",
		"actor": "p1a: Pikachu",
		"move": "Thunderbolt",
		"target": "p2a: Charizard",
	})
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Charizard",
		"previousCondition": "88/100",
		"condition": "88/100",
		"previousHp": 350,
		"hp": 230,
		"maxHp": 400,
		"amount": 120,
	})

	_check_equal(str(result.get("log_message", "")), "(Charizard lost 30% of its health!)", "damage after hazard logs repeated-condition numeric loss")


func _check_damage_after_hazard_logs_mixed_visible_and_exact_conditions() -> void:
	var presentation = _make_presentation()
	presentation.build({
		"type": "move",
		"actor": "p1a: Great Tusk",
		"move": "Earthquake",
		"target": "p2a: Alomomola",
	})
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Alomomola",
		"previousCondition": "94/100",
		"condition": "283/472",
		"previousHp": 94,
		"hp": 283,
		"maxHp": 472,
		"amount": 189,
	})

	_check_equal(str(result.get("log_message", "")), "(Alomomola lost 34% of its health!)", "damage after hazard logs visible delta before exact HP reveal")


func _check_booster_energy_quark_drive_messages() -> void:
	var presentation = _make_presentation()
	var item_result: Dictionary = presentation.build({
		"type": "item",
		"target": "p1a: Iron Valiant",
		"item": "Booster Energy",
		"state": "end",
	})
	var ability_result: Dictionary = presentation.build({
		"type": "ability",
		"target": "p1a: Iron Valiant",
		"ability": "Quark Drive",
		"effect": "boost",
		"stat": "spe",
		"source": "item: Booster Energy",
	})

	_check_equal(str(item_result.get("log_message", "")), "Iron Valiant's Booster Energy activated!", "Booster Energy lead item activation logs")
	_check_equal(str(item_result.get("battle_message", "")), "Iron Valiant's Booster Energy activated!", "Booster Energy lead item activation battle text")
	_check_equal(str(ability_result.get("log_message", "")), "Iron Valiant's Quark Drive boosted its Speed!", "Quark Drive lead stat boost logs")
	_check_equal(str(ability_result.get("battle_message", "")), "Iron Valiant's Quark Drive boosted its Speed!", "Quark Drive lead stat boost battle text")
	_check_equal(str(ability_result.get("ability_boost_target_ident", "")), "p1a: Iron Valiant", "Quark Drive lead stat boost animates badge target")


func _check_paralysis_status_event_uses_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "status",
		"target": "p2a: Garchomp",
		"status": "par",
		"state": "start",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_paralysis", "paralysis status start uses status effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "paralysis status start targets affected Pokemon")


func _check_paralysis_cant_event_replays_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "cant",
		"actor": "p1a: Pikachu",
		"reason": "par",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_paralysis", "paralysis cant replays status effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p1a: Pikachu", "paralysis cant targets blocked actor")


func _format_actor(ident: String, _prefer_player_name := true) -> String:
	if ident.contains(": "):
		return str(ident.split(": ")[1]).strip_edges()
	return ident


func _get_player_display_name(player_id: String) -> String:
	return player_id


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
