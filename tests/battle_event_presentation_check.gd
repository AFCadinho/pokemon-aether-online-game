extends SceneTree

const BattleEventPresentationScript := preload("res://scripts/battle/battle_event_presentation.gd")
const BattleEventTextFormatterScript := preload("res://scripts/battle/battle_event_text_formatter.gd")
const BattleHpEventHelperScript := preload("res://scripts/battle/battle_hp_event_helper.gd")
const SupremeOverlordEffectScript := preload("res://scripts/battle/battle_supreme_overlord_effect.gd")
const BattleLogPanelScript := preload("res://scripts/battle/battle_ui/battle_log_panel.gd")
const SUPER_EFFECTIVE_DAMAGE_SOUND := "res://assets/audio/sfx/battle/hit_super_effective.ogg"
const BATTLE_ANIMATION_ROUTER := "res://scripts/battle/battle_animation_router.gd"
const BATTLE_EVENT_RENDERER := "res://scripts/battle/battle_event_renderer.gd"

var failed := false


func _init() -> void:
	_check_previous_condition_uses_visible_scale()
	_check_stale_previous_condition_rewinds_from_authoritative_state()
	_check_legitimate_full_hp_rewind_is_preserved()
	_check_multihit_knockout_keeps_rendered_hp_continuity()
	_check_multihit_knockout_keeps_continuity_across_batches()
	_check_multihit_knockout_keeps_continuity_across_hp_scales()
	_check_full_hp_reveal_damage_has_no_damage_target()
	_check_real_damage_keeps_damage_target()
	_check_direct_damage_logs_one_decimal_precision()
	_check_public_damage_percent_is_preferred_over_quantized_hp_delta()
	_check_damage_after_hazard_uses_numeric_delta_when_previous_condition_is_stale()
	_check_damage_after_hazard_logs_when_conditions_repeat()
	_check_damage_after_hazard_logs_mixed_visible_and_exact_conditions()
	_check_booster_energy_quark_drive_messages()
	_check_air_balloon_messages()
	_check_consumable_item_activation_animations()
	_check_tera_shift_max_hp_sync_is_silent()
	_check_eat_berry_sheet_tile_size()
	_check_eat_berry_sheet_presentation_tuning()
	_check_future_sight_lifecycle_messages()
	_check_solar_beam_prepare_uses_charge_animation()
	_check_electro_shot_prepare_uses_charge_animation()
	_check_wish_heal_uses_delayed_animation()
	_check_protect_activation_uses_block_animation()
	_check_evasion_drop_uses_normalized_negative_amount()
	_check_paralysis_status_event_uses_status_effect_animation()
	_check_status_event_logs_public_source_ability()
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
	_check_super_effective_damage_uses_distinct_sound()
	_check_poison_damage_replays_status_effect_animation()
	_check_badly_poisoned_damage_replays_status_effect_animation()
	_check_burn_damage_replays_status_effect_animation()
	_check_z_power_event_has_visible_message()
	_check_stat_reset_events_have_visible_messages()
	_check_switch_log_uses_destination_side()
	_check_semantic_battle_log_colors()
	_check_supreme_overlord_fallen_counter_protocol()
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


func _check_super_effective_damage_uses_distinct_sound() -> void:
	var sound_stream := load(SUPER_EFFECTIVE_DAMAGE_SOUND) as AudioStream
	var router_source := FileAccess.get_file_as_string(BATTLE_ANIMATION_ROUTER)
	var renderer_source := FileAccess.get_file_as_string(BATTLE_EVENT_RENDERER)
	_check_equal(sound_stream != null, true, "trimmed super-effective hit OGG loads")
	_check_equal(
		router_source.contains('const SUPER_EFFECTIVE_DAMAGE_SOUND_PATH := "%s"' % SUPER_EFFECTIVE_DAMAGE_SOUND)
		and router_source.contains("get_damage_sound_path(sound_variant)"),
		true,
		"battle animation router resolves the super-effective hit sound"
	)
	_check_equal(
		renderer_source.contains("damage_sound_variant")
		and renderer_source.contains("play_damage_tween_for_target("),
		true,
		"damage presentation forwards its sound variant to the hit tween"
	)
	var presentation = _make_presentation()
	presentation.build({
		"type": "move",
		"actor": "p1a: Pikachu",
		"move": "Thunderbolt",
		"target": "p2a: Blastoise",
	})
	presentation.build({
		"type": "effectiveness",
		"target": "p2a: Blastoise",
		"effectiveness": "super",
	})
	var super_damage: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Blastoise",
		"previousCondition": "100/100",
		"condition": "40/100",
	})
	_check_equal(
		str(super_damage.get("damage_sound_variant", "")),
		"super_effective",
		"super-effective damage replaces the normal hit sound"
	)

	presentation.build({
		"type": "move",
		"actor": "p1a: Pikachu",
		"move": "Quick Attack",
		"target": "p2a: Blastoise",
	})
	var normal_damage: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Blastoise",
		"previousCondition": "40/100",
		"condition": "30/100",
	})
	_check_equal(
		str(normal_damage.get("damage_sound_variant", "")),
		"normal",
		"ordinary damage keeps the normal hit sound"
	)


func _check_z_power_event_has_visible_message() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "zPower",
		"target": "p1a: Pikachu",
	})

	_check_equal(
		str(result.get("battle_message", "")),
		"Pikachu surrounded itself with Z-Power!",
		"Z-Power event receives visible battle presentation"
	)


func _check_stat_reset_events_have_visible_messages() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "statStage",
		"operation": "clearAll",
	})
	_check_equal(
		str(result.get("battle_message", "")),
		"All stat changes were eliminated!",
		"Haze receives a visible all-stat reset presentation"
	)
	_check_equal(
		str(result.get("log_message", "")),
		"All stat changes were eliminated!",
		"Haze receives a battle-log all-stat reset presentation"
	)


func _check_switch_log_uses_destination_side() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "switch",
		"playerId": "p2",
		"from": "Pikipek",
		"to": "Furret",
		"toIdent": "p1a: Furret",
	})
	_check_equal(
		str(result.get("log_message", "")),
		"Pikipek, come back!\nGo! Furret!",
		"switch logs use the destination ident side when playerId is stale"
	)


func _check_semantic_battle_log_colors() -> void:
	var presentation = _make_presentation()
	var cases := [
		[{"type": "move", "actor": "p1a: Pikachu", "move": "Thunderbolt"}, "move"],
		[{"type": "switch", "playerId": "p1", "to": "Pikachu"}, "switch"],
		[{"type": "damage", "target": "p2a: Garchomp", "previousCondition": "100/100", "condition": "75/100"}, "damage"],
		[{"type": "fieldEffect", "effect": "Electric Terrain", "state": "start"}, "field"],
		[{"type": "ability", "target": "p2a: Landorus", "ability": "Intimidate"}, "effect"],
		[{"type": "status", "target": "p1a: Pikachu", "status": "par"}, "status"],
		[{"type": "effectiveness", "target": "p1a: Gholdengo", "effectiveness": "immune"}, "warning"],
		[{"type": "effectiveness", "target": "p2a: Garchomp", "effectiveness": "resisted"}, "detail"],
		[{"type": "effectiveness", "target": "p2a: Garchomp", "effectiveness": "super"}, "result"],
		[{"type": "faint", "target": "p2a: Garchomp"}, "faint"],
	]
	for test_case: Array in cases:
		var event_data: Dictionary = test_case[0] as Dictionary
		var result: Dictionary = presentation.build(event_data)
		_check_equal(
			str(result.get("log_kind", "")),
			str(test_case[1]),
			"%s event receives a semantic battle-log color" % str(event_data.get("type", ""))
		)

	var panel = BattleLogPanelScript.new()
	_check_equal(
		panel._format_line("Volledig vertaalde schademelding", "damage"),
		"[color=#ff929f]Volledig vertaalde schademelding[/color]",
		"semantic battle-log colors do not depend on English message text"
	)
	panel.free()


func _check_tera_shift_max_hp_sync_is_silent() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "heal",
		"target": "p1a: Terapagos",
		"previousCondition": "100/100",
		"condition": "100/100",
		"maxHpIncreaseSync": true,
		"silent": true,
	})
	_check_equal(str(result.get("log_message", "")), "", "Tera Shift max-HP sync has no battle-log heal")
	_check_equal(str(result.get("effect_animation_key", "")), "", "Tera Shift max-HP sync has no heal animation")
	_check_equal(str(result.get("heal_target_ident", "")), "", "Tera Shift max-HP sync has no heal target")


func _check_supreme_overlord_fallen_counter_protocol() -> void:
	_check_equal(SupremeOverlordEffectScript.get_fallen_count("fallen4"), 4, "Showdown fallen4 exposes Supreme Overlord's public count")
	_check_equal(SupremeOverlordEffectScript.get_fallen_count("fallen5"), 5, "Supreme Overlord count supports Showdown's maximum")
	_check_equal(SupremeOverlordEffectScript.get_fallen_count("fallen6"), -1, "invalid out-of-range fallen effects are ignored")

	var fallen_by_ident: Dictionary = {}
	_check_equal(SupremeOverlordEffectScript.update_fallen_by_ident(fallen_by_ident, "p1:kingambit", "fallen4", "start"), true, "fallen start event updates the indicator state")
	_check_equal(int(fallen_by_ident.get("p1:kingambit", -1)), 4, "fallen indicator starts at the Showdown count")
	SupremeOverlordEffectScript.update_fallen_by_ident(fallen_by_ident, "p1:kingambit", "fallen5", "activate")
	_check_equal(int(fallen_by_ident.get("p1:kingambit", -1)), 5, "a later Supreme Overlord activation replaces the count")
	SupremeOverlordEffectScript.update_fallen_by_ident(fallen_by_ident, "p1:kingambit", "fallen5", "end")
	_check_equal(fallen_by_ident.has("p1:kingambit"), false, "fallen end event removes the indicator state")

	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "pokemonEffect",
		"target": "p1a: Kingambit",
		"effect": "fallen4",
		"state": "start",
	})
	_check_equal(str(result.get("log_message", "")), "", "Showdown's silent fallen protocol no longer produces repetitive battle log text")


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


func _check_stale_previous_condition_rewinds_from_authoritative_state() -> void:
	var helper = BattleHpEventHelperScript.new()
	var snapshot: Dictionary = helper.get_rewind_hp_snapshot({
		"type": "damage",
		"previousCondition": "100/100",
		"condition": "42/100",
		"previousHp": 272,
		"hp": 168,
		"maxHp": 400,
	}, {})

	_check_equal(snapshot.get("hp", 0), 272, "canonical HP repairs a stale full-HP rewind without a state lookup")
	_check_equal(snapshot.get("max_hp", 0), 400, "stale rewind keeps the canonical HP scale")

	snapshot = helper.get_rewind_hp_snapshot({
		"type": "damage",
		"previousCondition": "100/100",
		"condition": "42/100",
	}, {
		"hp": 68,
		"max_hp": 100,
	})

	_check_equal(snapshot.get("hp", 0), 68, "stale full-HP rewind uses the intermediate authoritative HP")


func _check_legitimate_full_hp_rewind_is_preserved() -> void:
	var helper = BattleHpEventHelperScript.new()
	var snapshot: Dictionary = helper.get_rewind_hp_snapshot({
		"type": "damage",
		"previousCondition": "100/100",
		"condition": "68/100",
		"previousHp": 400,
		"hp": 272,
		"maxHp": 400,
	}, {
		"hp": 272,
		"max_hp": 400,
	})

	_check_equal(snapshot.get("hp", 0), 100, "a genuine full-to-damaged event still starts at full HP")


func _check_multihit_knockout_keeps_rendered_hp_continuity() -> void:
	var helper = BattleHpEventHelperScript.new()
	var events: Array = [
		{
			"type": "damage", "target": "p2a: Pidgey",
			"previousCondition": "100/100", "condition": "81/100",
			"previousHp": 16, "hp": 13, "maxHp": 16,
		},
		{
			"type": "damage", "target": "p2a: Pidgey",
			"previousCondition": "81/100", "condition": "69/100",
			"previousHp": 13, "hp": 11, "maxHp": 16,
		},
		{
			"type": "damage", "target": "p2a: Pidgey",
			"previousCondition": "69/100", "condition": "19/100",
			"previousHp": 11, "hp": 3, "maxHp": 16,
		},
		{
			"type": "damage", "target": "p2a: Pidgey",
			"previousCondition": "44/100", "condition": "0 fnt",
			"previousHp": 7, "hp": 0, "maxHp": 16,
		},
		{"type": "faint", "target": "p2a: Pidgey", "condition": "0 fnt"},
	]
	var normalized: Array = helper.normalize_damage_event_continuity(events)
	var knockout_damage: Dictionary = normalized[3] as Dictionary

	_check_equal(
		str(knockout_damage.get("previousCondition", "")),
		"19/100",
		"multi-hit knockout starts from the HP rendered by the preceding hit"
	)
	_check_equal(
		int(knockout_damage.get("previousHp", -1)),
		3,
		"multi-hit knockout keeps the exact HP cursor from the preceding hit"
	)
	_check_equal(
		str((events[3] as Dictionary).get("previousCondition", "")),
		"44/100",
		"HP continuity normalization does not mutate the response events"
	)


func _check_multihit_knockout_keeps_continuity_across_batches() -> void:
	var helper = BattleHpEventHelperScript.new()
	helper.normalize_damage_event_continuity([
		{
			"type": "damage", "target": "p2a: Pidgey",
			"pokemonKey": "p2:slot:1",
			"previousCondition": "69/100", "condition": "19/100",
			"previousHp": 11, "hp": 3, "maxHp": 16,
		},
	])
	var final_batch: Array = helper.normalize_damage_event_continuity([
		{
			"type": "damage", "target": "p2: Pidgey",
			"pokemonKey": "p2:slot:1",
			"previousCondition": "44/100", "condition": "0 fnt",
			"previousHp": 7, "hp": 0, "maxHp": 16,
		},
		{"type": "faint", "target": "p2a: Pidgey", "condition": "0 fnt"},
	])
	var knockout_damage: Dictionary = final_batch[0] as Dictionary

	_check_equal(
		str(knockout_damage.get("previousCondition", "")),
		"19/100",
		"a separately delivered final hit uses stable identity and the previously rendered HP"
	)
	_check_equal(
		int(knockout_damage.get("previousHp", -1)),
		3,
		"exact HP continuity survives a response batch boundary"
	)


func _check_multihit_knockout_keeps_continuity_across_hp_scales() -> void:
	var helper = BattleHpEventHelperScript.new()
	helper.normalize_damage_event_continuity([
		{
			"type": "damage", "target": "p2a: Pidgey",
			"previousCondition": "69/100", "condition": "19/100",
			"previousHp": 11, "hp": 3, "maxHp": 16,
		},
	])
	var final_batch: Array = helper.normalize_damage_event_continuity([
		{
			"type": "damage", "target": "p2a: Pidgey",
			"previousCondition": "44/100", "condition": "0 fnt",
			"previousHp": 44, "hp": 0, "maxHp": 100,
		},
	])
	var knockout_damage: Dictionary = final_batch[0] as Dictionary

	_check_equal(
		str(knockout_damage.get("previousCondition", "")),
		"19/100",
		"a public-scale knockout starts from the preceding exact-scale HP"
	)
	_check_equal(
		int(knockout_damage.get("previousHp", -1)),
		19,
		"cross-scale knockout rewind preserves the previously rendered percentage"
	)


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


func _check_direct_damage_logs_one_decimal_precision() -> void:
	var presentation = _make_presentation()
	presentation.build({
		"type": "move",
		"actor": "p1a: Samurott",
		"move": "Ceaseless Edge",
		"target": "p2a: Dragonite",
	})
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Dragonite",
		"previousCondition": "400/400",
		"condition": "222/400",
		"previousHp": 400,
		"hp": 222,
		"maxHp": 400,
		"amount": 178,
	})

	_check_equal(str(result.get("log_message", "")), "(Dragonite lost 44.5% of its health!)", "direct damage logs one decimal when exact HP is available")


func _check_public_damage_percent_is_preferred_over_quantized_hp_delta() -> void:
	var presentation = _make_presentation()
	presentation.build({
		"type": "move",
		"actor": "p1a: Samurott",
		"move": "Knock Off",
		"target": "p2a: Heatran",
	})
	var result: Dictionary = presentation.build({
		"type": "damage",
		"target": "p2a: Heatran",
		"previousCondition": "100/100",
		"condition": "73/100",
		"previousHp": 100,
		"hp": 73,
		"maxHp": 100,
		"damagePercent": 27.9,
	})

	_check_equal(str(result.get("log_message", "")), "(Heatran lost 27.9% of its health!)", "public exact damage percent overrides quantized HP delta")


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

	_check_equal(str(result.get("log_message", "")), "(Charizard lost 30.0% of its health!)", "damage after hazard ignores stale previous condition")


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

	_check_equal(str(result.get("log_message", "")), "(Charizard lost 30.0% of its health!)", "damage after hazard logs repeated-condition numeric loss")


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

	_check_equal(str(result.get("log_message", "")), "(Alomomola lost 34.0% of its health!)", "damage after hazard logs visible delta before exact HP reveal")


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

func _check_air_balloon_messages() -> void:
	var presentation = _make_presentation()
	var reveal_result: Dictionary = presentation.build({
		"type": "item",
		"target": "p2a: Wailord",
		"item": "Air Balloon",
		"state": "start",
	})
	var popped_result: Dictionary = presentation.build({
		"type": "item",
		"target": "p2a: Wailord",
		"item": "Air Balloon",
		"state": "end",
	})

	_check_equal(str(reveal_result.get("log_message", "")), "Wailord floats in the air with its Air Balloon!", "Air Balloon reveal logs")
	_check_equal(str(reveal_result.get("battle_message", "")), "Wailord floats in the air with its Air Balloon!", "Air Balloon reveal uses battle text")
	_check_equal(str(popped_result.get("battle_message", "")), "Wailord's Air Balloon popped!", "Air Balloon end uses battle text")


func _check_consumable_item_activation_animations() -> void:
	var presentation = _make_presentation()
	var cases := [
		[{"type": "item", "target": "p1a: Ferrothorn", "item": "Eject Button", "state": "end"}, "use_item", "Eject Button uses the generic consumable animation"],
		[{"type": "item", "target": "p2a: Alakazam", "item": "Focus Sash", "state": "end"}, "use_item", "Focus Sash uses the generic consumable animation"],
		[{"type": "item", "target": "p1a: Tapu Fini", "item": "Sitrus Berry", "state": "end"}, "eat_berry", "Sitrus Berry uses the berry animation"],
		[{"type": "item", "target": "p1a: Garchomp", "item": "Shuca Berry", "state": "end"}, "eat_berry", "Shuca Berry uses the berry animation"],
	]
	for test_case: Array in cases:
		var event_data: Dictionary = test_case[0] as Dictionary
		var result: Dictionary = presentation.build(event_data)
		_check_equal(str(result.get("effect_animation_key", "")), str(test_case[1]), str(test_case[2]))
		_check_equal(str(result.get("effect_animation_target_ident", "")), str(event_data.get("target", "")), "%s targets its holder" % str(test_case[2]))
		var preload_keys: Dictionary = presentation.get_animation_preload_keys_for_event(event_data)
		_check_equal((preload_keys.get("effect_keys", []) as Array).has(str(test_case[1])), true, "%s is prewarmed before presentation" % str(test_case[2]))

	var knocked_off := presentation.build({
		"type": "item",
		"target": "p1a: Ferrothorn",
		"item": "Eject Button",
		"state": "end",
		"source": "move: Knock Off",
	})
	_check_equal(str(knocked_off.get("effect_animation_key", "")), "", "Knock Off does not look like an item activation")

	var balloon := presentation.build({
		"type": "item",
		"target": "p2a: Wailord",
		"item": "Air Balloon",
		"state": "end",
	})
	_check_equal(str(balloon.get("effect_animation_key", "")), "", "Air Balloon pop keeps its dedicated presentation")


func _check_eat_berry_sheet_tile_size() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://assets/battles/animations/common/eatberry/eatberry.json"
	))
	_check_equal(parsed is Dictionary, true, "Eat Berry animation data is readable")
	if not parsed is Dictionary:
		return
	var tile_size: Variant = (parsed as Dictionary).get("tile_size", [])
	_check_equal(tile_size, [192.0, 192.0], "GEN8 Eat Berry sheet uses complete 192px cells")


func _check_eat_berry_sheet_presentation_tuning() -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(
		"res://data/battle_effect_animations.json"
	))
	_check_equal(parsed is Dictionary, true, "battle effect animation catalog is readable")
	if not parsed is Dictionary:
		return
	var effects: Variant = (parsed as Dictionary).get("effects", {})
	_check_equal(effects is Dictionary, true, "battle effect animation catalog has effects")
	if not effects is Dictionary:
		return
	var berry_effect: Variant = (effects as Dictionary).get("eat_berry", {})
	_check_equal(berry_effect is Dictionary, true, "Eat Berry has a catalog entry")
	if not berry_effect is Dictionary:
		return
	var config: Dictionary = berry_effect as Dictionary
	_check_equal(float(config.get("sprite_zoom_multiplier", 0.0)), 0.6, "Eat Berry scales its imported 150 percent source down for battle presentation")
	_check_equal(config.get("sheet_visual_offset", []), [-104.0, 19.0], "Eat Berry centers its fixed source coordinates on the holder")
	_check_equal(int(config.get("animation_end_frame", -1)), 9, "Eat Berry presents one bite cycle instead of replaying the imported sequence")


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


func _check_status_event_logs_public_source_ability() -> void:
	var presentation = _make_presentation()
	var result: Dictionary = presentation.build({
		"type": "status",
		"target": "p2a: Landorus",
		"status": "par",
		"source": "ability: Static",
		"sourceTarget": "p1a: Zapdos",
		"sourceAbility": "Static",
	})

	_check_equal(
		str(result.get("pre_log_message", "")),
		"Zapdos's Static activated!",
		"status presentation logs its public source ability before the condition"
	)
	_check_equal(
		str(result.get("log_message", "")),
		"The opposing Landorus was paralyzed!",
		"status presentation retains the affected Pokemon message"
	)


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
