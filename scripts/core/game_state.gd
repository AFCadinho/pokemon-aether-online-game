extends Node

var player_position: Vector2 = Vector2.ZERO
var has_player_position := false
var player_direction: Vector2 = Vector2.DOWN

var current_map: Node = null

var input_locked := false

func lock_input() -> void:
	input_locked = true
	
func unlock_input() -> void:
	input_locked = false
