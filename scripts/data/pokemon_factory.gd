extends RefCounted

class_name PokemonFactory

## Factory voor het maken van Pokemon-instances vanuit lokale JSON-data.
##
## Deze class leest species- en move-data uit `res://data/pokemon/`.
## Gameplay-code hoeft daardoor niet zelf te weten hoe de JSON-bestanden
## zijn opgebouwd.
##
## Voorbeeld:
## ```
## var charmander := PokemonFactory.create_pokemon("charmander", 5)
## var gyarados := PokemonFactory.create_pokemon("gyarados", 50, {
##     "ability": "Intimidate",
##     "nature": "Adamant",
##     "item": "Leftovers",
##     "evs": {"atk": 252, "spe": 252, "hp": 4},
##     "moves": ["Waterfall", "Crunch", "Dragon Dance", "Earthquake"]
## })
## ```
const SPECIES_PATH := "res://data/pokemon/species/%s.json"
const MOVE_PATH := "res://data/pokemon/moves/%s.json"
const MOVE_TYPE_DIR := "res://data/pokemon/moves"

static var _moves_by_id: Dictionary = {}
static var _moves_loaded := false


## Maakt een nieuwe Pokemon op basis van species id en level.
##
## `species_id` gebruikt de bestandsnaam zonder `.json`, bijvoorbeeld
## `"charmander"`, `"bulbasaur"` of `"mr-mime"`.
##
## De factory:
## - laadt species-data uit JSON
## - kiest moves die de Pokemon op dit level al geleerd heeft
## - houdt maximaal de laatste 4 geleerde moves over
## - vertaalt move ids naar nette display names
## - past optionele overrides toe, zoals ability, item, nature, evs, moves en HP
##
## Geeft `null` terug als de species-data niet geladen kan worden.
static func create_pokemon(species_id: String, level: int, options: Dictionary = {}) -> Pokemon:
	var species_data := _load_species_data(_normalize_species_id(species_id))
	if species_data.is_empty():
		print_debug("PokemonFactory.create_pokemon failed: species_id=", species_id, " level=", level, " options=", options)
		return null

	var move_ids := _get_moves_for_level(species_data, level)
	var move_names := _get_move_names(move_ids)
	var pokemon := Pokemon.new(
		str(options.get("species", species_data["name"])),
		int(options.get("level", level)),
		str(options.get("item", "")),
		str(options.get("ability", species_data["abilities"].get("primary", ""))),
		str(options.get("nature", "Hardy")),
		options.get("evs", {}),
		_get_option_moves(options, move_names),
		str(options.get("instanceId", options.get("instance_id", ""))),
		_has_hp_override(options)
	)

	var ivs_value: Variant = options.get("ivs", {})
	var ivs: Dictionary = ivs_value if ivs_value is Dictionary else {}
	var calculated_max_hp := _calculate_max_hp(species_data, pokemon.level, pokemon.evs, ivs)
	pokemon.max_hp = calculated_max_hp
	pokemon.current_hp = calculated_max_hp

	if _has_hp_override(options):
		_apply_hp_options(pokemon, options)

	return pokemon


## Maakt een Pokemon vanuit een Dictionary, handig voor encounters of database records.
##
## Verwachte velden zijn bijvoorbeeld:
## species, level, ability, item, nature, evs, moves, currentHp/current_hp, maxHp/max_hp.
static func create_pokemon_from_data(data: Dictionary) -> Pokemon:
	var species_id := str(data.get("species", data.get("species_id", "")))
	if species_id == "":
		print_debug("PokemonFactory.create_pokemon_from_data failed: missing species. data=", data)
		push_error("Pokemon data mist species")
		return null

	var level := int(data.get("level", data.get("min_level", 1)))
	var pokemon := create_pokemon(species_id, level, data)
	if pokemon == null:
		print_debug("PokemonFactory.create_pokemon_from_data failed: species_id=", species_id, " level=", level, " data=", data)

	return pokemon


static func get_expected_max_hp(species_id: String, level: int, evs: Dictionary = {}, ivs: Dictionary = {}) -> int:
	var species_data := _load_species_data(_normalize_species_id(species_id))
	if species_data.is_empty():
		return 0

	return _calculate_max_hp(species_data, level, evs, ivs)


static func _get_option_moves(options: Dictionary, default_moves: Array[String]) -> Array:
	if not options.has("moves"):
		return default_moves

	var moves: Array = []
	for move in options.get("moves", []):
		moves.append(str(move))

	if moves.size() <= 4:
		return moves

	return moves.slice(0, 4)


static func _has_hp_override(options: Dictionary) -> bool:
	return (
		options.has("currentHp")
		or options.has("current_hp")
		or options.has("maxHp")
		or options.has("max_hp")
		or options.has("condition")
	)


static func _apply_hp_options(pokemon: Pokemon, options: Dictionary) -> void:
	var condition_hp := _parse_condition(str(options.get("condition", "")))
	var has_condition_hp := not condition_hp.is_empty()
	var has_max_hp := options.has("maxHp") or options.has("max_hp")
	var has_current_hp := options.has("currentHp") or options.has("current_hp")

	var max_hp := pokemon.max_hp
	if has_condition_hp:
		max_hp = int(condition_hp.get("max_hp", max_hp))
	if has_max_hp:
		max_hp = int(options.get("maxHp", options.get("max_hp", max_hp)))

	pokemon.max_hp = max(max_hp, 1)

	var current_hp := pokemon.max_hp
	if has_condition_hp:
		current_hp = int(condition_hp.get("current_hp", current_hp))
	if has_current_hp:
		current_hp = int(options.get("currentHp", options.get("current_hp", current_hp)))

	pokemon.current_hp = clamp(current_hp, 0, pokemon.max_hp)


static func _calculate_max_hp(species_data: Dictionary, level: int, evs: Dictionary, ivs: Dictionary) -> int:
	var base_stats_value: Variant = species_data.get("base_stats", {})
	var base_stats: Dictionary = base_stats_value if base_stats_value is Dictionary else {}
	var base_hp := int(base_stats.get("hp", 1))
	var hp_ev := int(evs.get("hp", 0))
	var hp_iv := int(ivs.get("hp", 31))

	if base_hp <= 1:
		return 1

	return int(floor(((2 * base_hp + hp_iv + floor(hp_ev / 4.0)) * level) / 100.0)) + level + 10


static func _parse_condition(condition: String) -> Dictionary:
	if condition == "":
		return {}

	if condition.contains("fnt"):
		return {
			"current_hp": 0,
			"max_hp": 1,
		}

	if not condition.contains("/"):
		return {}

	var parts := condition.split("/")
	return {
		"current_hp": int(parts[0]),
		"max_hp": max(int(str(parts[1]).split(" ")[0]), 1),
	}


## Laadt de JSON-data voor een Pokemon species.
##
## Verwacht een bestand zoals:
## `res://data/pokemon/species/charmander.json`
##
## Geeft een lege Dictionary terug wanneer het bestand mist, niet geopend kan
## worden, of geen geldige JSON dictionary bevat.
static func _load_species_data(species_id: String) -> Dictionary:
	var path := SPECIES_PATH % species_id.to_lower()

	if not FileAccess.file_exists(path):
		push_error("Pokemon species-data ontbreekt: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Pokemon species-data kon niet geopend worden: " + path)
		return {}

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Ongeldige Pokemon species JSON: " + path)
		return {}

	return parsed


## Bepaalt welke moves een Pokemon op dit level kent.
##
## Deze functie leest `level_up_moves` uit de species JSON. Alle moves met
## `level <= huidig level` worden gezien als geleerd.
##
## Als er meer dan 4 moves beschikbaar zijn, worden alleen de laatste 4
## overgehouden. Dat bootst het standaard Pokemon-principe na waarbij een
## Pokemon maximaal 4 moves tegelijk kan hebben.
static func _get_moves_for_level(species_data: Dictionary, level: int) -> Array[String]:
	var learned_moves: Array[String] = []

	for entry in species_data.get("level_up_moves", []):
		if int(entry.get("level", 0)) <= level:
			learned_moves.append(str(entry.get("move", "")))

	while learned_moves.size() > 4:
		learned_moves.pop_front()

	return learned_moves


## Zet move ids om naar display names.
##
## Voorbeeld:
## `"scratch"` wordt `"Scratch"` op basis van `moves/<type>.json`.
##
## Als move-data ontbreekt, valt de functie terug op een simpele gecapitalized
## versie van de move id.
static func _get_move_names(move_ids: Array[String]) -> Array[String]:
	var move_names: Array[String] = []

	for move_id in move_ids:
		var move_data := _load_move_data(move_id)

		if move_data.is_empty():
			move_names.append(move_id.capitalize())
		else:
			move_names.append(str(move_data.get("name", move_id.capitalize())))

	return move_names


## Laadt de JSON-data voor een move.
##
## Verwacht een bestand zoals:
## `res://data/pokemon/moves/fire.json`
##
## Geeft een lege Dictionary terug wanneer het bestand mist, niet geopend kan
## worden, of geen geldige JSON dictionary bevat.
static func _load_move_data(move_id: String) -> Dictionary:
	_ensure_moves_loaded()

	var key := move_id.to_lower()
	var move_data: Dictionary = _moves_by_id.get(key, {})
	if move_data.is_empty():
		push_error("Pokemon move-data ontbreekt: " + move_id)

	return move_data


## Laadt alle move-data uit type-gegroepeerde bestanden.
##
## Verwacht bestanden zoals:
## `res://data/pokemon/moves/fire.json`, `res://data/pokemon/moves/normal.json`, ...
##
## Elk bestand is een dictionary met move id als key en move details als value.
static func _ensure_moves_loaded() -> void:
	if _moves_loaded:
		return

	_moves_loaded = true
	var dir := DirAccess.open(MOVE_TYPE_DIR)
	if dir == null:
		push_error("Kan move folder niet openen: " + MOVE_TYPE_DIR)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".json"):
			var path := MOVE_PATH % file_name.get_basename()
			var file := FileAccess.open(path, FileAccess.READ)
			if file == null:
				push_error("Pokemon move-data kon niet geopend worden: " + path)
				file_name = dir.get_next()
				continue

			var parsed = JSON.parse_string(file.get_as_text())
			if typeof(parsed) != TYPE_DICTIONARY:
				push_error("Ongeldige Pokemon move bucket JSON: " + path)
				file_name = dir.get_next()
				continue

			if not _is_move_bucket_dict(parsed):
				# Alleen map-bestanden met move-id keys worden ingeladen.
				file_name = dir.get_next()
				continue

			for move_key in parsed.keys():
				if typeof(parsed[move_key]) != TYPE_DICTIONARY:
					continue
				_moves_by_id[str(move_key).to_lower()] = parsed[move_key]

		file_name = dir.get_next()

	dir.list_dir_end()


## Controleert of een JSON-object een move-type bucket is (move-id keys -> move dicts)
static func _is_move_bucket_dict(value: Dictionary) -> bool:
	if value.is_empty():
		return false

	for key in value.keys():
		if typeof(value[key]) != TYPE_DICTIONARY:
			return false
		if typeof(key) != TYPE_STRING:
			return false

	return true


static func get_species_types(species_id: String) -> Array:
	var species_data := _load_species_data(_normalize_species_id(species_id))
	return species_data.get("types", [])

static func _normalize_species_id(species_id: String) -> String:
	return species_id.to_lower().replace(" ", "-").replace("-mega-x", "-megax").replace("-mega-y", "-megay")
