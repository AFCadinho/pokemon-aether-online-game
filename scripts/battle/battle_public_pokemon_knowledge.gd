extends RefCounted


static func from_pokemon_data(pokemon_data: Dictionary) -> Dictionary:
	var knowledge_value: Variant = pokemon_data.get("knowledge", {})
	if not (knowledge_value is Dictionary):
		return {}

	var knowledge: Dictionary = knowledge_value as Dictionary
	var safe_knowledge := {}
	var moves_value: Variant = knowledge.get("confirmedMoves", knowledge.get("confirmed_moves", []))
	if moves_value is Array:
		var safe_moves: Array = []
		var moves: Array = moves_value as Array
		for index in range(mini(moves.size(), 4)):
			var move_value: Variant = moves[index]
			if not (move_value is Dictionary):
				continue
			var move: Dictionary = move_value as Dictionary
			var name_value: Variant = move.get("name", "")
			if typeof(name_value) != TYPE_STRING:
				continue
			var name := str(name_value).strip_edges()
			if name == "":
				continue
			var safe_move := {"name": name}
			var max_pp := -1
			for key in ["pp", "maxpp"]:
				var amount: Variant = move.get(key, null)
				var normalized_amount: Variant = _get_bounded_integer(amount, 0, 99)
				if normalized_amount == null:
					continue
				safe_move[key] = int(normalized_amount)
				if key == "maxpp":
					max_pp = int(normalized_amount)
			if safe_move.has("pp") and max_pp >= 0 and int(safe_move.get("pp")) > max_pp:
				safe_move.erase("pp")
			safe_moves.append(safe_move)
		if not safe_moves.is_empty():
			safe_knowledge["confirmedMoves"] = safe_moves

	for key in ["confirmedItem", "confirmedAbility"]:
		var confirmed_value: Variant = knowledge.get(key, "")
		if typeof(confirmed_value) != TYPE_STRING:
			continue
		var confirmed := str(confirmed_value).strip_edges()
		if confirmed != "":
			safe_knowledge[key] = confirmed

	var stat_changes_value: Variant = knowledge.get("statChanges", knowledge.get("stat_changes", {}))
	if stat_changes_value is Dictionary:
		var safe_stat_changes := {}
		for stat in ["atk", "def", "spa", "spd", "spe", "accuracy", "evasion"]:
			var amount: Variant = (stat_changes_value as Dictionary).get(stat, null)
			var normalized_amount: Variant = _get_bounded_integer(amount, -6, 6)
			if normalized_amount != null:
				safe_stat_changes[stat] = int(normalized_amount)
		if not safe_stat_changes.is_empty():
			safe_knowledge["statChanges"] = safe_stat_changes

	return safe_knowledge


static func _get_bounded_integer(value: Variant, minimum: int, maximum: int) -> Variant:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return null

	var numeric_value := float(value)
	if not is_finite(numeric_value) or numeric_value != floor(numeric_value):
		return null

	var integer_value := int(numeric_value)
	if integer_value < minimum or integer_value > maximum:
		return null

	return integer_value
