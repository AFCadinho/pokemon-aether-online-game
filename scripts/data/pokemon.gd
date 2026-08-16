extends RefCounted

class_name Pokemon

const DEFAULT_HAPPINESS := 50

var species: String
var level: int
var item: String
var ability: String
var hidden_ability: bool
var nature: String
var location: String
var origin: Dictionary
var ball_item_id: String
var caught_ball_item_id: String
var instance_id: String
var owned_pokemon_id: int
var shiny: bool
var evs: Dictionary
var stored_evs: Dictionary
var ivs: Dictionary
var stats: Dictionary
var moves: Array
var types: Array
var possible_abilities: Array
var can_evolve: bool
var tradable: bool
var experience: int
var current_level_exp: int
var next_level_exp: int
var experience_to_next_level: int
var growth_rate: String
var base_experience: int
var status: String
var happiness: int

var current_hp: int
var max_hp: int
var has_saved_hp_state := false

func _init(
	_species: String,
	_level: int,
	_item := "",
	_ability := "",
	_nature := "Hardy",
	_evs := {},
	_ivs := {},
	_stats := {},
	_moves := [],
	_instance_id := "",
	_owned_pokemon_id: int = 0,
	_shiny: bool = false,
	_has_saved_hp_state := false,
	_types := [],
	_possible_abilities := [],
	_location: String = "",
	_origin := {},
	_tradable: bool = true,
	_stored_evs := {},
	_ball_item_id: String = "poke-ball",
	_caught_ball_item_id: String = "",
	_experience: int = 0,
	_current_level_exp: int = 0,
	_next_level_exp: int = 0,
	_experience_to_next_level: int = 0,
	_growth_rate: String = "",
	_base_experience: int = 0,
	_status: String = "",
	_happiness: int = DEFAULT_HAPPINESS
	) -> void:
	species = _species
	level = _level
	item = _item
	ability = _ability
	hidden_ability = false
	nature = _nature
	location = _location
	origin = _normalize_origin(_origin, location)
	ball_item_id = _normalize_ball_item_id(_ball_item_id, "poke-ball")
	caught_ball_item_id = _normalize_ball_item_id(_caught_ball_item_id, "")
	instance_id = _instance_id
	owned_pokemon_id = _owned_pokemon_id
	shiny = _shiny
	has_saved_hp_state = _has_saved_hp_state
	evs = {
		"hp": _evs.get("hp", 0),
		"atk": _evs.get("atk", 0),
		"def": _evs.get("def", 0),
		"spa": _evs.get("spa", 0),
		"spd": _evs.get("spd", 0),
		"spe": _evs.get("spe", 0),
	}
	stored_evs = {
		"hp": _stored_evs.get("hp", 0),
		"atk": _stored_evs.get("atk", 0),
		"def": _stored_evs.get("def", 0),
		"spa": _stored_evs.get("spa", 0),
		"spd": _stored_evs.get("spd", 0),
		"spe": _stored_evs.get("spe", 0),
	}
	ivs = {
		"hp": _ivs.get("hp", 31),
		"atk": _ivs.get("atk", 31),
		"def": _ivs.get("def", 31),
		"spa": _ivs.get("spa", 31),
		"spd": _ivs.get("spd", 31),
		"spe": _ivs.get("spe", 31),
	}
	stats = _normalize_stat_dict(_stats, 0)
	moves = _moves
	types = _normalize_types(_types)
	possible_abilities = _normalize_string_array(_possible_abilities)
	can_evolve = false
	tradable = _tradable
	experience = max(_experience, 0)
	current_level_exp = max(_current_level_exp, 0)
	next_level_exp = max(_next_level_exp, current_level_exp)
	experience_to_next_level = max(_experience_to_next_level, 0)
	growth_rate = _growth_rate.strip_edges()
	base_experience = max(_base_experience, 0)
	status = _normalize_status(_status)
	happiness = clampi(_happiness, 0, 255)

	max_hp = 20
	current_hp = max_hp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func to_battle_dict() -> Dictionary:
	ensure_instance_id()

	var battle_data := {
		"species": species,
		"level": level,
		"item": item,
		"ability": ability,
		"hiddenAbility": hidden_ability,
		"nature": nature,
		"happiness": happiness,
		"evs": evs,
		"storedEvs": stored_evs,
		"ivs": ivs,
		"stats": stats,
		"moves": _moves_to_battle_list(),
		"savedMoves": _moves_to_persistence_list(),
		"types": types,
		"possibleAbilities": possible_abilities,
		"canEvolve": can_evolve,
		"instanceId": instance_id,
		"ballItemId": ball_item_id,
		"shiny": shiny,
		"experience": experience,
		"currentLevelExp": current_level_exp,
		"nextLevelExp": next_level_exp,
		"experienceToNextLevel": experience_to_next_level,
	}
	if growth_rate != "":
		battle_data["growthRate"] = growth_rate
	if base_experience > 0:
		battle_data["baseExperience"] = base_experience
	if owned_pokemon_id > 0:
		battle_data["ownedPokemonId"] = owned_pokemon_id
	if caught_ball_item_id != "":
		battle_data["caughtBallItemId"] = caught_ball_item_id

	if has_saved_hp_state or status != "":
		battle_data["currentHp"] = current_hp
		battle_data["maxHp"] = max_hp
		battle_data["condition"] = _to_battle_condition()

	return battle_data


func to_battle_state_dict(metadata_slot: int = -1) -> Dictionary:
	ensure_instance_id()

	var battle_state := {
		"species": species,
		"ownedPokemonId": owned_pokemon_id,
		"instanceId": instance_id,
		"currentHp": current_hp,
		"maxHp": max_hp,
		"moves": _moves_to_persistence_list(),
		"condition": _to_battle_condition(),
	}
	if metadata_slot > 0:
		battle_state["metadataSlot"] = metadata_slot

	return battle_state

func to_persistence_dict() -> Dictionary:
	var pokemon_data := to_battle_dict()
	pokemon_data.erase("savedMoves")
	pokemon_data["moves"] = _moves_to_persistence_list()
	if owned_pokemon_id > 0:
		pokemon_data["ownedPokemonId"] = owned_pokemon_id
	if location.strip_edges() != "":
		pokemon_data["location"] = location
	if not origin.is_empty():
		pokemon_data["origin"] = origin.duplicate(true)
	pokemon_data["ballItemId"] = ball_item_id
	if caught_ball_item_id != "":
		pokemon_data["caughtBallItemId"] = caught_ball_item_id
	pokemon_data["tradable"] = tradable
	pokemon_data["currentHp"] = current_hp
	pokemon_data["maxHp"] = max_hp
	pokemon_data["condition"] = _to_battle_condition()
	return pokemon_data

func _moves_to_battle_list() -> Array:
	var battle_moves: Array = []
	for move_value: Variant in moves:
		if move_value is Dictionary:
			var move_data: Dictionary = move_value as Dictionary
			var move_name: String = str(move_data.get("name", "")).strip_edges()
			if move_name == "":
				move_name = str(move_data.get("id", move_data.get("move", ""))).strip_edges()
			if move_name != "":
				battle_moves.append(move_name)
		else:
			var move_text: String = str(move_value).strip_edges()
			if move_text != "":
				battle_moves.append(move_text)

	return battle_moves.slice(0, 4)

func _moves_to_persistence_list() -> Array:
	var persisted_moves: Array = []
	for move_value: Variant in moves:
		if move_value is Dictionary:
			persisted_moves.append((move_value as Dictionary).duplicate(true))
		else:
			var move_text: String = str(move_value).strip_edges()
			if move_text != "":
				persisted_moves.append(move_text)

	return persisted_moves.slice(0, 4)

func _to_battle_condition() -> String:
	if current_hp <= 0:
		return "0 fnt"

	var condition := "%s/%s" % [current_hp, max(max_hp, 1)]
	if status != "":
		condition += " " + status
	return condition

func ensure_instance_id() -> void:
	if instance_id != "":
		return

	instance_id = "pokemon_%s_%s" % [Time.get_ticks_usec(), randi()]

func _normalize_types(value: Variant) -> Array:
	return _normalize_string_array(value)

func _normalize_stat_dict(value: Variant, default_value: int) -> Dictionary:
	var source: Dictionary = {}
	if value is Dictionary:
		source = value as Dictionary

	return {
		"hp": int(source.get("hp", default_value)),
		"atk": int(source.get("atk", default_value)),
		"def": int(source.get("def", default_value)),
		"spa": int(source.get("spa", default_value)),
		"spd": int(source.get("spd", default_value)),
		"spe": int(source.get("spe", default_value)),
	}

func _normalize_string_array(value: Variant) -> Array:
	var normalized_values: Array = []
	if not (value is Array):
		return normalized_values

	for item in value:
		normalized_values.append(str(item))

	return normalized_values

func _normalize_origin(value: Variant, fallback_location: String = "") -> Dictionary:
	var normalized_origin: Dictionary = {}
	if value is Dictionary:
		normalized_origin = (value as Dictionary).duplicate(true)

	if normalized_origin.is_empty() and fallback_location.strip_edges() != "":
		normalized_origin["locationName"] = fallback_location.strip_edges()

	return normalized_origin

func _normalize_ball_item_id(value: String, fallback_value: String = "") -> String:
	var normalized_value := value.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	return normalized_value if normalized_value != "" else fallback_value

func _normalize_status(value: String) -> String:
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
