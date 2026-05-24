extends RefCounted

class_name Pokemon

var species: String
var level: int
var item: String
var ability: String
var nature: String
var evs: Dictionary
var moves: Array

var current_hp: int
var max_hp: int

func _init(
	_species: String, 
	_level: int,
	_item := "",
	_ability := "",
	_nature := "Hardy",
	_evs := {},
	_moves := []
	) -> void:
	species = _species
	level = _level
	item = _item
	ability = _ability
	nature = _nature
	evs = {
		"hp": _evs.get("hp", 0),
		"atk": _evs.get("atk", 0),
		"def": _evs.get("def", 0),
		"spa": _evs.get("spa", 0),
		"spd": _evs.get("spd", 0),
		"spe": _evs.get("spe", 0),
	}
	moves = _moves

	max_hp = 20
	current_hp = max_hp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func to_battle_dict() -> Dictionary:
	return {
		"species": species,
		"level": level,
		"item": item,
		"ability": ability,
		"nature": nature,
		"evs": evs,
		"moves": moves,
	}
