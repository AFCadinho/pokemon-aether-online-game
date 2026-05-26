extends Node

class_name PlayerData

signal party_changed

var player_name := "Player"
var party: Array[Pokemon] = []
var money := 0
var flags := {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func add_pokemon(pokemon: Pokemon) -> void:
	if party.size() >= 6:
		return
		
	party.append(pokemon)
	party_changed.emit()
