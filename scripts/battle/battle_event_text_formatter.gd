extends RefCounted

class_name BattleEventTextFormatter

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
			return "%s boosted %s!" % [ability, stat]

		return "%s's %s boosted its %s!" % [actor, ability, stat]

	if actor == "":
		return "%s activated!" % ability

	return "%s's %s activated!" % [actor, ability]

func is_ability_boost_event(event: Dictionary) -> bool:
	var effect: String = str(event.get("effect", "")).to_lower()
	var stat: String = _format_stat_name(str(event.get("stat", "")))
	return effect == "boost" and stat != ""

func format_move_event(actor: String, move_name: String) -> String:
	if actor == "" or move_name == "":
		return ""

	return "%s used %s!" % [actor, move_name]

func format_move_source_message(event: Dictionary, actor: String) -> String:
	var raw_source := str(event.get("source", ""))
	if raw_source == "" or actor == "":
		return ""

	var source_name := _format_pokemon_effect_name(raw_source)
	if source_name == "":
		return ""

	if _is_reflection_effect(raw_source, source_name):
		return "%s's %s reflected the move!" % [actor, source_name]

	return ""

func format_player_switch_log_message(from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = "Pokemon"

	if from_name != "":
		return "%s, come back!\nGo! %s!" % [from_name, to_name]

	return "Go! %s!" % to_name

func format_player_switch_battle_message(from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = "Pokemon"

	if from_name != "":
		return "Go! %s!" % to_name

	return format_player_switch_log_message(from_name, to_name)

func format_player_forced_switch_log_message(_from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = "Pokemon"

	return "Go! %s!" % to_name

func format_player_forced_switch_battle_message(_from_name: String, to_name: String) -> String:
	if to_name == "":
		to_name = "Pokemon"

	return "Go! %s!" % to_name

func format_opponent_switch_log_message(trainer_name: String, from_name: String, to_name: String) -> String:
	if trainer_name == "":
		trainer_name = "The opposing Trainer"
	if to_name == "":
		to_name = "Pokemon"

	if from_name != "":
		return "%s withdrew %s!\n%s sent out %s!" % [
			trainer_name,
			from_name,
			trainer_name,
			to_name
		]

	return "%s sent out %s!" % [trainer_name, to_name]

func format_opponent_switch_battle_message(trainer_name: String, to_name: String) -> String:
	if trainer_name == "":
		trainer_name = "The opposing Trainer"
	if to_name == "":
		to_name = "Pokemon"

	return "%s sent out %s!" % [trainer_name, to_name]

func format_opponent_forced_switch_log_message(trainer_name: String, _from_name: String, to_name: String) -> String:
	return format_opponent_switch_battle_message(trainer_name, to_name)

func format_opponent_forced_switch_battle_message(trainer_name: String, to_name: String) -> String:
	return format_opponent_switch_battle_message(trainer_name, to_name)

func format_faint_event(target: String) -> String:
	if target == "":
		target = "Pokemon"

	return "%s fainted!" % target

func format_win_event(winner: String) -> String:
	if winner == "":
		return "The battle ended!"

	return "%s won!" % winner

func format_transform_event(actor: String, species: String) -> String:
	if actor == "":
		actor = "Pokemon"
	if species == "":
		species = "Pokemon"

	return "%s transformed into %s!" % [actor, species]

func format_mega_event(actor: String, species: String) -> String:
	if actor == "":
		actor = "Pokemon"

	var normalized_actor := actor.to_lower().replace(" ", "").replace("-", "")
	var normalized_species := species.to_lower().replace(" ", "").replace("-", "")
	if species != "" and normalized_species.contains("mega") and normalized_species != normalized_actor:
		return "%s has Mega Evolved into %s!" % [actor, species]

	return "%s has Mega Evolved!" % actor

func format_primal_event(actor: String, species: String) -> String:
	if actor == "":
		actor = "Pokemon"

	if species != "":
		return "%s underwent Primal Reversion into %s!" % [actor, species]

	return "%s underwent Primal Reversion!" % actor

func format_wild_battle_start_messages(player_species: String, opponent_species: String) -> Array[String]:
	if player_species == "":
		player_species = "Pokemon"
	if opponent_species == "":
		opponent_species = "Pokemon"

	return [
		"A wild %s has appeared!" % opponent_species,
		"Go! %s!" % player_species,
	]

func format_trainer_battle_start_messages(
	player_species: String,
	opponent_species: String,
	trainer_name: String
	) -> Array[String]:
	if player_species == "":
		player_species = "Pokemon"
	if opponent_species == "":
		opponent_species = "Pokemon"
	if trainer_name == "":
		trainer_name = "Trainer"

	return [
		"%s wants to battle!" % trainer_name,
		"%s sent out %s!" % [trainer_name, opponent_species],
		"Go! %s!" % player_species,
	]

func format_action_prompt(player_species: String) -> String:
	if player_species == "":
		player_species = "Pokemon"

	return "What will %s do?" % player_species

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

	var message := "%s's %s %s!" % [target, stat, action]
	if as_detail:
		return "- %s" % message

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
		return "%s's %s %s because of %s!" % [target, stat, action, source]

	return "%s's %s %s!" % [target, stat, action]

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
		return "But it failed! (%s)" % reason

	return "But it failed!"

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
			if status.to_lower() == "freeze":
				return "%s thawed out!" % target
			return "%s was cured of %s!" % [target, status]

	match status.to_lower():
		"poison":
			return "%s was poisoned!" % target
		"toxic poison":
			return "%s was badly poisoned!" % target
		"burn":
			return "%s was burned!" % target
		"paralysis":
			return "%s was paralyzed!" % target
		"sleep":
			return "%s fell asleep!" % target
		"freeze":
			return "%s was frozen!" % target

	return "%s became affected by %s!" % [target, status]

func format_cant_event(event: Dictionary) -> String:
	var actor := _format_battle_actor(str(event.get("actor", event.get("target", ""))))
	var reason := _format_event_reason(str(event.get("reason", event.get("source", ""))))
	if actor != "" and reason != "":
		return "%s couldn't move because of %s!" % [actor, reason]
	if actor != "":
		return "%s couldn't move!" % actor
	if reason != "":
		return "It couldn't move because of %s!" % reason

	return "It couldn't move!"

func format_miss_event(event: Dictionary) -> String:
	var actor: String = _format_battle_actor(str(event.get("actor", "")))
	var target: String = _format_battle_actor(str(event.get("target", "")))
	if target != "":
		return "%s avoided the attack!" % target
	if actor != "":
		return "%s's attack missed!" % actor

	return "The attack missed!"

func format_effectiveness_event(event: Dictionary) -> String:
	match str(event.get("effectiveness", "")):
		"super":
			return "It's super effective!"
		"resisted":
			return "It's not very effective..."
		"immune":
			return "It had no effect!"

	return ""

func format_hit_count_event(event: Dictionary) -> String:
	var count: int = int(event.get("count", 0))
	if count <= 1:
		return ""

	return "Hit %s times!" % count

func format_critical_hit_event(_event: Dictionary) -> String:
	return "A critical hit!"

func format_direct_damage_message(
	target: String,
	visible_hp_change: int,
	has_hp_loss: bool,
	has_sub_percent_hp_loss: bool
	) -> String:
	if has_hp_loss:
		var percent: int = max(1, visible_hp_change)
		return "(%s lost %s%% of its health!)" % [target, percent]
	if has_sub_percent_hp_loss:
		return "(%s lost less than 1%% of its health!)" % target

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
			return "%s is hurt by %s!" % [target, active_effect]
		return ""

	match source.to_lower().replace(" ", ""):
		"sandstorm":
			return "%s is buffeted by the sandstorm!" % target
		"hail":
			return "%s is buffeted by the hail!" % target
		"bind", "clamp", "firespin", "infestation", "magmastorm", "sandtomb", "snaptrap", "whirlpool", "wrap":
			return "%s is hurt by %s!" % [target, _format_compact_effect_name(source)]
		"stealthrock":
			return "Pointed stones dug into %s!" % target
		"spikes":
			return "%s was hurt by spikes!" % target
		"toxicspikes":
			return "%s was hurt by poison spikes!" % target
		"leechseed":
			return "%s's health is sapped by Leech Seed!" % target
		"brn", "burn":
			return "%s was hurt by its burn!" % target
		"psn", "poison":
			return "%s was hurt by poison!" % target
		"tox", "toxic":
			return "%s was hurt by poison!" % target
		"curse":
			return "%s is afflicted by the curse!" % target
		"rockyhelmet":
			return "%s was hurt by Rocky Helmet!" % target

	if allow_active_effect_fallback and active_effect != "":
		return "%s is hurt by %s!" % [target, active_effect]

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
		return "%s restored HP using its Leftovers!" % target
	if _is_heal_from_ability(event) and source != "":
		return "%s's %s restored its HP!" % [target, _format_compact_effect_name(source)]
	if source != "" and source_key != "drain":
		return "%s restored HP with %s!" % [target, _format_compact_effect_name(source)]

	if hp > previous_hp:
		var percent: int = max(1, visible_hp_change)
		return "(%s restored %s%% of its health!)" % [target, percent]

	return "  - %s restored HP!" % target

func format_heal_battle_message(event: Dictionary, target: String, previous_hp: int, hp: int) -> String:
	var source := _get_heal_source_name(event)
	var source_key := source.to_lower().replace(" ", "")

	if source_key == "leftovers":
		return "%s restored HP using its Leftovers!" % target
	if _is_heal_from_ability(event) and source != "":
		return "%s's %s restored its HP!" % [target, _format_compact_effect_name(source)]
	if source != "" and source_key != "drain":
		return "%s restored HP with %s!" % [target, _format_compact_effect_name(source)]
	if hp > previous_hp:
		return "%s restored HP!" % target

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
	var effect_name := _format_field_effect_name(str(event.get("effect", "")))
	if effect_name == "":
		return ""

	var state := str(event.get("state", ""))
	match state:
		"start":
			var source_message := _format_field_effect_start_source_message(event, effect_name)
			if source_message != "":
				return source_message

			return "%s became active!" % effect_name
		"upkeep":
			return "%s continues." % effect_name
		"end":
			return "%s ended." % effect_name

	return "%s changed." % effect_name

func format_field_effect_name(effect: String) -> String:
	return _format_field_effect_name(effect)

func format_pokemon_effect_event(event: Dictionary) -> String:
	var target := _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var raw_effect := str(event.get("effect", ""))
	var effect := format_pokemon_effect_name(raw_effect)
	if target == "" or effect == "":
		return ""

	var state := str(event.get("state", "")).to_lower()
	if state == "activate" and _is_reflection_effect(raw_effect, effect):
		return "%s's %s reflected the move!" % [target, effect]

	# Showdown represents Future Sight's delayed lifecycle as a volatile start on
	# the user followed by an end on the Pokemon that receives the attack. Those
	# events describe an action, not a persistent condition on either Pokemon.
	if _is_future_sight_effect(raw_effect):
		match state:
			"start":
				return "%s foresaw an attack!" % target
			"activate", "end":
				return "%s took the Future Sight attack!" % target

	if _is_protect_effect(raw_effect):
		if state == "start" or state == "activate":
			return "%s protected itself!" % target

	if _is_substitute_effect(raw_effect):
		match state:
			"start":
				return "%s put in a substitute!" % target
			"activate":
				return "The substitute took the hit for %s!" % target
			"end":
				return "%s's substitute faded!" % target

	var ability_stat_message := _format_ability_stat_pokemon_effect(target, raw_effect)
	if ability_stat_message != "":
		return ability_stat_message

	if _is_ability_like_pokemon_effect(raw_effect, effect):
		match state:
			"start", "activate":
				return "%s's %s activated!" % [target, effect]
			"end":
				return "%s's %s ended." % [target, effect]

	if effect.to_lower() == "confusion":
		match state:
			"start":
				return "%s became confused!" % target
			"activate":
				return "%s is confused!" % target
			"end":
				return "%s snapped out of confusion!" % target

	if is_trapping_pokemon_effect(effect):
		match state:
			"start", "activate":
				return "%s is trapped by %s!" % [target, effect]
			"end":
				return "%s was freed from %s!" % [target, effect]

	match state:
		"start":
			return "%s became affected by %s!" % [target, effect]
		"activate":
			return "%s is affected by %s!" % [target, effect]
		"end":
			return "%s is no longer affected by %s." % [target, effect]

	return "%s's %s changed." % [target, effect]

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

	return _format_compact_effect_name(cleaned)

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
		return "%s's %s activated!" % [target, ability_name]

	return "%s's %s was boosted by %s!" % [target, stat_name, ability_name]

func _format_stat_change_source(event: Dictionary) -> String:
	var source := _normalize_event_source(str(event.get("source", "")))
	if source == "":
		return ""

	return _format_compact_effect_name(source)

func _format_stat_change_action(amount: int) -> String:
	match amount:
		1:
			return "rose"
		2:
			return "rose sharply"
		3, 4, 5, 6:
			return "rose drastically"
		-1:
			return "fell"
		-2:
			return "harshly fell"
		-3, -4, -5, -6:
			return "severely fell"

	return ""

func _format_stat_name(stat: String) -> String:
	match stat.to_lower().replace(" ", ""):
		"atk", "attack":
			return "Attack"
		"def", "defense", "defence":
			return "Defense"
		"spa", "spatk", "specialattack":
			return "Sp. Atk"
		"spd", "spdef", "specialdefense", "specialdefence":
			return "Sp. Def"
		"spe", "speed":
			return "Speed"
		"accuracy":
			return "accuracy"
		"evasion":
			return "evasion"

	return _format_compact_effect_name(stat)

func _format_fail_ability_source_event(event: Dictionary) -> String:
	var source: String = str(event.get("source", ""))
	if not source.to_lower().begins_with("ability:"):
		return ""

	var target: String = _format_battle_actor(str(event.get("target", event.get("pokemon", ""))))
	var ability: String = _format_ability_name(source)
	if target == "" or ability == "":
		return ""

	return "%s's %s activated!" % [target, ability]

func _format_status_name(status: String) -> String:
	var cleaned: String = _normalize_event_source(status).to_lower().replace(" ", "")
	match cleaned:
		"psn", "poison", "poisoned":
			return "poison"
		"tox", "toxic", "badlypoisoned":
			return "toxic poison"
		"brn", "burn", "burned":
			return "burn"
		"par", "paralysis", "paralyzed":
			return "paralysis"
		"slp", "sleep", "asleep":
			return "sleep"
		"frz", "freeze", "frozen":
			return "freeze"

	if cleaned == "":
		return ""

	return _format_compact_effect_name(cleaned)

func _format_event_reason(reason: String) -> String:
	var cleaned := _normalize_event_source(reason)
	if cleaned == "":
		return ""

	match cleaned.to_lower().replace(" ", ""):
		"slp", "sleep":
			return "sleep"
		"frz", "freeze":
			return "freeze"
		"par", "paralysis":
			return "paralysis"
		"flinch":
			return "flinching"
		"recharge":
			return "recharging"
		"trapped":
			return "being trapped"

	return cleaned

func _format_field_effect_start_source_message(event: Dictionary, effect_name: String) -> String:
	var source_name := _get_field_effect_source_name(event)
	if source_name == "":
		return ""

	var actor := _format_field_effect_source_actor(event)
	var source_kind := _get_field_effect_source_kind(event)
	if source_kind == "ability":
		return _format_ability_field_effect_message(actor, source_name, effect_name)

	if actor != "" and source_name != effect_name:
		return "%s's %s activated %s!" % [actor, source_name, effect_name]

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

func _format_ability_field_effect_message(actor: String, ability: String, effect_name: String) -> String:
	var action := _get_field_effect_start_action(effect_name)
	if action == "":
		action = "activated %s" % effect_name

	return _format_ability_weather_message(actor, ability, action)

func _get_field_effect_start_action(effect_name: String) -> String:
	match effect_name.to_lower().replace(" ", ""):
		"sun":
			return "intensified the sun"
		"rain":
			return "made it rain"
		"sandstorm":
			return "whipped up a sandstorm"
		"hail":
			return "summoned hail"
		"snow":
			return "summoned snow"

	return ""

func _format_ability_weather_message(actor: String, ability: String, action: String) -> String:
	if actor == "":
		return "%s %s!" % [ability, action]

	return "%s's %s %s!" % [actor, ability, action]

func _format_field_effect_name(effect: String) -> String:
	var cleaned := effect
	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	match cleaned:
		"RainDance":
			return "Rain"
		"PrimordialSea":
			return "Primordial Sea"
		"SunnyDay":
			return "Sun"
		"HarshSun":
			return "Harsh Sun"
		"DesolateLand":
			return "Desolate Land"
		"DeltaStream":
			return "Delta Stream"
		"Sandstorm":
			return "Sandstorm"
		"Hail":
			return "Hail"
		"Snow":
			return "Snow"

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
		return "The opposing %s" % actor_name

	return actor_name

func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""
