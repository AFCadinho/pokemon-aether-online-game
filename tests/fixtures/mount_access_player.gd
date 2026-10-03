extends "res://scripts/world/player.gd"

var test_map: Node
var owns_mount := true
var licensed := true


func _resolve_current_map() -> Node:
	return test_map


func _is_mount_owned(_mount_id: String) -> bool:
	return owns_mount


func _has_mount_license_for_current_region() -> bool:
	return licensed


func refresh_pokemon_follower() -> void:
	pass


func reset_pokemon_follower_position() -> void:
	pass


func set_activity_style(_style: String) -> void:
	pass


func clear_activity_style() -> void:
	pass


func _sync_mount_visual() -> void:
	pass
