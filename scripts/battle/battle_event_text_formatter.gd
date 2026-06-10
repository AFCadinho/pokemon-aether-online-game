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
		"SunnyDay":
			return "Sun"
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
