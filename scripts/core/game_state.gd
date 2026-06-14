extends Node

var player_position: Vector2 = Vector2.ZERO
var has_player_position := false
var player_direction: Vector2 = Vector2.DOWN

var current_map: Node = null

var input_locked := false
var overworld_input_locked := false
var ui_input_locked := false
var world_debug_enabled := false
var repel_enabled := false

func lock_input() -> void:
	input_locked = true
	overworld_input_locked = true
	ui_input_locked = true
	
func unlock_input() -> void:
	input_locked = false
	overworld_input_locked = false
	ui_input_locked = false

func lock_overworld_input() -> void:
	overworld_input_locked = true

func unlock_overworld_input() -> void:
	overworld_input_locked = false

func lock_ui_input() -> void:
	ui_input_locked = true

func unlock_ui_input() -> void:
	ui_input_locked = false

func is_overworld_input_locked() -> bool:
	return input_locked or overworld_input_locked

func is_ui_input_locked() -> bool:
	return ui_input_locked

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

func reset_world_debug_log() -> void:
	if not world_debug_enabled:
		return

	var file := FileAccess.open("user://world_debug.log", FileAccess.WRITE)
	if file == null:
		return

	file.store_line("world debug started")

func debug_world(message: String) -> void:
	if not world_debug_enabled:
		return

	var full_message := "[world-debug] %s" % message
	print(full_message)

	var file := FileAccess.open("user://world_debug.log", FileAccess.READ_WRITE)
	if file == null:
		return

	file.seek_end()
	file.store_line(full_message)
