extends Node2D

@export_file("*.json") var encounter_data_path = "res://data/encounters/kanto/route_1.json"

var encounter_data: Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	encounter_data = load_encounter_data()

func load_encounter_data() -> Dictionary:
	if not FileAccess.file_exists(encounter_data_path):
		push_error("Encounter data not found: " + encounter_data_path)
		return {}

	var file := FileAccess.open(encounter_data_path, FileAccess.READ)
	var text := file.get_as_text()
	var parsed = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid encounter JSON: " + encounter_data_path)
		return {}

	return parsed


func try_get_wild_encounter() -> Pokemon:
	var grass_data: Dictionary = encounter_data.get("grass", {})

	if grass_data.is_empty():
		return null

	var encounter_chance: float = grass_data.get("encounter_chance", 0.0)

	if randf() > encounter_chance:
		return null

	var pokemon_list: Array = grass_data.get("pokemon", [])

	if pokemon_list.is_empty():
		return null

	var encounter := pick_weighted_encounter(pokemon_list)
	var level := randi_range(encounter.get("min_level", 2), encounter.get("max_level", 2))

	return Pokemon.new(
		encounter.get("species", "Unknown"),
		level,
		encounter.get("item", ""),
		encounter.get("ability", ""),
		encounter.get("nature", "Hardy"),
		encounter.get("evs", {}),
		encounter.get("moves", [])
	)
	
func pick_weighted_encounter(pokemon_list: Array) -> Dictionary:
	var total_weight := 0

	for pokemon_entry in pokemon_list:
		total_weight += pokemon_entry.get("weight", 1)

	var roll := randi_range(1, total_weight)
	var running_total := 0

	for pokemon_entry in pokemon_list:
		running_total += pokemon_entry.get("weight", 1)

		if roll <= running_total:
			return pokemon_entry

	return pokemon_list[0]
