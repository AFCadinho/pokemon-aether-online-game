extends SceneTree

const BattleEventTextFormatterScript := preload("res://scripts/battle/battle_event_text_formatter.gd")

var formatter := BattleEventTextFormatterScript.new()
var failed := false
var localization_manager: Node
var settings_manager: Node


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	localization_manager = root.get_node_or_null("LocalizationManager")
	settings_manager = root.get_node_or_null("SettingsManager")
	_check_equal(localization_manager != null, true, "formatter check can access LocalizationManager")
	_check_equal(settings_manager != null, true, "formatter check can access SettingsManager")
	if localization_manager == null or settings_manager == null:
		quit(1)
		return
	var original_locale := str(localization_manager.get("current_locale"))
	var original_content_name_language := str(settings_manager.get("content_name_language"))
	settings_manager.set("content_name_language", "localized")
	localization_manager.call("set_locale", "en")
	_check_equal(
		formatter.format_wild_battle_start_messages("Pikachu", "Pidgey"),
		["A wild Pidgey has appeared!", "Go! Pikachu!"],
		"wild battle start messages"
	)
	_check_equal(
		formatter.format_pokemon_identity("Sparky", "Pikachu"),
		"Sparky (Pikachu)",
		"battle-log identity links nickname to species"
	)
	_check_equal(
		formatter.format_pokemon_identity("Pikachu", "Pikachu"),
		"Pikachu",
		"battle-log identity does not duplicate the species name"
	)
	_check_equal(
		formatter.format_trainer_battle_start_messages("Pikachu", "Eevee", "Gary Oak"),
		["Gary Oak wants to battle!", "Gary Oak sent out Eevee!", "Go! Pikachu!"],
		"trainer battle start messages"
	)
	_check_equal(
		formatter.format_player_switch_log_message("Pikachu", "Charizard"),
		"Pikachu, come back!\nGo! Charizard!",
		"player switch log message"
	)
	_check_equal(
		formatter.format_player_switch_battle_message("Pikachu", "Charizard"),
		"Go! Charizard!",
		"player switch battle message"
	)
	_check_equal(
		formatter.format_player_forced_switch_log_message("Pikachu", "Charizard"),
		"Go! Charizard!",
		"player forced switch log message"
	)
	_check_equal(
		formatter.format_action_prompt("Pikachu"),
		"What will Pikachu do?",
		"action prompt"
	)
	_check_equal(
		formatter.format_effectiveness_event({"effectiveness": "super"}),
		"It's super effective!",
		"super effective message"
	)
	_check_equal(
		formatter.format_effectiveness_event({"effectiveness": "resisted"}),
		"It's not very effective...",
		"resisted message"
	)
	_check_equal(
		formatter.format_stat_stage_event({"type": "statStage", "operation": "clearAll"}),
		"All stat changes were eliminated!",
		"Haze stat reset message"
	)
	_check_equal(
		formatter.format_stat_stage_event({"type": "statStage", "operation": "clear", "target": "p2a: Gholdengo"}),
		"The opposing Gholdengo's stat changes were eliminated!",
		"Clear Smog stat reset message"
	)
	_check_equal(
		formatter.format_direct_damage_message("Pikachu", 12, true, false),
		"(Pikachu lost 12.0% of its health!)",
		"direct damage message"
	)
	_check_equal(
		formatter.format_direct_damage_message("Pikachu", 0, false, true),
		"(Pikachu lost less than 1% of its health!)",
		"sub-percent damage message"
	)
	_check_equal(
		formatter.format_heal_event({"source": "Leftovers"}, "Pikachu", 50, 56, 6),
		"Pikachu restored HP using its Leftovers!",
		"leftovers heal message"
	)
	_check_equal(
		formatter.format_primal_event("Kyogre", "Kyogre-Primal"),
		"Kyogre underwent Primal Reversion into Kyogre-Primal!",
		"primal reversion message"
	)
	_check_equal(
		formatter.format_pokemon_effect_event({"target": "p1a: Gengar", "effect": "move: Substitute", "state": "start"}),
		"Gengar put in a substitute!",
		"substitute start message"
	)
	_check_equal(
		formatter.format_pokemon_effect_event({"target": "p1a: Gengar", "effect": "Substitute", "state": "activate"}),
		"The substitute took the hit for Gengar!",
		"substitute hit message"
	)
	_check_equal(
		formatter.format_pokemon_effect_event({"target": "p1a: Gengar", "effect": "Substitute", "state": "end"}),
		"Gengar's substitute faded!",
		"substitute end message"
	)
	_check_equal(
		formatter.format_status_source_ability_event({
			"target": "p2a: Landorus",
			"status": "par",
			"source": "ability: Static",
			"sourceTarget": "p1a: Zapdos",
			"sourceAbility": "Static",
		}),
		"Zapdos's Static activated!",
		"status event reports its public source ability"
	)
	_check_equal(
		formatter.format_field_effect_event({"effectType": "weather", "effect": "none", "endedEffect": "Snow", "state": "end"}),
		"The snow stopped.",
		"snow end message retains the ended weather"
	)
	_check_equal(
		formatter.format_field_effect_event({"effectType": "weather", "effect": "none", "state": "end"}),
		"The weather returned to normal.",
		"legacy weather end message never displays None ended"
	)
	localization_manager.call("set_locale", "nl")
	_check_equal(
		formatter.format_move_event("Pikachu", "Thunderbolt"),
		"Pikachu gebruikte Bliksemschicht!",
		"Dutch move event localizes the sentence and move presentation"
	)
	_check_equal(
		formatter.format_ability_event({"target": "Pikachu", "ability": "Static"}),
		"Statische Lading van Pikachu werd geactiveerd!",
		"Dutch ability event localizes ability presentation"
	)
	_check_equal(
		formatter.format_status_event({"target": "Pikachu", "status": "brn"}),
		"Pikachu liep een brandwond op!",
		"Dutch status event localizes battle grammar"
	)
	_check_equal(
		formatter.format_field_effect_event({"state": "end", "effectType": "weather", "effect": "Snow"}),
		"De sneeuw stopte.",
		"Dutch weather end uses canonical event identity after localization"
	)
	localization_manager.call("set_locale", "pt_BR")
	_check_equal(
		formatter.format_action_prompt("Pikachu"),
		"O que Pikachu fará?",
		"Portuguese action prompt localizes at runtime"
	)
	_check_equal(
		formatter.format_stat_change_event({"target": "Pikachu", "stat": "atk", "amount": 2}),
		"Ataque de Pikachu subiu muito!",
		"Portuguese stat event localizes stat and action"
	)
	localization_manager.call("set_locale", original_locale)
	settings_manager.set("content_name_language", original_content_name_language)

	quit(1 if failed else 0)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
