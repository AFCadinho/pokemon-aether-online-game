extends RefCounted

class_name BattleHpEventHelper

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

	if previous_percent >= 0 and current_percent >= 0:
		var condition_change: int = abs(previous_percent - current_percent)
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

func event_has_hp_loss(event: Dictionary) -> bool:
	if is_percentage_only_condition_event(event, false):
		return false

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

func get_condition_visible_hp_percent(condition: String) -> int:
	if condition.contains("fnt"):
		return 0

	if not condition.contains("/"):
		return -1

	var current_hp: int = int(condition.split("/")[0])
	var right: String = str(condition.split("/")[1])
	var max_hp: int = int(right.split(" ")[0])
	return to_visible_hp_percent(current_hp, max_hp)
