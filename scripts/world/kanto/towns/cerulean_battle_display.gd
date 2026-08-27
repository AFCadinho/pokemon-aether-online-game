extends Node2D

@export_range(4.0, 32.0, 1.0) var lunge_distance := 16.0
@export_range(0.1, 2.0, 0.05) var movement_duration := 0.55
@export_range(0.0, 4.0, 0.1) var pose_pause_seconds := 0.8

@onready var left_pokemon: Node2D = $Pikachu
@onready var right_pokemon: Node2D = $Eevee

var left_origin := Vector2.ZERO
var right_origin := Vector2.ZERO


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	left_origin = left_pokemon.position
	right_origin = right_pokemon.position
	_run_practice_battle.call_deferred()


func _run_practice_battle() -> void:
	await get_tree().process_frame
	while is_inside_tree():
		await _move_pair(
			left_origin + Vector2.RIGHT * lunge_distance,
			right_origin + Vector2.LEFT * lunge_distance,
			Vector2.RIGHT,
			Vector2.LEFT
		)
		if not is_inside_tree():
			return
		await _pause_in_pose(Vector2.RIGHT, Vector2.LEFT)
		await _move_pair(left_origin, right_origin, Vector2.LEFT, Vector2.RIGHT)
		if not is_inside_tree():
			return
		await _pause_in_pose(Vector2.RIGHT, Vector2.LEFT)


func _move_pair(
	left_target: Vector2,
	right_target: Vector2,
	left_direction: Vector2,
	right_direction: Vector2
) -> void:
	_play_walk(left_pokemon, left_direction)
	_play_walk(right_pokemon, right_direction)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(left_pokemon, "position", left_target, movement_duration)
	tween.tween_property(right_pokemon, "position", right_target, movement_duration)
	await tween.finished


func _pause_in_pose(left_direction: Vector2, right_direction: Vector2) -> void:
	_set_idle(left_pokemon, left_direction)
	_set_idle(right_pokemon, right_direction)
	if pose_pause_seconds <= 0.0:
		return
	await get_tree().create_timer(pose_pause_seconds).timeout


func _play_walk(pokemon: Node2D, direction: Vector2) -> void:
	if pokemon.has_method("_play_walk_animation"):
		pokemon.call("_play_walk_animation", direction)


func _set_idle(pokemon: Node2D, direction: Vector2) -> void:
	if pokemon.has_method("_set_idle_frame"):
		pokemon.call("_set_idle_frame", direction)
