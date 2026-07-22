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
	_check_future_sight_lifecycle_messages()
	_check_solar_beam_prepare_uses_charge_animation()
	_check_electro_shot_prepare_uses_charge_animation()
	_check_wish_heal_uses_delayed_animation()
	_check_protect_activation_uses_block_animation()
	_check_evasion_drop_uses_normalized_negative_amount()
	_check_paralysis_status_event_uses_status_effect_animation()
	_check_paralysis_cant_event_replays_status_effect_animation()
	_check_freeze_status_event_uses_status_effect_animation()
	_check_freeze_cant_event_replays_status_effect_animation()
	_check_sleep_status_event_uses_status_effect_animation()
	_check_sleep_cant_event_replays_status_effect_animation()
	_check_poison_status_event_uses_status_effect_animation()
	_check_badly_poisoned_status_event_uses_status_effect_animation()
	_check_burn_status_event_uses_status_effect_animation()
	_check_confusion_pokemon_effect_uses_status_effect_animation()
	_check_confusion_activate_replays_status_effect_animation()
	_check_direct_damage_on_statused_target_does_not_replay_status_effect()
	_check_poison_damage_replays_status_effect_animation()
	_check_badly_poisoned_damage_replays_status_effect_animation()
	_check_burn_damage_replays_status_effect_animation()
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


func _check_future_sight_lifecycle_messages() -> void:
	var presentation = _make_presentation()
	var start_result: Dictionary = presentation.build({
		"type": "pokemonEffect",
		"target": "p1a: Slowking",
		"effect": "move: Future Sight",
		"state": "start",
	})
	var hit_result: Dictionary = presentation.build({
		"type": "pokemonEffect",
		"target": "p2a: Iron Valiant",
		"effect": "move: Future Sight",
		"state": "end",
	})

	_check_equal(str(start_result.get("log_message", "")), "Slowking foresaw an attack!", "Future Sight setup is described as a delayed attack")
	_check_equal(str(hit_result.get("log_message", "")), "The opposing Iron Valiant took the Future Sight attack!", "Future Sight resolution names the delayed hit")
	_check_equal(str(start_result.get("effect_animation_key", "")), "", "Future Sight setup does not replay the move animation")
	_check_equal(str(hit_result.get("effect_animation_key", "")), "future_sight_impact", "Future Sight resolution plays its delayed impact animation")

	var damage_result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Iron Valiant",
		"source": "move: Future Sight",
		"previousCondition": "100/100",
		"condition": "42/100",
		"previousHp": 100,
		"hp": 42,
		"maxHp": 100,
	})
	_check_equal(str(damage_result.get("effect_animation_key", "")), "future_sight_impact", "Future Sight damage source plays its delayed impact animation")


func _check_solar_beam_prepare_uses_charge_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "prepare",
		"actor": "p1a: Venusaur",
		"move": "Solar Beam",
	})
	_check_equal(str(result.get("log_message", "")), "Venusaur is absorbing light!", "Solar Beam charge uses player-facing text")
	_check_equal(str(result.get("effect_animation_key", "")), "solar_beam_charge", "Solar Beam charge uses its separate charge animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p1a: Venusaur", "Solar Beam charge is anchored to the attacker")


func _check_electro_shot_prepare_uses_charge_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "prepare",
		"actor": "p1a: Raging Bolt",
		"move": "Electro Shot",
	})
	_check_equal(str(result.get("log_message", "")), "Raging Bolt is charging electricity!", "Electro Shot charge uses player-facing text")
	_check_equal(str(result.get("effect_animation_key", "")), "electro_shot_charge", "Electro Shot charge uses its separate charge animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p1a: Raging Bolt", "Electro Shot charge is anchored to the attacker")


func _check_wish_heal_uses_delayed_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "heal",
		"target": "p1a: Jirachi",
		"source": "[from] move: Wish",
		"previousHp": 40,
		"hp": 90,
		"maxHp": 100,
	})
	_check_equal(str(result.get("effect_animation_key", "")), "wish_fulfilled", "Wish healing uses its delayed fulfillment animation")
	_check_equal(str(result.get("heal_followup_effect_animation_key", "")), "generic_heal", "Wish fulfillment is followed by the normal heal animation")


func _check_protect_activation_uses_block_animation() -> void:
	var presentation = _make_presentation()
	var setup_result: Dictionary = presentation.build({
		"type": "pokemonEffect",
		"target": "p1a: Alomomola",
		"effect": "move: Protect",
		"state": "start",
	})
	var block_result: Dictionary = presentation.build({
		"type": "pokemonEffect",
		"target": "p1a: Alomomola",
		"effect": "move: Protect",
		"state": "activate",
	})
	_check_equal(str(setup_result.get("log_message", "")), "Alomomola protected itself!", "Protect setup uses player-facing text")
	_check_equal(str(setup_result.get("effect_animation_key", "")), "", "Protect setup does not replay its move animation")
	_check_equal(str(block_result.get("log_message", "")), "Alomomola protected itself!", "Protect activation uses player-facing text")
	_check_equal(str(block_result.get("effect_animation_key", "")), "protect_block", "Protect activation plays the shield block animation")


func _check_evasion_drop_uses_normalized_negative_amount() -> void:
	var presentation = _make_presentation()
	var event := {
		"type": "statChange",
		"target": "p1a: Ceruledge",
		"stat": "evasion",
		"direction": "down",
		"stage": 1,
	}
	var preload_data: Dictionary = presentation.get_animation_preload_keys_for_event(event)
	var result: Dictionary = presentation.build(event)

	_check_equal(int(result.get("stat_change_amount", 0)), -1, "evasion drop retains its negative stage amount")
	_check_equal(str(result.get("effect_animation_key", "")), "stat_down", "evasion drop uses the stat-down animation")
	_check_equal((preload_data.get("effect_keys", []) as Array).has("stat_down"), true, "evasion drop preloads the stat-down effect")


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


func _check_freeze_status_event_uses_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "status",
		"target": "p2a: Garchomp",
		"status": "frz",
		"state": "start",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_frozen", "freeze status start uses freeze effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "freeze status start targets affected Pokemon")


func _check_freeze_cant_event_replays_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "cant",
		"actor": "p1a: Pikachu",
		"reason": "frz",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_frozen", "freeze cant replays status effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p1a: Pikachu", "freeze cant targets blocked actor")


func _check_sleep_status_event_uses_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "status",
		"target": "p2a: Garchomp",
		"status": "slp",
		"state": "start",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_sleeping", "sleep status start uses sleep effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "sleep status start targets affected Pokemon")


func _check_sleep_cant_event_replays_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "cant",
		"actor": "p1a: Pikachu",
		"reason": "slp",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_sleeping", "sleep cant replays status effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p1a: Pikachu", "sleep cant targets blocked actor")


func _check_poison_status_event_uses_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "status",
		"target": "p2a: Garchomp",
		"status": "psn",
		"state": "start",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_poisoned", "poison status start uses poison effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "poison status start targets affected Pokemon")


func _check_badly_poisoned_status_event_uses_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "status",
		"target": "p2a: Garchomp",
		"status": "tox",
		"state": "start",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_badly_poisoned", "badly poisoned status start uses toxic effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "badly poisoned status start targets affected Pokemon")


func _check_burn_status_event_uses_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "status",
		"target": "p2a: Garchomp",
		"status": "brn",
		"state": "start",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_burned", "burn status start uses burn effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "burn status start targets affected Pokemon")


func _check_confusion_pokemon_effect_uses_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "pokemonEffect",
		"target": "p2a: Garchomp",
		"effect": "confusion",
		"state": "start",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_confused", "confusion start uses confused effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "confusion start targets affected Pokemon")


func _check_confusion_activate_replays_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "pokemonEffect",
		"target": "p1a: Pikachu",
		"effect": "confusion",
		"state": "activate",
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_confused", "confusion activate replays confused effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p1a: Pikachu", "confusion activate targets affected Pokemon")


func _check_direct_damage_on_statused_target_does_not_replay_status_effect() -> void:
	var presentation = _make_presentation()
	presentation.build({
		"type": "move",
		"actor": "p1a: Garchomp",
		"move": "Earthquake",
		"target": "p2a: Steelix",
	})
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Steelix",
		"previousCondition": "100/100 psn",
		"condition": "64/100 psn",
		"previousHp": 100,
		"hp": 64,
		"maxHp": 100,
	})

	_check_equal(str(result.get("effect_animation_key", "")), "", "direct damage on poisoned target does not replay poison effect")
	_check_equal(str(result.get("damage_target_ident", "")), "p2a: Steelix", "direct damage on poisoned target still animates HP loss")

	result = presentation.build({
		"type": "damage",
		"target": "p2a: Steelix",
		"previousCondition": "64/100 brn",
		"condition": "28/100 brn",
		"previousHp": 64,
		"hp": 28,
		"maxHp": 100,
	})

	_check_equal(str(result.get("effect_animation_key", "")), "", "direct damage on burned target does not replay burn effect")
	_check_equal(str(result.get("damage_target_ident", "")), "p2a: Steelix", "direct damage on burned target still animates HP loss")


func _check_poison_damage_replays_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"source": "psn",
		"previousCondition": "100/100 psn",
		"condition": "88/100 psn",
		"previousHp": 100,
		"hp": 88,
		"maxHp": 100,
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_poisoned", "poison damage replays poison effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "poison damage targets affected Pokemon")
	_check_equal(str(result.get("damage_target_ident", "")), "p2a: Garchomp", "poison damage still animates HP loss")


func _check_badly_poisoned_damage_replays_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"source": "tox",
		"previousCondition": "100/100 tox",
		"condition": "82/100 tox",
		"previousHp": 100,
		"hp": 82,
		"maxHp": 100,
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_badly_poisoned", "badly poisoned damage replays toxic effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "badly poisoned damage targets affected Pokemon")
	_check_equal(str(result.get("damage_target_ident", "")), "p2a: Garchomp", "badly poisoned damage still animates HP loss")

	result = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"source": "psn",
		"previousCondition": "100/100 tox",
		"condition": "94/100 tox",
		"previousHp": 100,
		"hp": 94,
		"maxHp": 100,
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_badly_poisoned", "toxic condition wins over Showdown psn damage source")


func _check_burn_damage_replays_status_effect_animation() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Garchomp",
		"source": "brn",
		"previousCondition": "100/100 brn",
		"condition": "94/100 brn",
		"previousHp": 100,
		"hp": 94,
		"maxHp": 100,
	})

	_check_equal(str(result.get("effect_animation_key", "")), "status_burned", "burn damage replays burn effect animation")
	_check_equal(str(result.get("effect_animation_target_ident", "")), "p2a: Garchomp", "burn damage targets affected Pokemon")
	_check_equal(str(result.get("damage_target_ident", "")), "p2a: Garchomp", "burn damage still animates HP loss")


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
