extends RefCounted

class_name BattleEventPresentation

var event_text_formatter: BattleEventTextFormatter
var hp_event_helper: BattleHpEventHelper
var format_actor: Callable
var get_player_display_name: Callable
var get_pokemon_species: Callable
var recent_field_effect_source := ""
var recent_ability_event := false
var recent_move_event := false
var active_residual_pokemon_effects := {}
var pending_damage_effectiveness_by_target := {}


func setup(
	formatter: BattleEventTextFormatter,
	hp_helper: BattleHpEventHelper,
	format_actor_callback: Callable,
	player_display_name_callback: Callable,
	pokemon_species_callback: Callable = Callable()
) -> void:
	event_text_formatter = formatter
	hp_event_helper = hp_helper
	format_actor = format_actor_callback
	get_player_display_name = player_display_name_callback
	get_pokemon_species = pokemon_species_callback


func reset() -> void:
	reset_recent_context()
	active_residual_pokemon_effects.clear()


func reset_recent_context() -> void:
	recent_field_effect_source = ""
	recent_ability_event = false
	recent_move_event = false
	pending_damage_effectiveness_by_target.clear()


func get_animation_preload_keys_for_event(event_data: Dictionary) -> Dictionary:
	var move_names: Array[String] = []
	var effect_keys: Array[String] = []
	var needs_damage_sound: bool = false

	match str(event_data.get("type", "")):
		"prepare":
			var prepared_move := str(event_data.get("move", ""))
			var prepare_effect_key := _get_prepare_effect_animation_key(prepared_move)
			if prepare_effect_key != "":
				effect_keys.append(prepare_effect_key)
		"move":
			var move_name: String = str(event_data.get("move", ""))
			if move_name != "":
				move_names.append(move_name)
		"ability":
			if _is_tera_shift_event(event_data):
				effect_keys.append("tera_shift")
		"fieldEffect":
			var field_effect_key: String = _get_field_effect_animation_key(event_data)
			if field_effect_key != "":
				effect_keys.append(field_effect_key)
		"item":
			var item_effect_key: String = _get_consumable_item_activation_animation_key(event_data)
			if item_effect_key != "":
				effect_keys.append(item_effect_key)
		"heal":
			if not bool(event_data.get("maxHpIncreaseSync", false)) and not bool(event_data.get("silent", false)):
				var heal_effect_key: String = _get_heal_effect_animation_key(event_data)
				if heal_effect_key != "":
					effect_keys.append(heal_effect_key)
				var heal_followup_effect_key: String = _get_heal_followup_effect_animation_key(event_data)
				if heal_followup_effect_key != "":
					effect_keys.append(heal_followup_effect_key)
		"statChange":
			var stat_effect_key: String = _get_stat_change_effect_animation_key(event_text_formatter.get_stat_change_amount(event_data))
			if stat_effect_key != "":
				effect_keys.append(stat_effect_key)
		"status":
			var status_effect_key: String = _get_status_condition_effect_animation_key(event_data)
			if status_effect_key != "":
				effect_keys.append(status_effect_key)
		"pokemonEffect":
			var pokemon_effect_key: String = _get_pokemon_effect_animation_key(event_data)
			if pokemon_effect_key != "":
				effect_keys.append(pokemon_effect_key)
			if _is_tera_shift_event(event_data):
				effect_keys.append("tera_shift")
		"cant":
			var cant_effect_key: String = _get_cant_status_effect_animation_key(event_data)
			if cant_effect_key != "":
				effect_keys.append(cant_effect_key)
		"formeChange":
			if _is_battle_bond_visual_transformation(event_data):
				effect_keys.append("mega_evolution")
		"mega", "primal":
			effect_keys.append("mega_evolution")
		"zPower":
			effect_keys.append("z_power")
		"damage":
			var damage_effect_key: String = _get_residual_status_damage_effect_animation_key(event_data)
			if damage_effect_key != "":
				effect_keys.append(damage_effect_key)
			needs_damage_sound = hp_event_helper.event_has_hp_loss(event_data) or hp_event_helper.event_has_sub_percent_hp_loss(event_data)

	return {
		"move_names": move_names,
		"effect_keys": effect_keys,
		"needs_damage_sound": needs_damage_sound,
	}


func build(event_data: Dictionary) -> Dictionary:
	var event_type := str(event_data.get("type", ""))
	var presentation := _new_presentation()

	match event_type:
		"prepare":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var prepare_actor := _format_actor(str(event_data.get("actor", "")))
			var prepared_move := str(event_data.get("move", ""))
			var prepare_effect_key := _get_prepare_effect_animation_key(prepared_move)
			if prepare_actor != "" and prepared_move != "":
				if prepare_effect_key == "solar_beam_charge":
					presentation["log_message"] = "%s is absorbing light!" % prepare_actor
				elif prepare_effect_key == "electro_shot_charge":
					presentation["log_message"] = "%s is charging electricity!" % prepare_actor
				else:
					presentation["log_message"] = "%s is preparing %s!" % [prepare_actor, prepared_move]
				presentation["battle_message"] = str(presentation["log_message"])
			presentation["effect_animation_key"] = prepare_effect_key
			presentation["effect_animation_target_ident"] = str(event_data.get("actor", ""))
		"move":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = true
			pending_damage_effectiveness_by_target.clear()
			presentation["attack_actor_ident"] = str(event_data.get("actor", ""))
			var actor_ident := str(event_data.get("actor", ""))
			var actor := _format_actor(actor_ident)
			var log_actor := _format_log_pokemon_identity(
				event_data,
				actor_ident,
				["actorRef", "actor_ref"],
				["actorSpecies"]
			)
			var move_name := str(event_data.get("move", ""))
			presentation["move_animation_name"] = move_name
			presentation["move_animation_actor_ident"] = str(event_data.get("actor", ""))
			presentation["move_animation_target_ident"] = str(event_data.get("target", ""))
			presentation["pre_log_message"] = event_text_formatter.format_move_source_message(event_data, log_actor)
			if str(presentation["pre_log_message"]) != "":
				presentation["battle_message"] = event_text_formatter.format_move_source_message(event_data, actor)
				presentation["attack_actor_ident"] = ""
			else:
				presentation["log_message"] = event_text_formatter.format_move_event(log_actor, move_name)
				presentation["battle_message"] = event_text_formatter.format_move_event(actor, move_name)

		"switch", "drag":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var player_id := _get_switch_player_id(event_data)
			var from_name := str(event_data.get("from", ""))
			var to_name := str(event_data.get("to", ""))
			var forced_switch := bool(event_data.get("forced", false)) or str(event_data.get("type", "")) == "drag"

			if to_name == "":
				to_name = _format_actor(str(event_data.get("toIdent", "")), false)
			if to_name == "":
				to_name = _format_actor(str(event_data.get("pokemon", "")), false)
			if to_name == "":
				to_name = ""
			var from_log_name := (
				event_text_formatter.format_pokemon_identity(
					from_name,
					_get_switch_ref_species(event_data, "fromRef")
				)
				if from_name.strip_edges() != ""
				else ""
			)
			var to_log_name := event_text_formatter.format_pokemon_identity(
				to_name,
				_get_switch_ref_species(event_data, "toRef")
			)
			if player_id == "p1":
				if forced_switch:
					presentation["log_message"] = event_text_formatter.format_player_forced_switch_log_message(from_log_name, to_log_name)
					presentation["battle_message"] = event_text_formatter.format_player_forced_switch_battle_message(from_name, to_name)
				else:
					presentation["log_message"] = event_text_formatter.format_player_switch_log_message(from_log_name, to_log_name)
					presentation["battle_message"] = event_text_formatter.format_player_switch_battle_message(from_name, to_name)
			else:
				var trainer_name := _get_player_display_name(player_id)
				if forced_switch:
					presentation["log_message"] = event_text_formatter.format_opponent_forced_switch_log_message(trainer_name, from_log_name, to_log_name)
					presentation["battle_message"] = event_text_formatter.format_opponent_forced_switch_battle_message(trainer_name, to_name)
				else:
					presentation["log_message"] = event_text_formatter.format_opponent_switch_log_message(trainer_name, from_log_name, to_log_name)
					presentation["battle_message"] = event_text_formatter.format_opponent_switch_battle_message(trainer_name, to_name)
			presentation["add_blank_after"] = true

		"faint":
			recent_ability_event = false
			recent_move_event = false
			presentation["faint_target_ident"] = str(event_data.get("target", ""))
			var target := _format_actor(str(presentation["faint_target_ident"]))
			presentation["log_message"] = event_text_formatter.format_faint_event(target)
			presentation["add_blank_after"] = true

		"win":
			recent_ability_event = false
			recent_move_event = false
			var winner := str(event_data.get("winner", ""))
			presentation["log_message"] = event_text_formatter.format_win_event(winner)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = true

		"capture":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			presentation["log_message"] = event_text_formatter.format_capture_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = true

		"transform":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var actor := _format_actor(str(event_data.get("target", "")))
			var species := str(event_data.get("species", ""))
			presentation["log_message"] = event_text_formatter.format_transform_event(actor, species)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"formeChange":
			if _is_battle_bond_visual_transformation(event_data):
				recent_field_effect_source = ""
				recent_ability_event = false
				recent_move_event = false
				presentation["effect_animation_key"] = "mega_evolution"
				presentation["effect_animation_target_ident"] = str(event_data.get("target", ""))

		"mega":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var actor := _format_actor(str(event_data.get("target", "")))
			var species := str(event_data.get("species", ""))
			presentation["log_message"] = event_text_formatter.format_mega_event(actor, species)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			presentation["effect_animation_key"] = "mega_evolution"
			presentation["effect_animation_target_ident"] = str(event_data.get("target", ""))

		"zPower":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var actor := _format_actor(str(event_data.get("target", "")))
			if actor != "":
				presentation["log_message"] = "%s surrounded itself with Z-Power!" % actor
				presentation["battle_message"] = str(presentation["log_message"])
				presentation["add_blank_after"] = true
			presentation["effect_animation_key"] = "z_power"
			presentation["effect_animation_target_ident"] = str(event_data.get("target", ""))

		"primal":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var actor := _format_actor(str(event_data.get("target", "")))
			var species := str(event_data.get("species", ""))
			presentation["log_message"] = event_text_formatter.format_primal_event(actor, species)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			presentation["effect_animation_key"] = "mega_evolution"
			presentation["effect_animation_target_ident"] = str(event_data.get("target", ""))

		"item":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var actor := _format_actor(str(event_data.get("target", "")))
			var item_name := str(event_data.get("item", "")).strip_edges()
			presentation["effect_animation_key"] = _get_consumable_item_activation_animation_key(event_data)
			presentation["effect_animation_target_ident"] = str(event_data.get("target", ""))
			if actor != "" and item_name != "":
				presentation["log_message"] = event_text_formatter.format_item_event(
					event_data,
					actor,
					_is_knock_off_item_end_event(event_data),
				)
				presentation["battle_message"] = str(presentation["log_message"])
				presentation["add_blank_after"] = true

		"fieldEffect":
			recent_ability_event = false
			recent_move_event = false
			presentation["log_message"] = event_text_formatter.format_field_effect_event(event_data)
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			presentation["effect_animation_key"] = _get_field_effect_animation_key(event_data)
			presentation["effect_animation_target_ident"] = str(event_data.get("sourceTarget", event_data.get("sourcePokemon", "")))
			recent_field_effect_source = str(event_data.get("effect", ""))

		"pokemonEffect":
			recent_ability_event = false
			recent_move_event = false
			_track_pokemon_effect_event(event_data)
			presentation["effect_animation_key"] = _get_pokemon_effect_animation_key(event_data)
			if _is_tera_shift_event(event_data):
				presentation["effect_animation_key"] = "tera_shift"
			presentation["effect_animation_target_ident"] = str(event_data.get("target", event_data.get("pokemon", "")))
			presentation["log_message"] = event_text_formatter.format_pokemon_effect_event(event_data)
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"ability":
			recent_field_effect_source = ""
			recent_move_event = false
			presentation["log_message"] = event_text_formatter.format_ability_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			if _is_tera_shift_event(event_data):
				presentation["effect_animation_key"] = "tera_shift"
				presentation["effect_animation_target_ident"] = str(event_data.get("target", event_data.get("actor", "")))
			if event_text_formatter.is_ability_boost_event(event_data):
				presentation["ability_boost_target_ident"] = str(event_data.get("target", event_data.get("actor", "")))
			recent_ability_event = str(presentation["log_message"]) != ""

		"statChange":
			recent_move_event = false
			presentation["stat_change_target_ident"] = str(event_data.get("target", ""))
			presentation["stat_change_amount"] = event_text_formatter.get_stat_change_amount(event_data)
			presentation["effect_animation_key"] = _get_stat_change_effect_animation_key(int(presentation["stat_change_amount"]))
			presentation["effect_animation_target_ident"] = str(presentation["stat_change_target_ident"])
			var is_ability_detail := recent_ability_event or event_text_formatter.is_stat_change_from_ability(event_data)
			presentation["log_message"] = event_text_formatter.format_stat_change_event(event_data, is_ability_detail)
			presentation["battle_message"] = event_text_formatter.format_stat_change_battle_message(event_data)
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			presentation["suppress_player_gap"] = is_ability_detail

		"statStage":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			presentation["log_message"] = event_text_formatter.format_stat_stage_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"status":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			presentation["effect_animation_key"] = _get_status_condition_effect_animation_key(event_data)
			presentation["effect_animation_target_ident"] = str(event_data.get("target", event_data.get("pokemon", "")))
			presentation["pre_log_message"] = event_text_formatter.format_status_source_ability_event(event_data)
			presentation["log_message"] = event_text_formatter.format_status_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"fail":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			presentation["log_message"] = event_text_formatter.format_fail_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"cant":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			presentation["effect_animation_key"] = _get_cant_status_effect_animation_key(event_data)
			presentation["effect_animation_target_ident"] = str(event_data.get("actor", event_data.get("target", "")))
			presentation["log_message"] = event_text_formatter.format_cant_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"miss":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			presentation["log_message"] = event_text_formatter.format_miss_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"effectiveness":
			recent_ability_event = false
			var effectiveness_target := str(event_data.get("target", ""))
			if str(event_data.get("effectiveness", "")) == "super" and not effectiveness_target.is_empty():
				pending_damage_effectiveness_by_target[effectiveness_target] = "super_effective"
			else:
				pending_damage_effectiveness_by_target.erase(effectiveness_target)
			presentation["log_message"] = event_text_formatter.format_effectiveness_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"hitCount":
			recent_ability_event = false
			recent_move_event = false
			presentation["log_message"] = event_text_formatter.format_hit_count_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"criticalHit":
			recent_ability_event = false
			presentation["log_message"] = event_text_formatter.format_critical_hit_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"turn":
			presentation["turn"] = int(event_data.get("turn", 0))
			recent_ability_event = false
			recent_move_event = false

		"damage":
			recent_ability_event = false
			var damage_target_ident := str(event_data.get("target", ""))
			presentation["damage_sound_variant"] = str(
				pending_damage_effectiveness_by_target.get(damage_target_ident, "normal")
			)
			pending_damage_effectiveness_by_target.erase(damage_target_ident)
			var has_hp_loss: bool = hp_event_helper.event_has_hp_loss(event_data)
			var has_sub_percent_hp_loss: bool = hp_event_helper.event_has_sub_percent_hp_loss(event_data)
			var damage_percent: float = hp_event_helper.get_event_damage_percent(event_data)
			if not has_hp_loss and not has_sub_percent_hp_loss:
				recent_field_effect_source = ""
			else:
				presentation["damage_target_ident"] = damage_target_ident
				presentation["effect_animation_key"] = _get_residual_status_damage_effect_animation_key(event_data)
				if str(presentation["effect_animation_key"]) != "":
					presentation["effect_animation_target_ident"] = damage_target_ident
				var target := _format_actor(str(presentation["damage_target_ident"]))
				var log_target := _format_log_pokemon_identity(
					event_data,
					str(presentation["damage_target_ident"]),
					["targetRef", "target_ref"],
					["targetSpecies", "species"]
				)
				var active_effect := ""
				if not recent_move_event:
					active_effect = _get_active_residual_pokemon_effect(str(presentation["damage_target_ident"]))
				var source_message := event_text_formatter.format_indirect_damage_message(
					event_data,
					log_target,
					recent_field_effect_source,
					active_effect,
					not recent_move_event
				)

				if source_message != "" and (has_hp_loss or has_sub_percent_hp_loss):
					presentation["log_message"] = source_message
					if event_text_formatter.should_show_indirect_damage_in_battle_text(event_data):
						presentation["battle_message"] = event_text_formatter.format_indirect_damage_message(
							event_data,
							target,
							recent_field_effect_source,
							active_effect,
							not recent_move_event
						)
				else:
					presentation["log_message"] = event_text_formatter.format_direct_damage_message(
						log_target,
						damage_percent,
						has_hp_loss,
						has_sub_percent_hp_loss
					)
					if str(presentation["log_message"]) == "":
						presentation["damage_target_ident"] = ""

				presentation["add_blank_after"] = str(presentation["log_message"]) != ""
				recent_field_effect_source = ""
				recent_move_event = false

		"heal":
			recent_ability_event = false
			recent_move_event = false
			if bool(event_data.get("maxHpIncreaseSync", false)) or bool(event_data.get("silent", false)):
				return presentation
			presentation["heal_target_ident"] = str(event_data.get("target", ""))
			presentation["effect_animation_key"] = _get_heal_effect_animation_key(event_data)
			presentation["heal_followup_effect_animation_key"] = _get_heal_followup_effect_animation_key(event_data)
			presentation["effect_animation_target_ident"] = str(presentation["heal_target_ident"])
			var target := _format_actor(str(presentation["heal_target_ident"]))
			var previous_hp := int(event_data.get("previousHp", 0))
			var hp := int(event_data.get("hp", 0))
			presentation["log_message"] = event_text_formatter.format_heal_event(
				event_data,
				target,
				previous_hp,
				hp,
				hp_event_helper.get_event_visible_hp_change(event_data)
			)
			presentation["battle_message"] = event_text_formatter.format_heal_battle_message(event_data, target, previous_hp, hp)
			presentation["add_blank_after"] = true
			recent_field_effect_source = ""

		_:
			recent_ability_event = false
			recent_move_event = false

	_assign_log_kinds(presentation, event_data)
	return presentation

func _get_switch_ref_species(event_data: Dictionary, ref_key: String) -> String:
	return _get_event_ref_species(event_data, [ref_key])


func _format_log_pokemon_identity(
	event_data: Dictionary,
	ident: String,
	ref_keys: Array,
	species_keys: Array = []
	) -> String:
	var display_name := _format_actor(ident, false)
	var species := _get_event_ref_species(event_data, ref_keys)
	if species == "":
		for key_value: Variant in species_keys:
			var value := str(event_data.get(str(key_value), "")).strip_edges()
			if value != "":
				species = value
				break
	if species == "" and get_pokemon_species.is_valid():
		species = str(get_pokemon_species.call(ident)).strip_edges()

	var identity := event_text_formatter.format_pokemon_identity(display_name, species)
	if _get_player_id_from_battle_ident(ident) == "p2" and identity != "":
		return _format_actor("p2a: %s" % identity)
	return identity


func _get_event_ref_species(event_data: Dictionary, ref_keys: Array) -> String:
	for key_value: Variant in ref_keys:
		var ref_value: Variant = event_data.get(str(key_value), {})
		if not (ref_value is Dictionary):
			continue
		var ref: Dictionary = ref_value as Dictionary
		var species := str(ref.get("displaySpecies", ref.get("species", ""))).strip_edges()
		if species != "":
			return species
	return ""


func _assign_log_kinds(presentation: Dictionary, event_data: Dictionary) -> void:
	var event_type := str(event_data.get("type", ""))
	var kind := _get_log_kind(event_type, event_data)
	presentation["log_kind"] = kind
	presentation["pre_log_kind"] = "effect" if event_type == "move" else kind


func _get_log_kind(event_type: String, event_data: Dictionary) -> String:
	match event_type:
		"move", "prepare":
			return "move"
		"switch", "drag":
			return "switch"
		"damage":
			return "damage"
		"heal":
			return "heal"
		"fieldEffect":
			return "field"
		"ability", "item", "pokemonEffect", "statChange", "transform", "mega", "primal", "formeChange", "zPower":
			return "effect"
		"status":
			return "status"
		"fail", "cant", "miss", "criticalHit":
			return "warning"
		"effectiveness":
			match str(event_data.get("effectiveness", "")):
				"super":
					return "result"
				"resisted":
					return "detail"
				"immune":
					return "warning"
		"faint":
			return "faint"
		"win":
			return "result"
	return ""


func _is_tera_shift_event(event_data: Dictionary) -> bool:
	var ability := str(event_data.get("ability", event_data.get("abilityName", "")))
	var effect := str(event_data.get("effect", ""))
	var normalized_ability := ability.to_lower().replace(" ", "").replace("-", "").replace("_", "")
	var normalized_effect := effect.to_lower().replace(" ", "").replace("-", "").replace("_", "")
	return normalized_ability == "terashift" or normalized_effect.ends_with("terashift")


func _is_battle_bond_visual_transformation(event_data: Dictionary) -> bool:
	if not bool(event_data.get("cosmeticOnly", false)):
		return false
	var species := _normalize_animation_key(str(event_data.get("species", "")))
	var source := str(event_data.get("source", "")).to_lower()
	source = source.replace(" ", "").replace("-", "").replace("_", "").replace(":", "")
	return species == "greninja_ash" and source == "abilitybattlebond"


func _new_presentation() -> Dictionary:
	return {
		"pre_log_message": "",
		"pre_log_kind": "",
		"log_message": "",
		"log_kind": "",
		"battle_message": "",
		"add_blank_after": false,
		"suppress_player_gap": false,
		"attack_actor_ident": "",
		"move_animation_name": "",
		"move_animation_actor_ident": "",
		"move_animation_target_ident": "",
		"move_animation_result": "",
		"damage_target_ident": "",
		"damage_sound_variant": "normal",
		"heal_target_ident": "",
		"heal_followup_effect_animation_key": "",
		"faint_target_ident": "",
		"stat_change_target_ident": "",
		"stat_change_amount": 0,
		"ability_boost_target_ident": "",
		"effect_animation_key": "",
		"effect_animation_target_ident": "",
		"turn": 0,
	}


func _get_stat_change_effect_animation_key(amount: int) -> String:
	if amount > 0:
		return "stat_up"
	if amount < 0:
		return "stat_down"
	return ""


func _get_prepare_effect_animation_key(move_name: String) -> String:
	if _normalize_animation_key(move_name) in ["solarbeam", "solar_beam"]:
		return "solar_beam_charge"
	if _normalize_animation_key(move_name) in ["electroshot", "electro_shot"]:
		return "electro_shot_charge"
	return ""


func _get_field_effect_animation_key(event: Dictionary) -> String:
	var state: String = str(event.get("state", "")).strip_edges().to_lower()
	if state != "start" and state != "activate":
		return ""

	var effect_key: String = _normalize_animation_key(str(event.get("effect", "")))
	match effect_key:
		"grassyterrain", "grassy_terrain":
			return "grassy_terrain_start"

	return ""


func _get_consumable_item_activation_animation_key(event: Dictionary) -> String:
	if str(event.get("state", "")).strip_edges().to_lower() != "end":
		return ""
	if _is_knock_off_item_end_event(event):
		return ""

	var item_key := _normalize_item_key(str(event.get("item", "")))
	# Air Balloon has its own pop message. It is removed rather than activated,
	# so it must not look like a consumable held-item trigger.
	if item_key == "" or item_key == "airballoon":
		return ""

	# A move such as Fling, Bug Bite, or Pluck consumes/removes an item as part
	# of that move's presentation; do not play a second passive-item animation.
	var source_key := _normalize_item_key(str(event.get("source", "")))
	if source_key.begins_with("move"):
		return ""

	if item_key.ends_with("berry"):
		return "eat_berry"
	return "use_item"


func _get_heal_effect_animation_key(event: Dictionary) -> String:
	for source_field in ["source", "effect", "from", "fromMove", "move", "reason", "moveName", "moveId"]:
		if _is_wish_effect(str(event.get(source_field, ""))):
			return "wish_fulfilled"

	var source_key: String = _normalize_animation_key(str(event.get("source", "")))
	match source_key:
		"leftovers":
			return "leftovers_recovery"
		"grassyterrain", "grassy_terrain":
			return "grassy_terrain_heal"
		"aquaring", "aqua_ring":
			return "aqua_ring_heal"
		"leechseed", "leech_seed":
			return "leech_seed_heal"
		"recover":
			return "recover_heal"

	return "generic_heal"


func _get_heal_followup_effect_animation_key(event: Dictionary) -> String:
	for source_field in ["source", "effect", "from", "fromMove", "move", "reason", "moveName", "moveId"]:
		if _is_wish_effect(str(event.get(source_field, ""))):
			return "generic_heal"

	return ""


func _is_wish_effect(raw_effect: String) -> bool:
	var normalized := raw_effect.strip_edges().to_lower()
	if normalized.begins_with("[from] "):
		normalized = normalized.substr("[from] ".length()).strip_edges()
	if normalized.begins_with("move:"):
		normalized = normalized.substr("move:".length()).strip_edges()
	return normalized.replace(" ", "").replace("-", "").replace("_", "") == "wish"


func _get_status_condition_effect_animation_key(event: Dictionary) -> String:
	var state := str(event.get("state", "start")).strip_edges().to_lower()
	if state == "end" or state == "cure" or state == "cured":
		return ""

	var status_key := _normalize_animation_key(str(event.get("status", event.get("condition", ""))))
	match status_key:
		"par", "paralysis", "paralyzed":
			return "status_paralysis"
		"psn", "poison", "poisoned":
			return "status_poisoned"
		"tox", "toxic", "badlypoisoned", "toxicpoison":
			return "status_badly_poisoned"
		"brn", "burn", "burned":
			return "status_burned"
		"frz", "freeze", "frozen":
			return "status_frozen"
		"slp", "sleep", "sleeping", "asleep":
			return "status_sleeping"

	return ""


func _get_cant_status_effect_animation_key(event: Dictionary) -> String:
	var reason_key := _normalize_animation_key(str(event.get("reason", event.get("source", ""))))
	match reason_key:
		"par", "paralysis", "paralyzed":
			return "status_paralysis"
		"frz", "freeze", "frozen":
			return "status_frozen"
		"slp", "sleep", "sleeping", "asleep":
			return "status_sleeping"

	return ""


func _get_pokemon_effect_animation_key(event: Dictionary) -> String:
	var state := str(event.get("state", "start")).strip_edges().to_lower()
	var raw_effect := str(event.get("effect", ""))
	if event_text_formatter._is_protect_effect(raw_effect):
		if state == "activate":
			return "protect_block"
		return ""

	# Future Sight plays its setup as the move animation. Showdown emits the
	# delayed hit separately as a pokemonEffect, so only its activation gets the
	# target-centered impact animation.
	if event_text_formatter._is_future_sight_effect(raw_effect):
		if state == "activate" or state == "end":
			return "future_sight_impact"
		return ""

	if state == "end" or state == "cure" or state == "cured":
		return ""

	var effect_key := _normalize_animation_key(raw_effect)
	match effect_key:
		"confusion", "confused":
			return "status_confused"

	return ""


func _get_residual_status_damage_effect_animation_key(event: Dictionary) -> String:
	for source_field in ["source", "effect", "from", "fromMove", "move"]:
		if event_text_formatter._is_future_sight_effect(str(event.get(source_field, ""))):
			return "future_sight_impact"

	var source_key := _normalize_animation_key(str(event.get("source", "")))
	match source_key:
		"psn", "poison", "poisoned":
			var condition_status_key := _normalize_animation_key(hp_event_helper.get_event_status(event, false))
			if condition_status_key in ["tox", "toxic", "badlypoisoned", "toxicpoison"]:
				return "status_badly_poisoned"
			return "status_poisoned"
		"tox", "toxic", "badlypoisoned", "toxicpoison":
			return "status_badly_poisoned"
		"brn", "burn", "burned":
			return "status_burned"

	return ""


func _track_pokemon_effect_event(event: Dictionary) -> void:
	var target_key := _get_pokemon_effect_target_key(event)
	var effect := event_text_formatter.format_pokemon_effect_name(str(event.get("effect", "")))
	if target_key == "" or not event_text_formatter.is_trapping_pokemon_effect(effect):
		return

	match str(event.get("state", "")).to_lower():
		"start", "activate":
			active_residual_pokemon_effects[target_key] = effect
		"end":
			active_residual_pokemon_effects.erase(target_key)


func _get_pokemon_effect_target_key(event: Dictionary) -> String:
	return _normalize_battle_ident(str(event.get("target", event.get("pokemon", ""))))


func _get_active_residual_pokemon_effect(target_ident: String) -> String:
	var target_key := _normalize_battle_ident(target_ident)
	if target_key == "":
		return ""

	return str(active_residual_pokemon_effects.get(target_key, ""))


func _normalize_battle_ident(ident: String) -> String:
	var cleaned := ident.strip_edges()
	if cleaned.contains(": "):
		var player_id := cleaned.split(": ")[0].substr(0, 2)
		var pokemon_name := cleaned.split(": ")[1]
		return "%s:%s" % [player_id, pokemon_name.to_lower()]

	return cleaned.to_lower()


func _normalize_animation_key(value: String) -> String:
	return value.strip_edges().to_lower().replace(" ", "_").replace("-", "_")


func _is_knock_off_item_end_event(event: Dictionary) -> bool:
	return _normalize_item_key(str(event.get("source", ""))) == "moveknockoff"


func _normalize_item_key(item_name: String) -> String:
	return item_name.to_lower().replace(" ", "").replace("-", "").replace("_", "").replace("'", "").replace(":", "")


func _format_actor(actor: String, include_side_prefix := true) -> String:
	if format_actor.is_valid():
		return str(format_actor.call(actor, include_side_prefix))

	return actor


func _get_player_display_name(player_id: String) -> String:
	if get_player_display_name.is_valid():
		return str(get_player_display_name.call(player_id))

	return player_id


func _get_switch_player_id(event: Dictionary) -> String:
	# The destination ident is the authoritative side for a switch. Some
	# recovery/synthetic projections omit playerId, and a stale playerId must not
	# turn the local player's replacement into an opponent switch in the log.
	for key in ["toIdent", "target", "pokemon", "ident"]:
		var player_id := _get_player_id_from_battle_ident(str(event.get(key, "")))
		if player_id != "":
			return player_id
	var declared_player_id := str(event.get("playerId", "")).strip_edges()
	return declared_player_id if declared_player_id in ["p1", "p2"] else ""


func _get_player_id_from_battle_ident(ident: String) -> String:
	var normalized := ident.strip_edges().to_lower()
	if normalized.begins_with("p1"):
		return "p1"
	if normalized.begins_with("p2"):
		return "p2"
	return ""


func _get_first_event_text_value(event: Dictionary, keys: Array) -> String:
	for key in keys:
		var value := str(event.get(str(key), ""))
		if value != "":
			return value

	return ""
