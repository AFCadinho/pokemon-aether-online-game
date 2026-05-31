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
##
## Geeft `null` terug als de species-data niet geladen kan worden.
static func create_pokemon(species_id: String, level: int) -> Pokemon:
	var species_data := _load_species_data(species_id)
	if species_data.is_empty():
		return null

	var move_ids := _get_moves_for_level(species_data, level)
	var move_names := _get_move_names(move_ids)

	return Pokemon.new(
		str(species_data["name"]),
		level,
		"",
		str(species_data["abilities"].get("primary", "")),
		"Hardy",
		{},
		move_names
	)


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
	var species_data := _load_species_data(species_id.to_lower())
	return species_data.get("types", [])
	
	
