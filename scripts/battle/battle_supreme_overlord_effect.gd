extends RefCounted

class_name BattleSupremeOverlordEffect


static func get_fallen_count(effect: String) -> int:
	var effect_key := effect.strip_edges().to_lower().replace(" ", "").replace("-", "").replace("_", "")
	if not effect_key.begins_with("fallen"):
		return -1

	var count_text := effect_key.substr("fallen".length())
	if count_text == "" or not count_text.is_valid_int():
		return -1

	var count := int(count_text)
	if count < 0 or count > 5:
		return -1
	return count


static func is_fallen_effect(effect: String) -> bool:
	return get_fallen_count(effect) >= 0


static func update_fallen_by_ident(
	fallen_by_ident: Dictionary,
	ident_key: String,
	effect: String,
	state: String
) -> bool:
	var fallen_count := get_fallen_count(effect)
	if ident_key == "" or fallen_count < 0:
		return false

	match state.strip_edges().to_lower():
		"start", "activate":
			fallen_by_ident[ident_key] = fallen_count
		"end", "cure", "cured":
			fallen_by_ident.erase(ident_key)
		_:
			return false
	return true
