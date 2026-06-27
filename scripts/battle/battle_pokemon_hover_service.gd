extends RefCounted

class_name BattlePokemonHoverService

var pokemon_stats_cache: Dictionary = {}
var debug_enabled := false

func clear_cache() -> void:
	pokemon_stats_cache.clear()

func get_hover_card_data(
	battle_state: BattleState,
	pokemon_info_request: HTTPRequest,
	pokemon_stats_request: HTTPRequest,
	pokemon_data: Dictionary,
	public_confirmed_abilities_by_ident: Dictionary,
	public_confirmed_items_by_ident: Dictionary = {},
	viewer_id_override: String = "",
	ident_override: String = ""
) -> Dictionary:
	var requested_ident := str(pokemon_data.get("ident", ""))
	var requested_lookup_ident := ident_override.strip_edges()
	if requested_lookup_ident == "":
		requested_lookup_ident = requested_ident
	var requested_species := battle_state.get_species_from_pokemon_data(pokemon_data)
	var pokemon_info: Dictionary = await _fetch_hover_pokemon_info(
		battle_state,
		pokemon_info_request,
		pokemon_data,
		viewer_id_override,
		ident_override
	)
	var pokemon_stats: Dictionary = await _fetch_hover_pokemon_stats(
		battle_state,
		pokemon_stats_request,
		pokemon_data
	)

	return {
		"requested_ident": requested_ident,
		"requested_lookup_ident": requested_lookup_ident,
		"requested_species": requested_species,
		"confirmed_moves": _get_confirmed_info_moves(pokemon_info),
		"confirmed_item": _get_confirmed_item_for_hover(
			pokemon_info,
			pokemon_data,
			public_confirmed_items_by_ident
		),
		"confirmed_ability": _get_confirmed_ability_for_hover(
			pokemon_info,
			pokemon_data,
			public_confirmed_abilities_by_ident
		),
		"stat_changes": _get_confirmed_info_stat_changes(pokemon_info),
		"speed_data": _get_hover_speed_data(pokemon_stats),
		"species_metadata": _get_hover_species_metadata(pokemon_stats),
		"pokemon_info": pokemon_info,
	}

func _fetch_hover_pokemon_info(
	battle_state: BattleState,
	request_node: HTTPRequest,
	pokemon_data: Dictionary,
	viewer_id_override: String = "",
	ident_override: String = ""
) -> Dictionary:
	var battle_id: String = battle_state.battle_id
	var ident: String = ident_override.strip_edges()
	if ident == "":
		ident = str(pokemon_data.get("ident", ""))
	if battle_id == "" or ident == "":
		_debug_battle_move("pokemon-info skipped battle_id=%s ident=%s pokemon=%s" % [
			battle_id,
			ident,
			JSON.stringify(pokemon_data),
		])
		return {}

	var viewer_id: String = viewer_id_override.strip_edges()
	if viewer_id == "":
		viewer_id = _get_hover_known_info_viewer_id(ident)
	if viewer_id == "":
		return {}

	_debug_battle_move("pokemon-info request viewerId=%s ident=%s battleId=%s" % [viewer_id, ident, battle_id])
	var response: Dictionary = await BattleApiClient.get_pokemon_info(
		request_node,
		battle_id,
		viewer_id,
		ident
	)
	_debug_battle_move("pokemon-info response=%s" % JSON.stringify(response))
	if not bool(response.get("success", false)):
		return {}

	var pokemon_value: Variant = response.get("pokemon", {})
	if pokemon_value is Dictionary:
		var pokemon_info: Dictionary = pokemon_value as Dictionary
		var response_ident := str(pokemon_info.get("ident", ""))
		if response_ident != "" and _normalize_battle_ident(response_ident) != _normalize_battle_ident(ident):
			_debug_battle_move("pokemon-info ignored mismatched response requested=%s responseIdent=%s response=%s" % [
				ident,
				response_ident,
				JSON.stringify(pokemon_info),
			])
			return {}

		return pokemon_info

	return {}

func _fetch_hover_pokemon_stats(
	battle_state: BattleState,
	request_node: HTTPRequest,
	pokemon_data: Dictionary
) -> Dictionary:
	var species: String = battle_state.get_species_from_pokemon_data(pokemon_data)
	var level: int = _get_level_from_pokemon_data(pokemon_data)
	if species == "" or level <= 0:
		_debug_battle_move("pokemon-stats skipped species=%s level=%s pokemon=%s" % [
			species,
			str(level),
			JSON.stringify(pokemon_data),
		])
		return {}

	var cache_key: String = "%s|%s" % [species.to_lower(), level]
	var cached_value: Variant = pokemon_stats_cache.get(cache_key, {})
	if cached_value is Dictionary and not cached_value.is_empty():
		return cached_value as Dictionary

	_debug_battle_move("pokemon-stats request species=%s level=%s" % [species, str(level)])
	var response: Dictionary = await PokemonDataApiClient.get_pokemon_stats(
		request_node,
		species,
		level
	)
	_debug_battle_move("pokemon-stats response=%s" % JSON.stringify(response))
	if not bool(response.get("success", false)):
		return {}

	var pokemon_value: Variant = response.get("pokemon", {})
	if pokemon_value is Dictionary:
		var pokemon_stats: Dictionary = pokemon_value as Dictionary
		if not _pokemon_stats_match_requested_species(pokemon_stats, species):
			_debug_battle_move("pokemon-stats ignored mismatched response requested=%s response=%s" % [
				species,
				JSON.stringify(pokemon_stats),
			])
			return {}

		pokemon_stats_cache[cache_key] = pokemon_stats
		return pokemon_stats

	return {}

func _pokemon_stats_match_requested_species(pokemon_stats: Dictionary, requested_species: String) -> bool:
	var response_species := str(pokemon_stats.get("species", ""))
	if response_species == "":
		return true

	return _normalize_species_for_compare(response_species) == _normalize_species_for_compare(requested_species)

func _get_level_from_pokemon_data(pokemon_data: Dictionary) -> int:
	var level_value: Variant = pokemon_data.get("level", null)
	if level_value != null:
		var parsed_level := int(level_value)
		if parsed_level > 0:
			return parsed_level

	return 100

func _get_hover_known_info_viewer_id(ident: String) -> String:
	match _get_player_id_from_ident(ident):
		"p1":
			return "p2"
		"p2":
			return "p1"

	return ""

func _get_player_id_from_ident(ident: String) -> String:
	if ident.begins_with("p1"):
		return "p1"
	if ident.begins_with("p2"):
		return "p2"

	return ""

func _get_confirmed_ability_for_hover(
	pokemon_info: Dictionary,
	pokemon_data: Dictionary,
	public_confirmed_abilities_by_ident: Dictionary
) -> String:
	var confirmed_ability: String = _get_optional_known_info_string(pokemon_info, "confirmedAbility")
	if confirmed_ability != "":
		return confirmed_ability

	var ident_key: String = _normalize_battle_ident(str(pokemon_data.get("ident", "")))
	if ident_key == "":
		return ""

	return str(public_confirmed_abilities_by_ident.get(ident_key, ""))

func _get_confirmed_item_for_hover(
	pokemon_info: Dictionary,
	pokemon_data: Dictionary,
	public_confirmed_items_by_ident: Dictionary
) -> String:
	var ident_key: String = _normalize_battle_ident(str(pokemon_data.get("ident", "")))
	if ident_key != "" and public_confirmed_items_by_ident.has(ident_key):
		return str(public_confirmed_items_by_ident.get(ident_key, ""))

	return _get_optional_known_info_string(pokemon_info, "confirmedItem")

func _get_confirmed_info_moves(pokemon_info: Dictionary) -> Array:
	var moves_value: Variant = pokemon_info.get("confirmedMoves", pokemon_info.get("confirmed_moves", []))
	if moves_value is Array:
		return moves_value

	return []

func _get_confirmed_info_stat_changes(pokemon_info: Dictionary) -> Dictionary:
	var stat_changes_value: Variant = pokemon_info.get("statChanges", pokemon_info.get("stat_changes", {}))
	if stat_changes_value is Dictionary:
		return stat_changes_value

	return {}

func _get_hover_speed_data(pokemon_stats: Dictionary) -> Dictionary:
	var speed_value: Variant = pokemon_stats.get("speed", {})
	if speed_value is Dictionary:
		return speed_value as Dictionary

	return {}

func _get_hover_species_metadata(pokemon_stats: Dictionary) -> Dictionary:
	var species_metadata := {}
	for key in ["species", "types", "possibleAbilities"]:
		if pokemon_stats.has(key):
			species_metadata[key] = pokemon_stats.get(key)

	return species_metadata

func _get_optional_known_info_string(pokemon_info: Dictionary, key: String) -> String:
	var snake_key: String = _to_snake_case_key(key)
	var value: Variant = pokemon_info.get(key, pokemon_info.get(snake_key, ""))
	if value == null:
		return ""

	return str(value)

func _to_snake_case_key(key: String) -> String:
	var result: String = ""
	for index in range(key.length()):
		var character: String = key.substr(index, 1)
		if index > 0 and character == character.to_upper() and character != character.to_lower():
			result += "_"
		result += character.to_lower()

	return result

func _normalize_battle_ident(ident: String) -> String:
	var cleaned := ident.strip_edges()
	if cleaned.contains(": "):
		var player_id := cleaned.split(": ")[0].substr(0, 2)
		var pokemon_name := cleaned.split(": ")[1]
		return "%s:%s" % [player_id, pokemon_name.to_lower()]

	return cleaned.to_lower()

func _normalize_species_for_compare(species: String) -> String:
	return species.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")

func _debug_battle_move(message: String) -> void:
	if not debug_enabled:
		return

	print("[battle-move] " + message)
