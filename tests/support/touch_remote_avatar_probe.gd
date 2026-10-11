extends "res://scripts/world/remote_player_avatar.gd"

# Exercise actual avatar hit testing and context dispatch without its visuals.
func _ready() -> void:
	add_to_group("remote_player_avatar")
	_create_interaction_hit_area()

func _process(_delta: float) -> void:
	pass
