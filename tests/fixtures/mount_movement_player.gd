extends "res://scripts/world/player.gd"

var completed := 0
var stop_after := -1
var exit_after := -1
var input_allowed := true

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	overworld_steps_completed.connect(func(count: int): completed += count)

func _try_start_move(direction: Vector2) -> bool:
	if stop_after >= 0 and completed >= stop_after:
		return false
	move_start_position = global_position
	target_position = global_position + direction * TILE_SIZE
	move_elapsed = 0.0
	is_moving = true
	return true

func _get_next_movement_direction() -> Vector2:
	return Vector2.RIGHT

func _can_accept_movement_input() -> bool:
	return input_allowed

func check_for_map_exit() -> bool:
	return exit_after >= 0 and completed >= exit_after

func _update_stair_visual_offset(_progress: float) -> void:
	pass
func _clear_stair_visual_offset() -> void:
	pass
func _update_sort_z() -> void:
	pass
func _sync_surf_state_after_move() -> void:
	pass
func is_standing_on_tall_grass() -> bool:
	return false
func _is_cave_encounter_map() -> bool:
	return false
func _spawn_sand_footprint_effect() -> void:
	pass
func set_idle_frame() -> void:
	pass
