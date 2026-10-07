extends RefCounted


static func from_pokemon_data(pokemon_data: Dictionary) -> int:
	var parsed_level := _parse_level(pokemon_data.get("level", null))
	if parsed_level >= 1 and (parsed_level <= 100 or parsed_level == 120):
		return parsed_level

	# Public spectator snapshots can carry the level only in Showdown details.
	var details_value: Variant = pokemon_data.get("details", "")
	if details_value is String:
		var details := (details_value as String).split(",")
		for index in range(1, details.size()):
			var token := details[index].strip_edges()
			if token.length() < 2 or token.substr(0, 1).to_upper() != "L":
				continue
			var details_level := _parse_level(token.substr(1))
			if details_level >= 1 and (details_level <= 100 or details_level == 120):
				return details_level

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
