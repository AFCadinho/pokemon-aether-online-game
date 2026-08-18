extends RefCounted

class_name BattleHpEventHelper

var _presentation_hp_cursor_by_target: Dictionary = {}


func get_event_hp_snapshot(event: Dictionary, use_previous_hp: bool) -> Dictionary:
	var condition_key: String = "previousCondition" if use_previous_hp else "condition"
	var condition_snapshot := parse_condition_hp_snapshot(str(event.get(condition_key, "")))
	if use_previous_hp and not condition_snapshot.is_empty():
		return condition_snapshot

	var hp_key: String = "previousHp" if use_previous_hp else "hp"
	if event.has(hp_key) and event.has("maxHp"):
		return {
			"hp": int(event.get(hp_key, 0)),
			"max_hp": max(int(event.get("maxHp", 1)), 1),
		}

	return condition_snapshot


func get_rewind_hp_snapshot(event: Dictionary, state_snapshot: Dictionary) -> Dictionary:
	var previous_snapshot: Dictionary = get_event_hp_snapshot(event, true)
	if previous_snapshot.is_empty():
		return previous_snapshot

	var current_snapshot: Dictionary = get_event_hp_snapshot(event, false)
	if current_snapshot.is_empty():
		return previous_snapshot

	var previous_percent := to_visible_hp_percent(
		int(previous_snapshot.get("hp", 0)),
		int(previous_snapshot.get("max_hp", 0))
	)
	var current_percent := to_visible_hp_percent(
		int(current_snapshot.get("hp", 0)),
		int(current_snapshot.get("max_hp", 0))
	)
	if event.has("previousHp") and event.has("hp") and int(event.get("maxHp", 0)) > 0:
		var numeric_max_hp := int(event.get("maxHp", 0))
		var numeric_previous_percent := to_visible_hp_percent(int(event.get("previousHp", 0)), numeric_max_hp)
		if current_percent < numeric_previous_percent and numeric_previous_percent < previous_percent:
			return {
				"hp": int(event.get("previousHp", 0)),
				"max_hp": numeric_max_hp,
			}

	if state_snapshot.is_empty():
		return previous_snapshot

	var state_percent := to_visible_hp_percent(
		int(state_snapshot.get("hp", 0)),
		int(state_snapshot.get("max_hp", 0))
	)
	var state_is_between_damage := current_percent < state_percent and state_percent < previous_percent
	var state_is_between_heal := previous_percent < state_percent and state_percent < current_percent
	if state_is_between_damage or state_is_between_heal:
		return state_snapshot.duplicate(true)

	return previous_snapshot


func normalize_damage_event_continuity(events: Array) -> Array:
	var normalized_events: Array = events.duplicate(true)

	for event_value: Variant in normalized_events:
		if not (event_value is Dictionary):
			continue

		var event: Dictionary = event_value as Dictionary
		var event_type := str(event.get("type", ""))
		if event_type == "switch" or event_type == "drag":
			# Active idents may be reused by the incoming Pokemon. Never carry an
			# outgoing Pokemon's rendered HP into the next switch target.
			_presentation_hp_cursor_by_target.clear()
			continue
		if event_type != "damage" and event_type != "heal" and event_type != "faint":
			continue

		var target_key := _get_hp_event_target_key(event)
		if target_key == "":
			continue

		if event_type == "damage" and _presentation_hp_cursor_by_target.has(target_key):
			_clamp_damage_rewind_to_cursor(event, _presentation_hp_cursor_by_target[target_key])

		var current_snapshot := get_event_hp_snapshot(event, false)
		if current_snapshot.is_empty():
			continue
		current_snapshot["condition"] = str(event.get("condition", ""))
		_presentation_hp_cursor_by_target[target_key] = current_snapshot

	return normalized_events


func _clamp_damage_rewind_to_cursor(event: Dictionary, cursor_value: Variant) -> void:
	if not (cursor_value is Dictionary):
		return

	var cursor: Dictionary = cursor_value as Dictionary
	var previous_snapshot := get_event_hp_snapshot(event, true)
	var current_snapshot := get_event_hp_snapshot(event, false)
	if event.has("previousHp") and event.has("hp") and int(event.get("maxHp", 0)) > 0:
		var numeric_max_hp := int(event.get("maxHp", 0))
		previous_snapshot = {
			"hp": int(event.get("previousHp", 0)),
			"max_hp": numeric_max_hp,
		}
		current_snapshot = {
			"hp": int(event.get("hp", 0)),
			"max_hp": numeric_max_hp,
		}
	if previous_snapshot.is_empty() or current_snapshot.is_empty():
		return

	var cursor_max_hp := int(cursor.get("max_hp", 0))
	var previous_max_hp := int(previous_snapshot.get("max_hp", 0))
	var current_max_hp := int(current_snapshot.get("max_hp", 0))
	if cursor_max_hp <= 0 or previous_max_hp <= 0 or current_max_hp <= 0:
		return

	var cursor_hp := int(cursor.get("hp", 0))
	var previous_hp := int(previous_snapshot.get("hp", 0))
	var current_hp := int(current_snapshot.get("hp", 0))
	var cursor_percent := to_visible_hp_percent(cursor_hp, cursor_max_hp)
	var previous_percent := to_visible_hp_percent(previous_hp, previous_max_hp)
	var current_percent := to_visible_hp_percent(current_hp, current_max_hp)
	if previous_percent <= cursor_percent or current_percent > cursor_percent:
		return

	var event_max_hp := int(event.get("maxHp", 0))
	if event_max_hp > 0:
		event["previousHp"] = clamp(
			roundi((float(cursor_hp) / float(cursor_max_hp)) * float(event_max_hp)),
			0,
			event_max_hp
		)
	var cursor_condition := str(cursor.get("condition", ""))
	if cursor_condition != "":
		event["previousCondition"] = cursor_condition
	else:
		event["previousCondition"] = "%d/%d" % [cursor_hp, cursor_max_hp]


func _get_hp_event_target_key(event: Dictionary) -> String:
	for key in ["pokemonKey", "pokemon_key"]:
		var pokemon_key := str(event.get(key, "")).strip_edges()
		if pokemon_key != "":
			return "pokemon:%s" % pokemon_key

	for ref_key in ["targetRef", "target_ref"]:
		var target_ref_value: Variant = event.get(ref_key, {})
		if not (target_ref_value is Dictionary):
			continue
		var target_ref: Dictionary = target_ref_value as Dictionary
		var pokemon_key := str(target_ref.get("pokemonKey", target_ref.get("pokemon_key", ""))).strip_edges()
		if pokemon_key != "":
			return "pokemon:%s" % pokemon_key

	var target := str(event.get("target", "")).strip_edges().to_lower()
	if target != "":
		return "target:%s" % target

	return ""

func get_event_status(event: Dictionary, use_previous_hp: bool) -> String:
	var condition_key: String = "previousCondition" if use_previous_hp else "condition"
	return get_status_from_condition(str(event.get(condition_key, "")))

func is_percentage_only_condition_event(event: Dictionary, use_previous_hp: bool) -> bool:
	var hp_key: String = "previousHp" if use_previous_hp else "hp"
	if event.has(hp_key):
		return false

	var condition_key: String = "previousCondition" if use_previous_hp else "condition"
	var condition_snapshot: Dictionary = parse_condition_hp_snapshot(str(event.get(condition_key, "")))
	if condition_snapshot.is_empty():
		return false

	var condition_max_hp: int = int(condition_snapshot.get("max_hp", 0))
	var event_max_hp: int = int(event.get("maxHp", 0))
	return condition_max_hp == 100 and event_max_hp > 100

func parse_condition_hp_snapshot(condition: String) -> Dictionary:
	if condition == "":
		return {}

	if condition.contains("fnt"):
		if condition.begins_with("0"):
			return {
				"hp": 0,
				"max_hp": 1,
			}

		return {}

	if not condition.contains("/"):
		return {}

	var parts: PackedStringArray = condition.split("/")
	if parts.size() < 2:
		return {}

	var hp: int = int(parts[0])
	var max_hp_text: String = str(parts[1]).split(" ")[0]
	var max_hp: int = max(int(max_hp_text), 1)
	return {
		"hp": hp,
		"max_hp": max_hp,
	}

func apply_condition_fields(pokemon_data: Dictionary, condition: String) -> void:
	pokemon_data["status"] = get_status_from_condition(condition)
	pokemon_data["fainted"] = condition.contains("fnt")

	if bool(pokemon_data["fainted"]):
		pokemon_data["hp"] = 0
		return

	var hp_snapshot := parse_condition_hp_snapshot(condition)
	if hp_snapshot.is_empty():
		return

	pokemon_data["hp"] = int(hp_snapshot.get("hp", 0))
	pokemon_data["maxHp"] = int(hp_snapshot.get("max_hp", 0))

func get_status_from_condition(condition: String) -> String:
	var parts: PackedStringArray = condition.split(" ")
	for part in parts:
		var status: String = str(part).strip_edges().to_lower()
		match status:
			"psn", "tox", "brn", "par", "slp", "frz":
				return status

	return ""

func to_visible_hp_percent(hp: int, max_hp: int) -> int:
	if max_hp <= 0:
		return 0

	if hp <= 0:
		return 0

	var clamped_hp: int = clamp(hp, 0, max_hp)
	return clamp(ceili((float(clamped_hp) / float(max_hp)) * 100.0), 0, 100)

func get_visible_hp_change(previous_hp: int, hp: int, max_hp: int) -> int:
	var previous_percent := to_visible_hp_percent(previous_hp, max_hp)
	var current_percent := to_visible_hp_percent(hp, max_hp)
	return abs(previous_percent - current_percent)

func get_event_visible_hp_change(event: Dictionary) -> int:
	var previous_condition := str(event.get("previousCondition", ""))
	var condition := str(event.get("condition", ""))
	var previous_percent: int = get_condition_visible_hp_percent(previous_condition)
	var current_percent: int = get_condition_visible_hp_percent(condition)
	var numeric_hp_loss_change: int = _get_numeric_hp_loss_visible_change(event)

	if previous_percent >= 0 and current_percent >= 0:
		var condition_change: int = abs(previous_percent - current_percent)
		if numeric_hp_loss_change >= 0:
			if condition_change == 0:
				return numeric_hp_loss_change
			if abs(condition_change - numeric_hp_loss_change) > 1:
				return numeric_hp_loss_change
		if condition_change == 0:
			var amount_from_condition: int = int(event.get("amount", 0))
			var max_hp_from_condition: int = int(event.get("maxHp", 0))
			if amount_from_condition > 0 and max_hp_from_condition > 0:
				var amount_condition_change: int = get_visible_hp_change(amount_from_condition, 0, max_hp_from_condition)
				return amount_condition_change
		return condition_change

	var previous_hp: int = int(event.get("previousHp", 0))
	var hp: int = int(event.get("hp", 0))
	var max_hp: int = int(event.get("maxHp", 0))
	if max_hp > 0:
		var amount: int = int(event.get("amount", 0))
		if amount > 0 and (previous_hp <= 0 or hp <= 0):
			var amount_change: int = get_visible_hp_change(amount, 0, max_hp)
			return amount_change

		var hp_change: int = get_visible_hp_change(previous_hp, hp, max_hp)
		return hp_change

	if current_percent >= 0:
		var current_only_change: int = abs(100 - current_percent)
		return current_only_change

	return 0

func get_event_damage_percent(event: Dictionary) -> float:
	var public_damage_percent: float = float(event.get("damagePercent", 0.0))
	if is_finite(public_damage_percent) and public_damage_percent > 0.0:
		return public_damage_percent

	var previous_hp: int = int(event.get("previousHp", 0))
	var hp: int = int(event.get("hp", 0))
	var max_hp: int = int(event.get("maxHp", 0))
	var amount: int = int(event.get("amount", 0))
	if previous_hp > hp and amount > 0 and max_hp > 0:
		return (float(amount) / float(max_hp)) * 100.0
	return float(get_event_visible_hp_change(event))

func event_has_hp_loss(event: Dictionary) -> bool:
	if is_percentage_only_condition_event(event, false):
		return false

	if _event_has_numeric_hp_loss(event):
		return true

	var previous_snapshot: Dictionary = get_event_hp_snapshot(event, true)
	var snapshot: Dictionary = get_event_hp_snapshot(event, false)
	if not previous_snapshot.is_empty() and not snapshot.is_empty():
		var snapshot_loss: bool = int(previous_snapshot.get("hp", 0)) > int(snapshot.get("hp", 0))
		if not snapshot_loss and int(event.get("amount", 0)) > 0 and int(event.get("maxHp", 0)) > 0:
			return true
		return snapshot_loss

	var amount: int = int(event.get("amount", 0))
	var max_hp: int = int(event.get("maxHp", 0))
	if amount > 0 and max_hp > 0:
		return true

	if not snapshot.is_empty():
		var current_loss: bool = int(snapshot.get("hp", 0)) < int(snapshot.get("max_hp", 0))
		return current_loss

	return false

func event_has_sub_percent_hp_loss(event: Dictionary) -> bool:
	var amount: int = int(event.get("amount", 0))
	var max_hp: int = int(event.get("maxHp", 0))
	if amount <= 0 or max_hp <= 0:
		return false

	return to_visible_hp_percent(amount, max_hp) <= 1

func _event_has_numeric_hp_loss(event: Dictionary) -> bool:
	if not event.has("previousHp") or not event.has("hp") or not event.has("maxHp"):
		return false

	var max_hp: int = int(event.get("maxHp", 0))
	if max_hp <= 0:
		return false

	var previous_hp: int = int(event.get("previousHp", 0))
	var hp: int = int(event.get("hp", 0))
	return previous_hp > hp

func _get_numeric_hp_loss_visible_change(event: Dictionary) -> int:
	if not _event_has_numeric_hp_loss(event):
		return -1
	var previous_hp: int = int(event.get("previousHp", 0))
	var hp: int = int(event.get("hp", 0))
	var max_hp: int = int(event.get("maxHp", 0))
	return get_visible_hp_change(previous_hp, hp, max_hp)

func get_condition_visible_hp_percent(condition: String) -> int:
	if condition.contains("fnt"):
		return 0

	if not condition.contains("/"):
		return -1

	var current_hp: int = int(condition.split("/")[0])
	var right: String = str(condition.split("/")[1])
	var max_hp: int = int(right.split(" ")[0])
	return to_visible_hp_percent(current_hp, max_hp)
