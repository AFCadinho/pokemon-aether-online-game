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

func get_world() -> Node:
	var tree := get_tree()
	if tree == null:
		return null

	var grouped_world := tree.get_first_node_in_group("world")
	if grouped_world != null:
		return grouped_world

	var current_scene := tree.current_scene
	if current_scene != null and current_scene.has_method("load_map"):
		return current_scene

	return null
