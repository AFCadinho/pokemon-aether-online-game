extends "res://scripts/world/player.gd"

var completed_steps := 0
var exit_position := Vector2.INF


func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	base_look_position = look_node.position
	base_rider_position = rider_node.position
	var save := get_node("/root/PlayerSave")
	save.ensure_body_matches_gender(false)
	_cache_appearance_sprites()
	_apply_body_appearance(save.appearance_body_id)
	refresh_map_layers()
	target_position = global_position
	move_start_position = global_position
	set_idle_frame()
	overworld_steps_completed.connect(func(count: int): completed_steps += count)


func check_for_map_exit() -> bool:
	return global_position == exit_position


func _is_cave_encounter_map() -> bool:
	return false


func _spawn_sand_footprint_effect() -> void:
	pass
