extends RefCounted

class_name Pokemon

var species: String
var level: int
var item: String
var ability: String
var nature: String
var instance_id: String
var shiny: bool
var evs: Dictionary
var stats: Dictionary
var moves: Array
var types: Array
var possible_abilities: Array

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
	_stats := {},
	_moves := [],
	_instance_id := "",
	_shiny: bool = false,
	_has_saved_hp_state := false,
	_types := [],
	_possible_abilities := []
	) -> void:
	species = _species
	level = _level
	item = _item
	ability = _ability
	nature = _nature
	instance_id = _instance_id
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
	stats = _normalize_stat_dict(_stats, 0)
	moves = _moves
	types = _normalize_types(_types)
	possible_abilities = _normalize_string_array(_possible_abilities)

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
		"nature": nature,
		"evs": evs,
		"stats": stats,
		"moves": moves,
		"types": types,
		"possibleAbilities": possible_abilities,
		"instanceId": instance_id,
		"shiny": shiny,
	}

	if has_saved_hp_state:
		battle_data["currentHp"] = current_hp
		battle_data["maxHp"] = max_hp
		battle_data["condition"] = _to_battle_condition()

	return battle_data

func _to_battle_condition() -> String:
	if current_hp <= 0:
		return "0 fnt"

	return "%s/%s" % [current_hp, max(max_hp, 1)]

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
