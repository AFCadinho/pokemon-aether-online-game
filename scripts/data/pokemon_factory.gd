extends RefCounted

class_name PokemonFactory

## Materializes backend-created Pokemon payloads into runtime Pokemon objects.
##
## Godot should not create Pokemon from local species/move JSON anymore.

static var last_error_message: String = ""


static func create_pokemon_from_backend_payload(data: Dictionary) -> Pokemon:
	last_error_message = ""
	var species := str(data.get("species", data.get("species_id", "")))
	if species == "":
		last_error_message = "Missing species in backend Pokemon payload."
		return null

	var caught_ball_item_id := _get_payload_caught_ball_item_id(data)
	var ball_item_id := _get_payload_ball_item_id(data, caught_ball_item_id)
	var pokemon := Pokemon.new(
		species,
		int(data.get("level", 1)),
		str(data.get("item", "")),
		str(data.get("ability", "")),
		str(data.get("nature", "Hardy")),
		data.get("evs", {}),
		data.get("ivs", {}),
		data.get("stats", {}),
		_get_payload_moves(data),
		str(data.get("instanceId", data.get("instance_id", ""))),
		_get_int_option(data, ["ownedPokemonId", "owned_pokemon_id", "pokemonId", "pokemon_id"]),
		_get_bool_option(data, ["shiny", "isShiny", "is_shiny"]),
		_has_hp_override(data),
		_get_payload_types(data),
		_get_payload_possible_abilities(data),
		_get_origin_location(data),
		_get_origin_payload(data),
		_get_bool_option(data, ["tradable", "isTradable", "is_tradable"], true),
		_get_stored_evs_payload(data),
		ball_item_id,
		caught_ball_item_id
	)

	pokemon.max_hp = max(int(data.get("maxHp", data.get("max_hp", pokemon.max_hp))), 1)
	pokemon.current_hp = int(clamp(int(data.get("currentHp", data.get("current_hp", pokemon.max_hp))), 0, pokemon.max_hp))
	pokemon.has_saved_hp_state = data.has("currentHp") or data.has("current_hp") or data.has("maxHp") or data.has("max_hp")
	return pokemon


static func _get_payload_moves(data: Dictionary) -> Array:
	var moves: Array = []
	var moves_value: Variant = data.get("moves", [])
	if not (moves_value is Array):
		return moves

	for move: Variant in moves_value:
		if move is Dictionary:
			moves.append((move as Dictionary).duplicate(true))
		else:
			moves.append(str(move))

	return moves.slice(0, 4)


static func _get_payload_types(data: Dictionary) -> Array:
	return _normalize_type_array(data.get("types", []))


static func _get_payload_possible_abilities(data: Dictionary) -> Array:
	return _normalize_string_array(data.get("possibleAbilities", data.get("possible_abilities", [])))


static func _get_stored_evs_payload(data: Dictionary) -> Dictionary:
	for key in ["storedEvs", "stored_evs", "pendingEvs", "pending_evs"]:
		var value: Variant = data.get(key, {})
		if value is Dictionary:
			return (value as Dictionary).duplicate(true)

	return {}


static func _get_origin_payload(data: Dictionary) -> Dictionary:
	var origin_value: Variant = data.get("origin", {})
	if origin_value is Dictionary:
		return (origin_value as Dictionary).duplicate(true)

	var location_name: String = _get_string_option(data, ["location", "caughtLocation", "caught_location", "metLocation", "met_location", "encounterArea", "encounter_area"])
	if location_name == "":
		return {}

	return {
		"locationName": location_name,
	}


static func _get_origin_location(data: Dictionary) -> String:
	var origin: Dictionary = _get_origin_payload(data)
	var location_name: String = str(origin.get("locationName", origin.get("location", ""))).strip_edges()
	if location_name != "":
		return location_name

	return _get_string_option(data, ["location", "caughtLocation", "caught_location", "metLocation", "met_location", "encounterArea", "encounter_area"])


static func _get_payload_ball_item_id(data: Dictionary, fallback_caught_ball_item_id: String = "") -> String:
	var ball_item_id := _get_normalized_item_option(data, ["ballItemId", "ball_item_id", "summonBallItemId", "summon_ball_item_id"])
	if ball_item_id != "":
		return ball_item_id

	return fallback_caught_ball_item_id if fallback_caught_ball_item_id != "" else "poke-ball"


static func _get_payload_caught_ball_item_id(data: Dictionary) -> String:
	var caught_ball_item_id := _get_normalized_item_option(data, ["caughtBallItemId", "caught_ball_item_id", "caughtWith", "caught_with"])
	if caught_ball_item_id != "":
		return caught_ball_item_id

	var origin_value: Variant = data.get("origin", {})
	if origin_value is Dictionary:
		var origin := origin_value as Dictionary
		caught_ball_item_id = _normalize_item_id(str(origin.get("ball", origin.get("ballItemId", origin.get("ball_item_id", "")))))
		if caught_ball_item_id != "":
			return caught_ball_item_id

	return ""


static func _normalize_type_array(value: Variant) -> Array:
	return _normalize_string_array(value)


static func _normalize_string_array(value: Variant) -> Array:
	var values: Array = []
	if not (value is Array):
		return values

	for item in value:
		values.append(str(item))

	return values


static func _get_bool_option(options: Dictionary, keys: Array, default_value: bool = false) -> bool:
	for key in keys:
		if not options.has(key):
			continue

		var value: Variant = options.get(key)
		if value is bool:
			return bool(value)

		var text_value: String = str(value).strip_edges().to_lower()
		match text_value:
			"true", "yes", "1", "y":
				return true
			"false", "no", "0", "n":
				return false

	return default_value


static func _get_int_option(options: Dictionary, keys: Array, default_value: int = 0) -> int:
	for key in keys:
		if not options.has(key):
			continue

		var value: Variant = options.get(key)
		if value is int:
			return max(int(value), 0)
		if value is float:
			return max(int(value), 0)

		var text_value: String = str(value).strip_edges()
		if text_value.is_valid_int():
			return max(int(text_value), 0)

	return default_value


static func _get_string_option(options: Dictionary, keys: Array, default_value: String = "") -> String:
	for key in keys:
		if not options.has(key):
			continue

		var text_value: String = str(options.get(key)).strip_edges()
		if text_value != "":
			return text_value

	return default_value


static func _get_normalized_item_option(options: Dictionary, keys: Array, default_value: String = "") -> String:
	return _normalize_item_id(_get_string_option(options, keys, default_value))


static func _normalize_item_id(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")


static func _has_hp_override(options: Dictionary) -> bool:
	return (
		options.has("currentHp")
		or options.has("current_hp")
		or options.has("maxHp")
		or options.has("max_hp")
	)
