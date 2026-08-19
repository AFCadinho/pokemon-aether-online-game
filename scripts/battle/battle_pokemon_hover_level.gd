extends RefCounted


static func from_pokemon_data(pokemon_data: Dictionary) -> int:
	var parsed_level := _parse_level(pokemon_data.get("level", null))
	if parsed_level >= 1 and parsed_level <= 100:
		return parsed_level

	return 100


static func _parse_level(value: Variant) -> int:
	if value is int:
		return int(value)
	if value is float:
		var numeric_value := float(value)
		if is_finite(numeric_value) and numeric_value == floor(numeric_value):
			return int(numeric_value)
		return -1
	if value is String:
		var text: String = value.strip_edges()
		if text.is_valid_int():
			return text.to_int()

	return -1
