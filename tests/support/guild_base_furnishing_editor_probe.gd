extends "res://scripts/ui/guild_base_furnishing_editor.gd"

var errors := 0
var authenticated := true

func _current() -> bool:
	return authenticated and is_instance_valid(room) and room.is_inside_tree() and get_node("/root/GameState").current_map == room and room.guild_id > 0

func _error(_response: Dictionary) -> void:
	errors += 1
