extends Node

class_name Pokemon

var species: String
var level: int
var current_hp: int
var max_hp: int

func _init(_species: String, _level: int) -> void:
	species = _species
	level = _level
	
	max_hp = 20
	current_hp = max_hp

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
