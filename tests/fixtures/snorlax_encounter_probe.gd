extends "res://scripts/world/interactables/sleeping_pokemon_encounter.gd"

var can_awaken := false
var spoken: Array = []

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	pass

func refresh_status() -> Dictionary:
	status = {"canAwaken": can_awaken}
	return {"success": true}

func show_dialogue(lines: Array[String] = [], _speaker := "", _mugshot: Texture2D = null) -> bool:
	spoken.append(lines)
	return true
