extends "res://scripts/world/map_metadata.gd"

signal puzzle_changed

const BIN_COLUMNS := 5
const BIN_ROWS := 4

# State belongs to this map instance: battles keep it, leaving the map drops it.
var first_switch := Vector2i(-1, -1)
var second_switch := Vector2i(-1, -1)
var first_switch_active := false
var puzzle_solved := false


func _ready() -> void:
	super._ready()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	first_switch = Vector2i(rng.randi_range(0, BIN_COLUMNS - 1), rng.randi_range(0, BIN_ROWS - 1))
	var neighbors := get_adjacent_bins(first_switch)
	second_switch = neighbors[rng.randi_range(0, neighbors.size() - 1)]
	puzzle_changed.emit()


func get_adjacent_bins(bin: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		var neighbor := bin + direction
		if _is_valid_bin(neighbor):
			neighbors.append(neighbor)
	return neighbors


func activate_bin(bin: Vector2i) -> String:
	if not _is_valid_bin(bin):
		return "empty"
	if puzzle_solved:
		return "solved"
	if not first_switch_active:
		if bin != first_switch:
			return "empty"
		first_switch_active = true
		puzzle_changed.emit()
		return "first"
	# Checking the same switch again is harmless, and is not a second guess.
	if bin == first_switch:
		return "first_active"
	if bin == second_switch:
		puzzle_solved = true
		puzzle_changed.emit()
		return "solved"
	first_switch_active = false
	puzzle_changed.emit()
	return "wrong"


func _is_valid_bin(bin: Vector2i) -> bool:
	return bin.x >= 0 and bin.x < BIN_COLUMNS and bin.y >= 0 and bin.y < BIN_ROWS


func get_safe_restored_player_position(world_position: Vector2) -> Vector2:
	# A new login starts a new puzzle visit. Do not trap a restored player on
	# the leader's side, or on an occupied NPC tile.
	if puzzle_solved:
		return world_position
	if to_local(world_position).y < 17 * 32 or is_position_blocked_by_character(world_position):
		return get_node("Spawns/FromVermilionCity").global_position
	return world_position
