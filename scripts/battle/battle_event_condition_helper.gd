extends RefCounted

class_name BattleEventConditionHelper

var debug_enabled := false
var hp_event_helper := preload("res://scripts/battle/battle_hp_event_helper.gd").new()


func fill_missing_previous_event_conditions(response: Dictionary, battle_state: BattleState) -> void:
	var events_value: Variant = response.get("events", [])
	if not (events_value is Array):
		return

	var events: Array = events_value as Array
	var current_conditions_by_ident: Dictionary = {}
	for event_value in events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type: String = str(event.get("type", ""))
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_ident: String = str(event.get("target", ""))
		if target_ident == "":
			continue

		if str(event.get("previousCondition", "")) != "":
			var known_condition: String = get_condition_from_event_data(event)
			if known_condition != "" and not hp_event_helper.is_percentage_only_condition_event(event, false):
				current_conditions_by_ident[target_ident] = known_condition
			continue

		var previous_condition: String = str(current_conditions_by_ident.get(target_ident, ""))
		if previous_condition == "":
			previous_condition = get_battle_condition_for_ident(target_ident, battle_state)
		if previous_condition == "":
			_debug("could not fill previousCondition target=%s event=%s" % [
				target_ident,
				JSON.stringify(event),
			])
			continue

		event["previousCondition"] = previous_condition
		var previous_snapshot: Dictionary = hp_event_helper.parse_condition_hp_snapshot(previous_condition)
		if not previous_snapshot.is_empty():
			event["previousHp"] = int(previous_snapshot.get("hp", 0))
			if not event.has("maxHp"):
				event["maxHp"] = int(previous_snapshot.get("max_hp", 1))
		var current_condition: String = get_condition_from_event_data(event)
		if current_condition != "" and not hp_event_helper.is_percentage_only_condition_event(event, false):
			current_conditions_by_ident[target_ident] = current_condition
		_debug("filled previousCondition target=%s previousCondition=%s event=%s" % [
			target_ident,
			previous_condition,
			JSON.stringify(event),
		])


func fill_missing_leftovers_heal_snapshot(event: Dictionary, target_ident: String, battle_state: BattleState) -> void:
	if target_ident == "":
		return

	var source_key: String = _normalize_event_source(str(event.get("source", ""))).to_lower().replace(" ", "")
	_debug("Checking heal snapshot target=%s source=%s source_key=%s event=%s" % [
		target_ident,
		str(event.get("source", "")),
		source_key,
		JSON.stringify(event),
	])
	if source_key != "leftovers":
		return

	var final_snapshot: Dictionary = hp_event_helper.get_event_hp_snapshot(event, false)
	var previous_snapshot: Dictionary = hp_event_helper.get_event_hp_snapshot(event, true)
	if not final_snapshot.is_empty() and not previous_snapshot.is_empty():
		var final_hp: int = int(final_snapshot.get("hp", 0))
		var previous_event_hp: int = int(previous_snapshot.get("hp", 0))
		if final_hp > previous_event_hp:
			_debug("Leftovers heal already has valid final snapshot target=%s event=%s" % [
				target_ident,
				JSON.stringify(event),
			])
			return

		_debug("Leftovers final snapshot has no healing; using fallback target=%s previous_hp=%s final_hp=%s event=%s" % [
			target_ident,
			str(previous_event_hp),
			str(final_hp),
			JSON.stringify(event),
		])

	_debug("Leftovers previous snapshot from event target=%s snapshot=%s" % [
		target_ident,
		JSON.stringify(previous_snapshot),
	])
	if previous_snapshot.is_empty():
		previous_snapshot = get_battle_hp_snapshot_for_ident(target_ident, battle_state)
		_debug("Leftovers previous snapshot from battle_state target=%s snapshot=%s" % [
			target_ident,
			JSON.stringify(previous_snapshot),
		])
	if previous_snapshot.is_empty():
		_debug("Leftovers fallback failed: no previous snapshot target=%s event=%s" % [
			target_ident,
			JSON.stringify(event),
		])
		return

	var previous_hp: int = int(previous_snapshot.get("hp", 0))
	var max_hp: int = max(int(previous_snapshot.get("max_hp", 1)), 1)
	if previous_hp <= 0 or previous_hp >= max_hp:
		_debug("Leftovers fallback skipped: previous_hp=%s max_hp=%s target=%s" % [
			str(previous_hp),
			str(max_hp),
			target_ident,
		])
		return

	var heal_amount: int = max(1, int(floor(float(max_hp) / 16.0)))
	var hp: int = min(previous_hp + heal_amount, max_hp)
	event["previousHp"] = previous_hp
	event["hp"] = hp
	event["maxHp"] = max_hp
	event["previousCondition"] = "%s/%s" % [previous_hp, max_hp]
	event["condition"] = "%s/%s" % [hp, max_hp]
	battle_state.apply_event_conditions([event])
	_debug("Leftovers fallback applied target=%s previous_hp=%s hp=%s max_hp=%s heal_amount=%s event=%s" % [
		target_ident,
		str(previous_hp),
		str(hp),
		str(max_hp),
		str(heal_amount),
		JSON.stringify(event),
	])


func get_condition_from_event_data(event: Dictionary) -> String:
	var condition: String = str(event.get("condition", ""))
	if condition != "":
		return condition

	if str(event.get("type", "")) == "faint":
		return "0 fnt"

	if event.has("hp") and event.has("maxHp"):
		var hp: int = int(event.get("hp", 0))
		var max_hp: int = max(int(event.get("maxHp", 1)), 1)
		if hp <= 0:
			return "0 fnt"

		return "%s/%s" % [hp, max_hp]

	return ""


func get_battle_hp_snapshot_for_ident(target_ident: String, battle_state: BattleState) -> Dictionary:
	var condition: String = get_battle_condition_for_ident(target_ident, battle_state)
	if condition == "":
		return {}

	return hp_event_helper.parse_condition_hp_snapshot(condition)


func get_battle_condition_for_ident(target_ident: String, battle_state: BattleState) -> String:
	var player_id: String = _get_player_id_from_ident(target_ident)
	if player_id == "":
		return ""

	var target_name: String = _get_ident_pokemon_name(target_ident)
	if target_name == "":
		return ""

	for pokemon_value in battle_state.get_player_team(player_id):
		if not (pokemon_value is Dictionary):
			continue

		var pokemon_data: Dictionary = pokemon_value as Dictionary
		if _get_ident_pokemon_name(str(pokemon_data.get("ident", ""))) != target_name:
			continue

		return str(pokemon_data.get("condition", ""))

	return ""


func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""


func _get_ident_pokemon_name(ident: String) -> String:
	if not ident.contains(": "):
		return ""

	return str(ident.split(": ")[1]).strip_edges().to_lower()


func _normalize_event_source(source: String) -> String:
	var cleaned := source.strip_edges()
	if cleaned.begins_with("[from] "):
		cleaned = cleaned.substr("[from] ".length()).strip_edges()

	if cleaned.contains(": "):
		cleaned = cleaned.split(": ")[1]

	return cleaned.strip_edges()


func _debug(message: String) -> void:
	if debug_enabled:
		print("[battle-hp] " + message)
