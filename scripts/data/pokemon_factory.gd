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
		caught_ball_item_id,
		_get_int_option(data, ["experience", "exp", "currentExp", "current_exp"]),
		_get_int_option(data, ["currentLevelExp", "current_level_exp", "levelStartExp", "level_start_exp"]),
		_get_int_option(data, ["nextLevelExp", "next_level_exp"]),
		_get_int_option(data, ["experienceToNextLevel", "experience_to_next_level", "expToNextLevel", "exp_to_next_level"]),
		_get_string_option(data, ["growthRate", "growth_rate"]),
		_get_int_option(data, ["baseExperience", "base_experience"]),
		_get_payload_status(data),
		_get_int_option(data, ["happiness", "friendship"], Pokemon.DEFAULT_HAPPINESS)
	)

	_apply_payload_hp_state(pokemon, data)
	pokemon.national_dex_number = _get_int_option(data, ["nationalDexNumber", "national_dex_number", "dexNumber", "dex_number"])
	pokemon.species_id = _get_string_option(data, ["speciesId", "species_id"])
	pokemon.showdown_id = _get_string_option(data, ["showdownId", "showdown_id"])
	pokemon.nickname = _get_string_option(data, ["nickname", "nickName", "displayName", "display_name", "name"])
	pokemon.gender = _normalize_pokemon_gender(_get_string_option(data, ["gender", "sex"]))
	pokemon.can_evolve = bool(data.get("canEvolve", data.get("can_evolve", false)))
	pokemon.hidden_ability = _get_bool_option(data, ["hiddenAbility", "hidden_ability"])
	pokemon.special_lineage = _get_string_option(data, ["specialLineage", "special_lineage"]).strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	return pokemon


static func _normalize_pokemon_gender(value: String) -> String:
	match value.strip_edges().to_lower():
		"m", "male", "masculine", "♂":
			return "male"
		"f", "female", "feminine", "♀":
			return "female"
		"n", "genderless", "none", "neutral":
			return "genderless"
	return ""


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
	var origin: Dictionary = {}
	if origin_value is Dictionary:
		origin = (origin_value as Dictionary).duplicate(true)

	var location_name: String = _get_string_option(data, ["location", "caughtLocation", "caught_location", "metLocation", "met_location", "encounterArea", "encounter_area"])
	if location_name != "" and str(origin.get("locationName", origin.get("location", ""))).strip_edges() == "":
		origin["locationName"] = location_name

	var original_trainer_name := _get_string_option(data, ["originalTrainerName", "original_trainer_name", "otName", "ot_name"])
	if original_trainer_name != "" and str(origin.get("originalTrainerName", origin.get("original_trainer_name", ""))).strip_edges() == "":
		origin["originalTrainerName"] = original_trainer_name

	var original_trainer_user_id := _get_int_option(data, ["originalTrainerUserId", "original_trainer_user_id", "originalOwnerUserId", "original_owner_user_id"])
	if original_trainer_user_id > 0 and int(origin.get("originalTrainerUserId", origin.get("original_trainer_user_id", 0))) <= 0:
		origin["originalTrainerUserId"] = original_trainer_user_id

	var current_trainer_name := _get_string_option(data, ["currentTrainerName", "current_trainer_name", "ownerName", "owner_name"])
	if current_trainer_name != "" and str(origin.get("currentTrainerName", origin.get("current_trainer_name", origin.get("ownerName", origin.get("owner_name", ""))))).strip_edges() == "":
		origin["currentTrainerName"] = current_trainer_name

	var current_trainer_user_id := _get_int_option(data, ["currentTrainerUserId", "current_trainer_user_id", "ownerUserId", "owner_user_id", "holderUserId", "holder_user_id"])
	if current_trainer_user_id > 0 and int(origin.get("currentTrainerUserId", origin.get("current_trainer_user_id", 0))) <= 0:
		origin["currentTrainerUserId"] = current_trainer_user_id

	return origin


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

		var value: Variant = options.get(key)
		if value == null:
			continue
		var text_value: String = str(value).strip_edges()
		if text_value != "":
			return text_value

	return default_value


static func _get_normalized_item_option(options: Dictionary, keys: Array, default_value: String = "") -> String:
	return _normalize_item_id(_get_string_option(options, keys, default_value))


static func _normalize_item_id(value: String) -> String:
	return value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")


static func _get_payload_status(data: Dictionary) -> String:
	var direct_status := _normalize_status(_get_string_option(data, ["status", "battleStatus", "battle_status"]))
	if direct_status != "":
		return direct_status

	return _get_status_from_condition(_get_string_option(data, ["condition", "hpCondition", "hp_condition"]))


static func _get_status_from_condition(condition: String) -> String:
	for part_value: String in condition.strip_edges().split(" ", false):
		var status := _normalize_status(part_value)
		if status != "":
			return status

	return ""


static func _normalize_status(value: String) -> String:
	match value.strip_edges().to_lower():
		"psn", "poison", "poisoned":
			return "psn"
		"tox", "toxic", "badly_poisoned", "badlypoisoned":
			return "tox"
		"brn", "burn", "burned":
			return "brn"
		"par", "paralysis", "paralyzed":
			return "par"
		"slp", "sleep", "sleeping", "asleep":
			return "slp"
		"frz", "freeze", "frozen":
			return "frz"

	return ""


static func _has_hp_override(options: Dictionary) -> bool:
	return (
		options.has("currentHp")
		or options.has("current_hp")
		or options.has("maxHp")
		or options.has("max_hp")
		or str(options.get("condition", "")).strip_edges() != ""
	)


static func _apply_payload_hp_state(pokemon: Pokemon, data: Dictionary) -> void:
	if not _has_hp_override(data):
		return

	var condition_hp := _get_hp_from_condition(str(data.get("condition", "")).strip_edges())
	var fallback_max_hp: int = int(condition_hp.get("max_hp", pokemon.max_hp)) if not condition_hp.is_empty() else pokemon.max_hp
	var max_hp: int = max(int(data.get("maxHp", data.get("max_hp", fallback_max_hp))), 1)
	var fallback_current_hp: int = int(condition_hp.get("current_hp", max_hp)) if not condition_hp.is_empty() else max_hp
	var current_hp: int = int(data.get("currentHp", data.get("current_hp", fallback_current_hp)))
	var has_stat_max_hp: bool = _has_stat_max_hp(pokemon)
	var stat_max_hp: int = _get_stat_max_hp(pokemon)

	if current_hp <= 0 and max_hp == 1:
		pokemon.max_hp = stat_max_hp if has_stat_max_hp else max_hp
		pokemon.current_hp = 0
		pokemon.has_saved_hp_state = true
		return

	if max_hp == 100 and has_stat_max_hp and stat_max_hp != 100:
		var hp_percent: int = int(clamp(current_hp, 0, 100))
		pokemon.max_hp = stat_max_hp
		pokemon.current_hp = int(round((float(hp_percent) / 100.0) * float(stat_max_hp)))
	else:
		pokemon.max_hp = max_hp
		pokemon.current_hp = int(clamp(current_hp, 0, pokemon.max_hp))

	pokemon.has_saved_hp_state = true


static func _get_hp_from_condition(condition: String) -> Dictionary:
	var normalized_condition := condition.strip_edges().to_lower()
	if normalized_condition == "":
		return {}
	if normalized_condition == "0 fnt" or normalized_condition.ends_with(" fnt"):
		return {
			"current_hp": 0,
			"max_hp": 1,
		}

	var hp_text := normalized_condition.split(" ", false)[0]
	if not hp_text.contains("/"):
		return {}

	var hp_parts := hp_text.split("/", false)
	if hp_parts.size() < 2:
		return {}

	return {
		"current_hp": int(float(hp_parts[0])),
		"max_hp": max(int(float(hp_parts[1])), 1),
	}


static func _get_stat_max_hp(pokemon: Pokemon) -> int:
	return max(int(pokemon.stats.get("hp", pokemon.max_hp)), 1)


static func _has_stat_max_hp(pokemon: Pokemon) -> bool:
	return pokemon.stats.has("hp") and int(pokemon.stats.get("hp", 0)) > 0
