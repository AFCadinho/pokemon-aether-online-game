extends "res://scripts/world/map_exit.gd"


func _enter_authorized_transition(player: Node2D, world: Node, selected_id: String, facing: String) -> void:
	var cabin := get_parent().get_parent()
	await cabin.play_departure()
	if not is_inside_tree() or not is_instance_valid(player):
		return
	cabin.handoff_departure_input()
	await super._enter_authorized_transition(player, world, selected_id, facing)
	if is_instance_valid(cabin) and cabin.is_inside_tree():
		cabin.finish_ride()
