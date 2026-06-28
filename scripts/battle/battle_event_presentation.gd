extends RefCounted

class_name BattleEventPresentation

var event_text_formatter: BattleEventTextFormatter
var hp_event_helper: BattleHpEventHelper
var format_actor: Callable
var get_player_display_name: Callable
var recent_field_effect_source := ""
var recent_ability_event := false
var recent_move_event := false
var active_residual_pokemon_effects := {}
var debug_enabled := false


func setup(
	formatter: BattleEventTextFormatter,
	hp_helper: BattleHpEventHelper,
	format_actor_callback: Callable,
	player_display_name_callback: Callable
) -> void:
	event_text_formatter = formatter
	hp_event_helper = hp_helper
	format_actor = format_actor_callback
	get_player_display_name = player_display_name_callback


func reset() -> void:
	reset_recent_context()
	active_residual_pokemon_effects.clear()


func reset_recent_context() -> void:
	recent_field_effect_source = ""
	recent_ability_event = false
	recent_move_event = false


func get_animation_preload_keys_for_event(event_data: Dictionary) -> Dictionary:
	var move_names: Array[String] = []
	var effect_keys: Array[String] = []
	var needs_damage_sound: bool = false

	match str(event_data.get("type", "")):
		"move":
			var move_name: String = str(event_data.get("move", ""))
			if move_name != "":
				move_names.append(move_name)
		"fieldEffect":
			var field_effect_key: String = _get_field_effect_animation_key(event_data)
			if field_effect_key != "":
				effect_keys.append(field_effect_key)
		"heal":
			var heal_effect_key: String = _get_heal_effect_animation_key(event_data)
			if heal_effect_key != "":
				effect_keys.append(heal_effect_key)
		"statChange":
			var stat_effect_key: String = _get_stat_change_effect_animation_key(int(event_data.get("amount", 0)))
			if stat_effect_key != "":
				effect_keys.append(stat_effect_key)
		"mega", "primal":
			effect_keys.append("mega_evolution")
		"damage":
			needs_damage_sound = true

	return {
		"move_names": move_names,
		"effect_keys": effect_keys,
		"needs_damage_sound": needs_damage_sound,
	}


func build(event_data: Dictionary) -> Dictionary:
	var event_type := str(event_data.get("type", ""))
	var presentation := _new_presentation()

	match event_type:
		"move":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = true
			presentation["attack_actor_ident"] = str(event_data.get("actor", ""))
			_debug_battle_move("move event actor=%s move=%s target=%s source=%s event=%s" % [
				str(presentation["attack_actor_ident"]),
				str(event_data.get("move", "")),
				str(event_data.get("target", "")),
				str(event_data.get("source", "")),
				JSON.stringify(event_data),
			])
			var actor := _format_actor(str(event_data.get("actor", "")))
			var move_name := str(event_data.get("move", ""))
			presentation["move_animation_name"] = move_name
			presentation["move_animation_actor_ident"] = str(event_data.get("actor", ""))
			presentation["move_animation_target_ident"] = str(event_data.get("target", ""))
			presentation["pre_log_message"] = event_text_formatter.format_move_source_message(event_data, actor)
			if str(presentation["pre_log_message"]) != "":
				presentation["battle_message"] = str(presentation["pre_log_message"])
				presentation["attack_actor_ident"] = ""
			else:
				presentation["log_message"] = event_text_formatter.format_move_event(actor, move_name)
				presentation["battle_message"] = str(presentation["log_message"])

		"switch", "drag":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var player_id := str(event_data.get("playerId", ""))
			var from_name := str(event_data.get("from", ""))
			var to_name := str(event_data.get("to", ""))
			var forced_switch := bool(event_data.get("forced", false)) or str(event_data.get("type", "")) == "drag"

			if to_name == "":
				to_name = _format_actor(str(event_data.get("toIdent", "")), false)
			if to_name == "":
				to_name = _format_actor(str(event_data.get("pokemon", "")), false)
			if to_name == "":
				to_name = "Pokemon"
			if player_id == "p1":
				if forced_switch:
					presentation["log_message"] = event_text_formatter.format_player_forced_switch_log_message(from_name, to_name)
					presentation["battle_message"] = event_text_formatter.format_player_forced_switch_battle_message(from_name, to_name)
				else:
					presentation["log_message"] = event_text_formatter.format_player_switch_log_message(from_name, to_name)
					presentation["battle_message"] = event_text_formatter.format_player_switch_battle_message(from_name, to_name)
			else:
				var trainer_name := _get_player_display_name(player_id)
				if forced_switch:
					presentation["log_message"] = event_text_formatter.format_opponent_forced_switch_log_message(trainer_name, from_name, to_name)
					presentation["battle_message"] = event_text_formatter.format_opponent_forced_switch_battle_message(trainer_name, to_name)
				else:
					presentation["log_message"] = event_text_formatter.format_opponent_switch_log_message(trainer_name, from_name, to_name)
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

		"transform":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			var actor := _format_actor(str(event_data.get("target", "")))
			var species := str(event_data.get("species", ""))
			presentation["log_message"] = event_text_formatter.format_transform_event(actor, species)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

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
			var item_state := str(event_data.get("state", ""))
			if actor != "" and item_name != "":
				if item_state == "end":
					if _is_knock_off_item_end_event(event_data):
						presentation["log_message"] = "%s's %s got knocked off!" % [actor, item_name]
					elif _normalize_item_key(item_name) == "boosterenergy":
						presentation["log_message"] = "%s's %s activated!" % [actor, item_name]
					else:
						presentation["log_message"] = "%s used its %s!" % [actor, item_name]
				else:
					presentation["log_message"] = "%s's %s was revealed!" % [actor, item_name]
				presentation["battle_message"] = str(presentation["log_message"])
				presentation["add_blank_after"] = true

		"fieldEffect":
			recent_ability_event = false
			recent_move_event = false
			_debug_battle_move("fieldEffect event effect=%s state=%s source=%s sourceTarget=%s event=%s" % [
				str(event_data.get("effect", "")),
				str(event_data.get("state", "")),
				str(event_data.get("source", "")),
				str(event_data.get("sourceTarget", "")),
				JSON.stringify(event_data),
			])
			presentation["log_message"] = event_text_formatter.format_field_effect_event(event_data)
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			presentation["effect_animation_key"] = _get_field_effect_animation_key(event_data)
			presentation["effect_animation_target_ident"] = str(event_data.get("sourceTarget", event_data.get("sourcePokemon", "")))
			recent_field_effect_source = str(event_data.get("effect", ""))

		"pokemonEffect":
			recent_ability_event = false
			recent_move_event = false
			_track_pokemon_effect_event(event_data)
			presentation["log_message"] = event_text_formatter.format_pokemon_effect_event(event_data)
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"ability":
			recent_field_effect_source = ""
			recent_move_event = false
			_debug_battle_move("ability event target=%s ability=%s effect=%s stat=%s source=%s event=%s" % [
				str(event_data.get("target", event_data.get("actor", ""))),
				str(event_data.get("ability", "")),
				str(event_data.get("effect", "")),
				str(event_data.get("stat", "")),
				str(event_data.get("source", "")),
				JSON.stringify(event_data),
			])
			presentation["log_message"] = event_text_formatter.format_ability_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			if event_text_formatter.is_ability_boost_event(event_data):
				presentation["ability_boost_target_ident"] = str(event_data.get("target", event_data.get("actor", "")))
			recent_ability_event = str(presentation["log_message"]) != ""

		"statChange":
			recent_move_event = false
			presentation["stat_change_target_ident"] = str(event_data.get("target", ""))
			presentation["stat_change_amount"] = int(event_data.get("amount", 0))
			presentation["effect_animation_key"] = _get_stat_change_effect_animation_key(int(presentation["stat_change_amount"]))
			presentation["effect_animation_target_ident"] = str(presentation["stat_change_target_ident"])
			var is_ability_detail := recent_ability_event or event_text_formatter.is_stat_change_from_ability(event_data)
			presentation["log_message"] = event_text_formatter.format_stat_change_event(event_data, is_ability_detail)
			presentation["battle_message"] = event_text_formatter.format_stat_change_battle_message(event_data)
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""
			presentation["suppress_player_gap"] = is_ability_detail

		"status":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			_debug_battle_move("status event target=%s status=%s source=%s event=%s" % [
				str(event_data.get("target", event_data.get("pokemon", ""))),
				_get_first_event_text_value(event_data, ["status", "statusName", "condition"]),
				str(event_data.get("source", "")),
				JSON.stringify(event_data),
			])
			presentation["log_message"] = event_text_formatter.format_status_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"fail":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
			_debug_battle_move("fail event target=%s reason=%s source=%s event=%s" % [
				str(event_data.get("target", event_data.get("pokemon", ""))),
				str(event_data.get("reason", "")),
				str(event_data.get("source", "")),
				JSON.stringify(event_data),
			])
			presentation["log_message"] = event_text_formatter.format_fail_event(event_data)
			presentation["battle_message"] = str(presentation["log_message"])
			presentation["add_blank_after"] = str(presentation["log_message"]) != ""

		"cant":
			recent_field_effect_source = ""
			recent_ability_event = false
			recent_move_event = false
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
			presentation["damage_target_ident"] = str(event_data.get("target", ""))
			_debug_battle_move("damage event target=%s previous_snapshot=%s final_snapshot=%s has_hp_loss=%s visible_change=%s event=%s" % [
				str(presentation["damage_target_ident"]),
				JSON.stringify(hp_event_helper.get_event_hp_snapshot(event_data, true)),
				JSON.stringify(hp_event_helper.get_event_hp_snapshot(event_data, false)),
				str(hp_event_helper.event_has_hp_loss(event_data)),
				str(hp_event_helper.get_event_visible_hp_change(event_data)),
				JSON.stringify(event_data),
			])
			var target := _format_actor(str(presentation["damage_target_ident"]))
			var has_hp_loss: bool = hp_event_helper.event_has_hp_loss(event_data)
			var has_sub_percent_hp_loss: bool = hp_event_helper.event_has_sub_percent_hp_loss(event_data)
			var active_effect := ""
			if not recent_move_event:
				active_effect = _get_active_residual_pokemon_effect(str(presentation["damage_target_ident"]))
			var source_message := event_text_formatter.format_indirect_damage_message(
				event_data,
				target,
				recent_field_effect_source,
				active_effect,
				not recent_move_event
			)
			_debug_battle_move("damage formatted target=%s source=%s fallback_source=%s recent_move=%s source_message=%s has_hp_loss=%s sub_percent=%s" % [
				str(presentation["damage_target_ident"]),
				str(event_data.get("source", "")),
				recent_field_effect_source,
				str(recent_move_event),
				source_message,
				str(has_hp_loss),
				str(has_sub_percent_hp_loss),
			])

			if source_message != "" and (has_hp_loss or has_sub_percent_hp_loss):
				presentation["log_message"] = source_message
				if event_text_formatter.should_show_indirect_damage_in_battle_text(event_data):
					presentation["battle_message"] = source_message
			else:
				presentation["log_message"] = event_text_formatter.format_direct_damage_message(
					target,
					hp_event_helper.get_event_visible_hp_change(event_data),
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
			presentation["heal_target_ident"] = str(event_data.get("target", ""))
			presentation["effect_animation_key"] = _get_heal_effect_animation_key(event_data)
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

	return presentation


func _new_presentation() -> Dictionary:
	return {
		"pre_log_message": "",
		"log_message": "",
		"battle_message": "",
		"add_blank_after": false,
		"suppress_player_gap": false,
		"attack_actor_ident": "",
		"move_animation_name": "",
		"move_animation_actor_ident": "",
		"move_animation_target_ident": "",
		"damage_target_ident": "",
		"heal_target_ident": "",
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


func _get_field_effect_animation_key(event: Dictionary) -> String:
	var state: String = str(event.get("state", "")).strip_edges().to_lower()
	if state != "start" and state != "activate":
		return ""

	var effect_key: String = _normalize_animation_key(str(event.get("effect", "")))
	match effect_key:
		"grassyterrain", "grassy_terrain":
			return "grassy_terrain_start"

	return ""


func _get_heal_effect_animation_key(event: Dictionary) -> String:
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


func _get_first_event_text_value(event: Dictionary, keys: Array) -> String:
	for key in keys:
		var value := str(event.get(str(key), ""))
		if value != "":
			return value

	return ""


func _debug_battle_move(message: String) -> void:
	if debug_enabled:
		print("[battle-move] " + message)
