extends RefCounted

class_name BattleEventTextFormatter

const BATTLE_SUPREME_OVERLORD_EFFECT := preload("res://scripts/battle/battle_supreme_overlord_effect.gd")

static var _english_fallback_catalog: Dictionary = {}

func format_ability_event(event: Dictionary) -> String:
	var actor := _format_ability_event_actor(event)
	var ability := _format_ability_name(_get_first_event_text_value(event, [
		"ability",
		"abilityName",
		"sourceName",
		"source",
	]))
	if ability == "":
		return ""

	if is_ability_boost_event(event):
		var stat: String = _format_stat_name(str(event.get("stat", "")))
		if actor == "":
			return _t("battle.event.ability.boost_no_actor", {"ability": ability, "stat": stat})

		return _t("battle.event.ability.boost", {"actor": actor, "ability": ability, "stat": stat})

	if actor == "":
		return _t("battle.event.ability.activated_no_actor", {"ability": ability})

	return _t("battle.event.ability.activated", {"actor": actor, "ability": ability})

func is_ability_boost_event(event: Dictionary) -> bool:
	var effect: String = str(event.get("effect", "")).to_lower()
	var stat: String = _format_stat_name(str(event.get("stat", "")))
	return effect == "boost" and stat != ""

func format_move_event(actor: String, move_name: String) -> String:
	if actor == "" or move_name == "":
		return ""

	return _t("battle.event.move.used", {
		"actor": actor,
		"move": _localized_content_name("moves", move_name, move_name),
	})

func format_move_source_message(event: Dictionary, actor: String) -> String:
	var raw_source := str(event.get("source", ""))
	if raw_source == "" or actor == "":
		return ""

	var source_name := _format_pokemon_effect_name(raw_source)
	if source_name == "":
		return ""

	if _is_reflection_effect(raw_source, source_name):
		return _t("battle.event.move.reflected", {"actor": actor, "source": source_name})

	return ""


func format_item_event(event: Dictionary, actor: String, knocked_off := false) -> String:
	var item := str(event.get("item", "")).strip_edges()
	if actor == "" or item == "":
		return ""
	var item_key := item.to_lower().replace(" ", "").replace("-", "").replace("_", "")
	if str(event.get("state", "")) == "end":
		if knocked_off:
			return _t("battle.item.knocked_off", {"pokemon": actor, "item": item})
		if item_key == "boosterenergy":
			return _t("battle.event.item.activated", {"actor": actor, "item": item})
		if item_key == "airballoon":
			return _t("battle.event.item.air_balloon_popped", {"actor": actor})
		return _t("battle.event.item.used", {"actor": actor, "item": item})
	if item_key == "airballoon":
		return _t("battle.event.item.air_balloon_floats", {"actor": actor})
	return _t("battle.event.item.revealed", {"actor": actor, "item": item})


func format_player_switch_log_message(from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = _t("battle.fallback.pokemon")

	if from_name != "":
		return _t("battle.event.switch.player", {"from": from_name, "to": to_name})

	return _t("battle.event.switch.go", {"pokemon": to_name})

func format_player_switch_battle_message(from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = _t("battle.fallback.pokemon")

	if from_name != "":
		return _t("battle.event.switch.go", {"pokemon": to_name})

	return format_player_switch_log_message(from_name, to_name)

func format_player_forced_switch_log_message(_from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = _t("battle.fallback.pokemon")

	return _t("battle.event.switch.go", {"pokemon": to_name})

func format_player_forced_switch_battle_message(_from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = _t("battle.fallback.pokemon")

	return _t("battle.event.switch.go", {"pokemon": to_name})

func format_opponent_switch_log_message(trainer_name: String, from_name: String, to_name: String) -> String:
	if trainer_name == "":
		trainer_name = _t("battle.event.trainer.opposing")
	if to_name == "":
		to_name = _t("battle.fallback.pokemon")

	if from_name != "":
		return _t("battle.event.switch.opponent", {
			"trainer": trainer_name,
			"from": from_name,
			"to": to_name,
		})

	return _t("battle.event.switch.sent_out", {"trainer": trainer_name, "pokemon": to_name})

func format_opponent_switch_battle_message(trainer_name: String, to_name: String) -> String:
	if trainer_name == "":
		trainer_name = _t("battle.event.trainer.opposing")
	if to_name == "":
		to_name = _t("battle.fallback.pokemon")

	return _t("battle.event.switch.sent_out", {"trainer": trainer_name, "pokemon": to_name})

func format_opponent_forced_switch_log_message(trainer_name: String, _from_name: String, to_name: String) -> String:
	return format_opponent_switch_battle_message(trainer_name, to_name)

func format_opponent_forced_switch_battle_message(trainer_name: String, to_name: String) -> String:
	return format_opponent_switch_battle_message(trainer_name, to_name)

func format_faint_event(target: String) -> String:
	if target == "":
		target = _t("battle.fallback.pokemon")

	return _t("battle.event.fainted", {"pokemon": target})

func format_win_event(winner: String) -> String:
	if winner == "":
		return _t("battle.event.ended")

	return _t("battle.event.won", {"winner": winner})

func format_transform_event(actor: String, species: String) -> String:
	if actor == "":
		actor = _t("battle.fallback.pokemon")
	if species == "":
		species = _t("battle.fallback.pokemon")

	return _t("battle.event.transformed", {"actor": actor, "species": species})

func format_mega_event(actor: String, species: String) -> String:
	if actor == "":
		actor = _t("battle.fallback.pokemon")

	var normalized_actor := actor.to_lower().replace(" ", "").replace("-", "")
	var normalized_species := species.to_lower().replace(" ", "").replace("-", "")
	if species != "" and normalized_species.contains("mega") and normalized_species != normalized_actor:
		return _t("battle.event.mega_species", {"actor": actor, "species": species})

	return _t("battle.event.mega", {"actor": actor})

func format_primal_event(actor: String, species: String) -> String:
	if actor == "":
		actor = _t("battle.fallback.pokemon")

	if species != "":
		return _t("battle.event.primal_species", {"actor": actor, "species": species})

	return _t("battle.event.primal", {"actor": actor})

func format_wild_battle_start_messages(player_species: String, opponent_species: String) -> Array[String]:
	if player_species == "":
		player_species = _t("battle.fallback.pokemon")
	if opponent_species == "":
		opponent_species = _t("battle.fallback.pokemon")

	return [
		_t("battle.event.wild_appeared", {"pokemon": opponent_species}),
		_t("battle.event.switch.go", {"pokemon": player_species}),
	]

func format_trainer_battle_start_messages(
	player_species: String,
	opponent_species: String,
	trainer_name: String
	) -> Array[String]:
	if player_species == "":
		player_species = _t("battle.fallback.pokemon")
	if opponent_species == "":
		opponent_species = _t("battle.fallback.pokemon")
	if trainer_name == "":
		trainer_name = _t("battle.event.trainer.generic")

	return [
		_t("battle.event.trainer_wants_battle", {"trainer": trainer_name}),
		_t("battle.event.switch.sent_out", {"trainer": trainer_name, "pokemon": opponent_species}),
		_t("battle.event.switch.go", {"pokemon": player_species}),
	]

func format_action_prompt(player_species: String) -> String:
	if player_species == "":
		player_species = _t("battle.fallback.pokemon")

	return _t("battle.event.action_prompt", {"pokemon": player_species})

func _format_pokemon_effect_name(effect: String) -> String:
	var cleaned := _normalize_event_source(effect)
	if cleaned == "":
		return ""

	return _format_compact_effect_name(cleaned)

func format_stat_change_event(event: Dictionary, as_detail := false) -> String:
	var target := _format_battle_actor(_get_first_event_text_value(event, [
		"target",
		"pokemon",
		"actor",
	]))
	var stat := _format_stat_name(_get_first_event_text_value(event, [
		"stat",
		"statName",
	]))
	var amount: int = get_stat_change_amount(event)
	if target == "" or stat == "" or amount == 0:
		return ""

	var action: String = _format_stat_change_action(amount)
	if action == "":
		return ""

	var message := _t("battle.event.stat.changed", {
		"target": target,
		"stat": stat,
		"action": action,
	})
	if as_detail:
		return _t("battle.event.detail", {"message": message})

	return message

func format_stat_change_battle_message(event: Dictionary) -> String:
	var target := _format_battle_actor(_get_first_event_text_value(event, [
		"target",
		"pokemon",
		"actor",
	]))
	var stat := _format_stat_name(_get_first_event_text_value(event, [
		"stat",
		"statName",
	]))
	var amount := get_stat_change_amount(event)
	if target == "" or stat == "" or amount == 0:
		return ""

	var action := _format_stat_change_action(amount)
	if action == "":
		return ""

	var source: String = _format_stat_change_source(event)
	if source != "":
		return _t("battle.event.stat.changed_source", {
			"target": target,
			"stat": stat,
			"action": action,
			"source": source,
		})

	return _t("battle.event.stat.changed", {"target": target, "stat": stat, "action": action})


func format_stat_stage_event(event: Dictionary) -> String:
	var operation := str(event.get("operation", "")).strip_edges()
	var target := _format_battle_actor(_get_first_event_text_value(event, [
		"target",
		"pokemon",
		"actor",
	]))
	match operation:
		"clearAll":
			return _t("battle.event.stat.reset.all")
		"clear":
			return _t("battle.event.stat.reset.target", {"target": target}) if target != "" else ""
		"clearPositive":
			return _t("battle.event.stat.reset.positive", {"target": target}) if target != "" else ""
		"invert":
			return _t("battle.event.stat.reset.inverted", {"target": target}) if target != "" else ""
		"swap":
			var source_target := _format_battle_actor(str(event.get("sourceTarget", "")))
			if target == "" or source_target == "":
				return ""
			return _t("battle.event.stat.reset.swapped", {
				"target": target,
				"source": source_target,
			})

	return ""

func is_stat_change_from_ability(event: Dictionary) -> bool:
	var source := str(event.get("source", "")).strip_edges()
	if source.begins_with("[from] "):
		source = source.substr("[from] ".length()).strip_edges()

	return source.to_lower().begins_with("ability:")

func get_stat_change_amount(event: Dictionary) -> int:
	for key in ["amount", "change", "stages", "stageChange"]:
		if event.has(key):
			return int(event.get(key, 0))

	var direction := str(event.get("direction", event.get("kind", ""))).to_lower()
	var amount := int(event.get("stage", event.get("value", 1)))
	if direction == "down" or direction == "fall" or direction == "fell" or direction == "unboost":
		return -abs(amount)
	if direction == "up" or direction == "rise" or direction == "rose" or direction == "boost":
		return abs(amount)

	return 0

func format_fail_event(event: Dictionary) -> String:
	var ability_message: String = _format_fail_ability_source_event(event)
	if ability_message != "":
		return ability_message

	var reason := _format_event_reason(str(event.get("reason", event.get("source", ""))))
	if reason != "":
		return _t("battle.event.failed_reason", {"reason": reason})

	return _t("battle.event.failed")

func format_status_event(event: Dictionary) -> String:
	var target: String = _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var status: String = _format_status_name(_get_first_event_text_value(event, [
		"status",
		"statusName",
		"condition",
	]))
	if target == "" or status == "":
		return ""

	var state: String = str(event.get("state", "start")).to_lower()
	match state:
		"end", "cure", "cured":
			if _status_key(event) == "freeze":
				return _t("battle.event.status.thawed", {"target": target})
			return _t("battle.event.status.cured", {"target": target, "status": status})

	match _status_key(event):
		"poison":
			return _t("battle.event.status.poisoned", {"target": target})
		"toxic":
			return _t("battle.event.status.badly_poisoned", {"target": target})
		"burn":
			return _t("battle.event.status.burned", {"target": target})
		"paralysis":
			return _t("battle.event.status.paralyzed", {"target": target})
		"sleep":
			return _t("battle.event.status.asleep", {"target": target})
		"freeze":
			return _t("battle.event.status.frozen", {"target": target})

	return _t("battle.event.status.affected", {"target": target, "status": status})

func format_status_source_ability_event(event: Dictionary) -> String:
	var ability_source := str(event.get("sourceAbility", "")).strip_edges()
	if ability_source == "":
		var raw_source := str(event.get("source", "")).strip_edges()
		if not raw_source.to_lower().begins_with("ability:"):
			return ""
		ability_source = raw_source

	var source_target := _format_battle_actor(str(event.get("sourceTarget", "")))
	var ability := _format_ability_name(ability_source)
	if ability == "":
		return ""
	if source_target == "":
		return _t("battle.event.ability.activated_no_actor", {"ability": ability})
	return _t("battle.event.ability.activated", {
		"actor": source_target,
		"ability": ability,
	})

func format_cant_event(event: Dictionary) -> String:
	var actor := _format_battle_actor(str(event.get("actor", event.get("target", ""))))
	var reason := _format_event_reason(str(event.get("reason", event.get("source", ""))))
	if actor != "" and reason != "":
		return _t("battle.event.cant.actor_reason", {"actor": actor, "reason": reason})
	if actor != "":
		return _t("battle.event.cant.actor", {"actor": actor})
	if reason != "":
		return _t("battle.event.cant.reason", {"reason": reason})

	return _t("battle.event.cant.generic")

func format_miss_event(event: Dictionary) -> String:
	var actor: String = _format_battle_actor(str(event.get("actor", "")))
	var target: String = _format_battle_actor(str(event.get("target", "")))
	if target != "":
		return _t("battle.event.miss.avoided", {"target": target})
	if actor != "":
		return _t("battle.event.miss.actor", {"actor": actor})

	return _t("battle.event.miss.generic")

func format_effectiveness_event(event: Dictionary) -> String:
	match str(event.get("effectiveness", "")):
		"super":
			return _t("battle.event.effectiveness.super")
		"resisted":
			return _t("battle.event.effectiveness.resisted")
		"immune":
			return _t("battle.event.effectiveness.immune")

	return ""

func format_hit_count_event(event: Dictionary) -> String:
	var count: int = int(event.get("count", 0))
	if count <= 1:
		return ""

	return _t("battle.event.hit_count", {"count": count})

func format_critical_hit_event(_event: Dictionary) -> String:
	return _t("battle.event.critical_hit")

func format_direct_damage_message(
	target: String,
	damage_percent: float,
	has_hp_loss: bool,
	has_sub_percent_hp_loss: bool
	) -> String:
	if has_hp_loss:
		var percent := "%.1f" % maxf(0.1, damage_percent)
		return _t("battle.event.damage.direct", {"target": target, "percent": percent})
	if has_sub_percent_hp_loss:
		return _t("battle.event.damage.direct_small", {"target": target})

	return ""

func format_indirect_damage_message(
	event: Dictionary,
	target: String,
	fallback_source: String = "",
	active_effect: String = "",
	allow_active_effect_fallback := true
	) -> String:
	var source := _normalize_event_source(str(event.get("source", "")))
	if source == "":
		source = _normalize_event_source(fallback_source)

	if source == "":
		if allow_active_effect_fallback and active_effect != "":
			return _t("battle.event.damage.effect", {"target": target, "effect": active_effect})
		return ""

	match source.to_lower().replace(" ", ""):
		"sandstorm":
			return _t("battle.event.damage.sandstorm", {"target": target})
		"hail":
			return _t("battle.event.damage.hail", {"target": target})
		"bind", "clamp", "firespin", "infestation", "magmastorm", "sandtomb", "snaptrap", "whirlpool", "wrap":
			return _t("battle.event.damage.effect", {"target": target, "effect": _format_compact_effect_name(source)})
		"stealthrock":
			return _t("battle.event.damage.stealth_rock", {"target": target})
		"spikes":
			return _t("battle.event.damage.spikes", {"target": target})
		"toxicspikes":
			return _t("battle.event.damage.toxic_spikes", {"target": target})
		"leechseed":
			return _t("battle.event.damage.leech_seed", {"target": target})
		"brn", "burn":
			return _t("battle.event.damage.burn", {"target": target})
		"psn", "poison":
			return _t("battle.event.damage.poison", {"target": target})
		"tox", "toxic":
			return _t("battle.event.damage.poison", {"target": target})
		"curse":
			return _t("battle.event.damage.curse", {"target": target})
		"rockyhelmet":
			return _t("battle.event.damage.rocky_helmet", {"target": target})

	if allow_active_effect_fallback and active_effect != "":
		return _t("battle.event.damage.effect", {"target": target, "effect": active_effect})

	return ""

func should_show_indirect_damage_in_battle_text(event: Dictionary) -> bool:
	var source := _normalize_event_source(str(event.get("source", "")))
	var source_key := source.to_lower().replace(" ", "")
	return source_key == "rockyhelmet"

func format_heal_event(
	event: Dictionary,
	target: String,
	previous_hp: int,
	hp: int,
	visible_hp_change: int
	) -> String:
	var source := _get_heal_source_name(event)
	var source_key := source.to_lower().replace(" ", "")

	if source_key == "leftovers":
		return _t("battle.event.heal.leftovers", {"target": target})
	if _is_heal_from_ability(event) and source != "":
		return _t("battle.event.heal.ability", {"target": target, "source": _format_compact_effect_name(source)})
	if source != "" and source_key != "drain":
		return _t("battle.event.heal.source", {"target": target, "source": _format_compact_effect_name(source)})

	if hp > previous_hp:
		var percent: int = max(1, visible_hp_change)
		return _t("battle.event.heal.percent", {"target": target, "percent": percent})

	return _t("battle.event.heal.detail", {"target": target})

func format_heal_battle_message(event: Dictionary, target: String, previous_hp: int, hp: int) -> String:
	var source := _get_heal_source_name(event)
	var source_key := source.to_lower().replace(" ", "")

	if source_key == "leftovers":
		return _t("battle.event.heal.leftovers", {"target": target})
	if _is_heal_from_ability(event) and source != "":
		return _t("battle.event.heal.ability", {"target": target, "source": _format_compact_effect_name(source)})
	if source != "" and source_key != "drain":
		return _t("battle.event.heal.source", {"target": target, "source": _format_compact_effect_name(source)})
	if hp > previous_hp:
		return _t("battle.event.heal.generic", {"target": target})

	return ""

func _get_heal_source_name(event: Dictionary) -> String:
	var source_ability := str(event.get("sourceAbility", event.get("ability", event.get("abilityName", "")))).strip_edges()
	if source_ability != "":
		return source_ability

	return _normalize_event_source(str(event.get("source", "")))

func _is_heal_from_ability(event: Dictionary) -> bool:
	if str(event.get("sourceAbility", event.get("ability", event.get("abilityName", "")))).strip_edges() != "":
		return true

	var source := str(event.get("source", "")).strip_edges().to_lower()
	if source.begins_with("[from] "):
		source = source.substr("[from] ".length()).strip_edges()
	return source.begins_with("ability:")

func format_field_effect_event(event: Dictionary) -> String:
	var state := str(event.get("state", ""))
	var raw_effect := str(event.get("effect", ""))
	var is_weather_end := (
		state == "end"
		and str(event.get("effectType", "")) == "weather"
	)
	if is_weather_end and raw_effect.strip_edges().to_lower() == "none":
		raw_effect = str(event.get("endedEffect", event.get("ended_effect", "")))
		if raw_effect.strip_edges() == "":
			return _t("battle.event.field.weather_normal")

	var effect_name := _format_field_effect_name(raw_effect)
	if effect_name == "":
		return ""

	match state:
		"swap":
			return _t("battle.event.field.swapped")
		"start":
			var source_message := _format_field_effect_start_source_message(event, effect_name)
			if source_message != "":
				return source_message

			return _t("battle.event.field.active", {"effect": effect_name})
		"upkeep":
			return _t("battle.event.field.continues", {"effect": effect_name})
		"end":
			if is_weather_end:
				return _format_weather_end_message(raw_effect, effect_name)
			return _t("battle.event.field.ended", {"effect": effect_name})

	return _t("battle.event.field.changed", {"effect": effect_name})

func _format_weather_end_message(raw_effect: String, effect_name: String) -> String:
	match _normalize_event_source(raw_effect).to_lower().replace(" ", ""):
		"raindance", "rain", "primordialsea":
			return _t("battle.event.weather.rain_ended")
		"sunnyday", "sun", "harshsun", "desolateland":
			return _t("battle.event.weather.sun_ended")
		"sandstorm":
			return _t("battle.event.weather.sandstorm_ended")
		"hail":
			return _t("battle.event.weather.hail_ended")
		"snow":
			return _t("battle.event.weather.snow_ended")

	return _t("battle.event.field.ended", {"effect": effect_name})

func format_field_effect_name(effect: String) -> String:
	return _format_field_effect_name(effect)

func format_pokemon_effect_event(event: Dictionary) -> String:
	var target := _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var raw_effect := str(event.get("effect", ""))
	# Showdown marks Supreme Overlord's fallen counter as [silent]. The backend
	# preserves the ordered effect but not that presentation hint, so the HUD
	# badge owns this state instead of emitting repetitive generic log text.
	if BATTLE_SUPREME_OVERLORD_EFFECT.is_fallen_effect(raw_effect):
		return ""
	var effect := format_pokemon_effect_name(raw_effect)
	if target == "" or effect == "":
		return ""

	var state := str(event.get("state", "")).to_lower()
	if state == "activate" and _is_reflection_effect(raw_effect, effect):
		return _t("battle.event.move.reflected", {"actor": target, "source": effect})

	# Showdown represents Future Sight's delayed lifecycle as a volatile start on
	# the user followed by an end on the Pokemon that receives the attack. Those
	# events describe an action, not a persistent condition on either Pokemon.
	if _is_future_sight_effect(raw_effect):
		match state:
			"start":
				return _t("battle.event.effect.future_sight_start", {"target": target})
			"activate", "end":
				return _t("battle.event.effect.future_sight_hit", {"target": target})

	if _is_protect_effect(raw_effect):
		if state == "start" or state == "activate":
			return _t("battle.event.effect.protected", {"target": target})

	if _is_substitute_effect(raw_effect):
		match state:
			"start":
				return _t("battle.event.effect.substitute_start", {"target": target})
			"activate":
				return _t("battle.event.effect.substitute_hit", {"target": target})
			"end":
				return _t("battle.event.effect.substitute_end", {"target": target})

	var ability_stat_message := _format_ability_stat_pokemon_effect(target, raw_effect)
	if ability_stat_message != "":
		return ability_stat_message

	if _is_ability_like_pokemon_effect(raw_effect, effect):
		match state:
			"start", "activate":
				return _t("battle.event.ability.activated", {"actor": target, "ability": effect})
			"end":
				return _t("battle.event.effect.actor_ended", {"target": target, "effect": effect})

	if effect.to_lower() == "confusion":
		match state:
			"start":
				return _t("battle.event.effect.confused_start", {"target": target})
			"activate":
				return _t("battle.event.effect.confused", {"target": target})
			"end":
				return _t("battle.event.effect.confused_end", {"target": target})

	if is_trapping_pokemon_effect(effect):
		match state:
			"start", "activate":
				return _t("battle.event.effect.trapped", {"target": target, "effect": effect})
			"end":
				return _t("battle.event.effect.freed", {"target": target, "effect": effect})

	match state:
		"start":
			return _t("battle.event.status.affected", {"target": target, "status": effect})
		"activate":
			return _t("battle.event.effect.affected", {"target": target, "effect": effect})
		"end":
			return _t("battle.event.effect.ended", {"target": target, "effect": effect})

	return _t("battle.event.effect.changed", {"target": target, "effect": effect})

func format_pokemon_effect_name(effect: String) -> String:
	return _format_pokemon_effect_name(effect)

func _is_substitute_effect(effect: String) -> bool:
	var cleaned_effect := effect.strip_edges().to_lower()
	if cleaned_effect.begins_with("move:"):
		cleaned_effect = cleaned_effect.substr("move:".length()).strip_edges()
	return cleaned_effect.replace(" ", "").replace("_", "").replace("-", "") == "substitute"

func is_trapping_pokemon_effect(effect: String) -> bool:
	match effect.to_lower().replace(" ", ""):
		"bind", "clamp", "firespin", "infestation", "magmastorm", "sandtomb", "snaptrap", "whirlpool", "wrap":
			return true

	return false

func _format_ability_event_actor(event: Dictionary) -> String:
	var actor := _format_battle_actor(_get_first_event_text_value(event, [
		"target",
		"actor",
		"pokemon",
		"sourcePokemon",
		"sourceTarget",
	]))
	return actor

func _format_ability_name(ability: String) -> String:
	var cleaned := _normalize_event_source(ability)
	if cleaned == "":
		return ""

	return _localized_content_name(
		"abilities",
		cleaned,
		_format_compact_effect_name(cleaned)
	)


func _localized_content_name(kind: String, content_id: String, fallback_name: String) -> String:
	var scene_tree := Engine.get_main_loop() as SceneTree
	var content_localization := (
		scene_tree.root.get_node_or_null("ContentLocalization")
		if scene_tree != null
		else null
	)
	if content_localization != null and content_localization.has_method("display_name"):
		return str(content_localization.call("display_name", kind, content_id, fallback_name))
	return fallback_name

func _is_reflection_effect(raw_effect: String, effect: String) -> bool:
	var source_kind := ""
	var cleaned_raw := raw_effect.strip_edges()
	if cleaned_raw.begins_with("[from] "):
		cleaned_raw = cleaned_raw.substr("[from] ".length()).strip_edges()
	if cleaned_raw.contains(": "):
		source_kind = str(cleaned_raw.split(": ")[0]).strip_edges().to_lower()

	var effect_key := effect.to_lower().replace(" ", "")
	return (
		(source_kind == "ability" and effect_key == "magicbounce")
		or (source_kind == "move" and effect_key == "magiccoat")
	)

func _is_future_sight_effect(raw_effect: String) -> bool:
	return _normalize_event_source(raw_effect).to_lower().replace(" ", "").replace("-", "") == "futuresight"


func _is_protect_effect(raw_effect: String) -> bool:
	return _normalize_event_source(raw_effect).to_lower().replace(" ", "").replace("-", "") == "protect"

func _is_ability_like_pokemon_effect(raw_effect: String, effect: String) -> bool:
	var cleaned_raw: String = raw_effect.strip_edges()
	if cleaned_raw.begins_with("[from] "):
		cleaned_raw = cleaned_raw.substr("[from] ".length()).strip_edges()

	if cleaned_raw.to_lower().begins_with("ability:"):
		return true

	match effect.to_lower().replace(" ", ""):
		"protosynthesis", "quarkdrive":
			return true

	return false

func _format_ability_stat_pokemon_effect(target: String, raw_effect: String) -> String:
	var effect_key: String = _normalize_event_source(raw_effect).to_lower().replace(" ", "")
	var ability_name: String = ""
	var stat_key: String = ""

	for ability_key in ["protosynthesis", "quarkdrive"]:
		if effect_key.begins_with(ability_key) and effect_key.length() > ability_key.length():
			ability_name = _format_compact_effect_name(ability_key)
			stat_key = effect_key.substr(ability_key.length())
			break

	if ability_name == "" or stat_key == "":
		return ""

	var stat_name: String = _format_stat_name(stat_key)
	if stat_name == "":
		return _t("battle.event.ability.activated", {"actor": target, "ability": ability_name})

	return _t("battle.event.stat.boosted_by", {
		"target": target,
		"stat": stat_name,
		"source": ability_name,
	})

func _format_stat_change_source(event: Dictionary) -> String:
	var source := _normalize_event_source(str(event.get("source", "")))
	if source == "":
		return ""

	return _format_compact_effect_name(source)

func _format_stat_change_action(amount: int) -> String:
	match amount:
		1:
			return _t("battle.event.stat.action.rose")
		2:
			return _t("battle.event.stat.action.rose_sharply")
		3, 4, 5, 6:
			return _t("battle.event.stat.action.rose_drastically")
		-1:
			return _t("battle.event.stat.action.fell")
		-2:
			return _t("battle.event.stat.action.fell_harshly")
		-3, -4, -5, -6:
			return _t("battle.event.stat.action.fell_severely")

	return ""

func _format_stat_name(stat: String) -> String:
	match stat.to_lower().replace(" ", ""):
		"atk", "attack":
			return _t("battle.event.stat.name.attack")
		"def", "defense", "defence":
			return _t("battle.event.stat.name.defense")
		"spa", "spatk", "specialattack":
			return _t("battle.event.stat.name.special_attack")
		"spd", "spdef", "specialdefense", "specialdefence":
			return _t("battle.event.stat.name.special_defense")
		"spe", "speed":
			return _t("battle.event.stat.name.speed")
		"accuracy":
			return _t("battle.event.stat.name.accuracy")
		"evasion":
			return _t("battle.event.stat.name.evasion")

	return _format_compact_effect_name(stat)

func _format_fail_ability_source_event(event: Dictionary) -> String:
	var source: String = str(event.get("source", ""))
	if not source.to_lower().begins_with("ability:"):
		return ""

	var target: String = _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var ability: String = _format_ability_name(source)
	if target == "" or ability == "":
		return ""

	return _t("battle.event.ability.activated", {"actor": target, "ability": ability})

func _format_status_name(status: String) -> String:
	var cleaned: String = _normalize_event_source(status).to_lower().replace(" ", "")
	match cleaned:
		"psn", "poison", "poisoned":
			return _t("battle.event.status.name.poison")
		"tox", "toxic", "badlypoisoned":
			return _t("battle.event.status.name.toxic")
		"brn", "burn", "burned":
			return _t("battle.event.status.name.burn")
		"par", "paralysis", "paralyzed":
			return _t("battle.event.status.name.paralysis")
		"slp", "sleep", "asleep":
			return _t("battle.event.status.name.sleep")
		"frz", "freeze", "frozen":
			return _t("battle.event.status.name.freeze")

	if cleaned == "":
		return ""

	return _format_compact_effect_name(cleaned)

func _format_event_reason(reason: String) -> String:
	var cleaned := _normalize_event_source(reason)
	if cleaned == "":
		return ""

	match cleaned.to_lower().replace(" ", ""):
		"slp", "sleep":
			return _t("battle.event.reason.sleep")
		"frz", "freeze":
			return _t("battle.event.reason.freeze")
		"par", "paralysis":
			return _t("battle.event.reason.paralysis")
		"flinch":
			return _t("battle.event.reason.flinching")
		"recharge":
			return _t("battle.event.reason.recharging")
		"trapped":
			return _t("battle.event.reason.trapped")

	return cleaned

func _format_field_effect_start_source_message(event: Dictionary, effect_name: String) -> String:
	var source_name := _get_field_effect_source_name(event)
	if source_name == "":
		return ""

	var actor := _format_field_effect_source_actor(event)
	var source_kind := _get_field_effect_source_kind(event)
	if source_kind == "ability":
		return _format_ability_field_effect_message(
			actor,
			source_name,
			effect_name,
			str(event.get("effect", "")),
		)

	if actor != "" and source_name != effect_name:
		return _t("battle.event.field.source_activated", {
			"actor": actor,
			"source": source_name,
			"effect": effect_name,
		})

	return ""

func _get_field_effect_source_name(event: Dictionary) -> String:
	var source_name := str(event.get("sourceName", ""))
	if source_name != "":
		return _normalize_event_source(source_name)

	return _normalize_event_source(str(event.get("source", "")))

func _get_field_effect_source_kind(event: Dictionary) -> String:
	var source := str(event.get("source", "")).strip_edges()
	if source.begins_with("[from] "):
		source = source.substr("[from] ".length()).strip_edges()

	if source.contains(": "):
		return str(source.split(": ")[0]).strip_edges().to_lower()

	return ""

func _format_field_effect_source_actor(event: Dictionary) -> String:
	var source_actor := str(event.get("sourcePokemon", ""))
	if source_actor == "":
		source_actor = str(event.get("sourceTarget", ""))
	if source_actor == "":
		source_actor = str(event.get("actor", ""))

	return _format_battle_actor(source_actor)

func _format_ability_field_effect_message(
	actor: String,
	ability: String,
	effect_name: String,
	raw_effect: String
) -> String:
	var action := _get_field_effect_start_action(raw_effect)
	if action == "":
		action = _t("battle.event.field.action.activated", {"effect": effect_name})

	return _format_ability_weather_message(actor, ability, action)

func _get_field_effect_start_action(raw_effect: String) -> String:
	match _normalize_event_source(raw_effect).to_lower().replace(" ", ""):
		"sunnyday", "sun", "harshsun", "desolateland":
			return _t("battle.event.field.action.sun")
		"raindance", "rain", "primordialsea":
			return _t("battle.event.field.action.rain")
		"sandstorm":
			return _t("battle.event.field.action.sandstorm")
		"hail":
			return _t("battle.event.field.action.hail")
		"snow":
			return _t("battle.event.field.action.snow")

	return ""

func _format_ability_weather_message(actor: String, ability: String, action: String) -> String:
	if actor == "":
		return _t("battle.event.ability.action_no_actor", {"ability": ability, "action": action})

	return _t("battle.event.ability.action", {"actor": actor, "ability": ability, "action": action})

func _format_field_effect_name(effect: String) -> String:
	var cleaned := effect
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	match cleaned:
		"RainDance":
			return _t("battle.event.field.name.rain")
		"PrimordialSea":
			return _t("battle.event.field.name.primordial_sea")
		"SunnyDay":
			return _t("battle.event.field.name.sun")
		"HarshSun":
			return _t("battle.event.field.name.harsh_sun")
		"DesolateLand":
			return _t("battle.event.field.name.desolate_land")
		"DeltaStream":
			return _t("battle.event.field.name.delta_stream")
		"Sandstorm":
			return _t("battle.event.field.name.sandstorm")
		"Hail":
			return _t("battle.event.field.name.hail")
		"Snow":
			return _t("battle.event.field.name.snow")

	cleaned = cleaned.replace("Dance", " Dance")
	cleaned = cleaned.replace("Room", " Room")
	cleaned = cleaned.replace("Terrain", " Terrain")
	cleaned = cleaned.replace("Rock", " Rock")
	cleaned = cleaned.replace("Web", " Web")
	cleaned = cleaned.replace("Spikes", " Spikes")

	return cleaned.strip_edges()

func _normalize_event_source(source: String) -> String:
	var cleaned := source.strip_edges()
	if cleaned.begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()

	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.strip_edges()

func _format_compact_effect_name(value: String) -> String:
	var cleaned := value.strip_edges()
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	cleaned = cleaned.replace("-", " ")
	cleaned = _split_camel_case_text(cleaned)
	var words := PackedStringArray()
	for raw_word in cleaned.split(" "):
		var word := str(raw_word).strip_edges()
		if word == "":
			continue

		words.append(word.substr(0, 1).to_upper() + word.substr(1).to_lower())

	return " ".join(words)

func _split_camel_case_text(value: String) -> String:
	var result := ""

	for index in range(value.length()):
		var character := value.substr(index, 1)
		var lower_character := character.to_lower()
		var is_uppercase := character == character.to_upper() and character != lower_character

		if is_uppercase and result != "" and not result.ends_with(" "):
			result += " "

		result += character

	return result

func _get_first_event_text_value(event: Dictionary, keys: Array) -> String:
	for key in keys:
		var value := str(event.get(str(key), ""))
		if value != "":
			return value

	return ""

func _format_battle_actor(actor: String, include_side_prefix := true) -> String:
	var player_id := _get_player_id_from_ident(actor)
	var actor_name := actor
	if actor_name.contains(": "):
		actor_name = actor_name.split(": ")[1]

	if include_side_prefix and player_id == "p2" and actor_name != "":
		return _t("battle.event.actor.opposing", {"actor": actor_name})

	return actor_name

func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""


func _status_key(event: Dictionary) -> String:
	var raw_status := _get_first_event_text_value(event, ["status", "statusName", "condition"])
	var cleaned := _normalize_event_source(raw_status).to_lower().replace(" ", "")
	match cleaned:
		"psn", "poison", "poisoned":
			return "poison"
		"tox", "toxic", "badlypoisoned":
			return "toxic"
		"brn", "burn", "burned":
			return "burn"
		"par", "paralysis", "paralyzed":
			return "paralysis"
		"slp", "sleep", "asleep":
			return "sleep"
		"frz", "freeze", "frozen":
			return "freeze"
	return cleaned


func _t(key: String, replacements: Dictionary = {}) -> String:
	var main_loop := Engine.get_main_loop() as SceneTree
	if main_loop != null:
		var localization_manager := main_loop.root.get_node_or_null("LocalizationManager")
		if localization_manager != null:
			return str(localization_manager.call("text", key, replacements))
	if _english_fallback_catalog.is_empty():
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string("res://localization/en.json")
		)
		if parsed is Dictionary:
			_english_fallback_catalog = parsed as Dictionary
	return str(_english_fallback_catalog.get(key, key)).format(replacements)
