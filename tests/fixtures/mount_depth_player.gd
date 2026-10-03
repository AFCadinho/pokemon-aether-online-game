extends "res://scripts/world/player.gd"

var depth_map: Node


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	base_look_position = look_node.position
	base_rider_position = rider_node.position
	_cache_appearance_sprites()
	_connect_mount_frame_sync()


func _resolve_current_map() -> Node:
	return depth_map
