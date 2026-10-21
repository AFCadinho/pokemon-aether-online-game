extends "res://scripts/world/map_metadata.gd"

func prepare_player_arrival(spawn_name: String) -> void:
	if spawn_name != "FromGym":
		return
	var door := get_node_or_null("PewterCity/GymDoubleSlidingDoor")
	if door != null:
		door.call("prepare_for_arrival")
