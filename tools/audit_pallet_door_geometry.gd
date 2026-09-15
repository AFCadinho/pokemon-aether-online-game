extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Instantiate off-tree: no access requests, movement, persistence or _ready.
	var scene: PackedScene = load("res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn")
	var map := scene.instantiate()
	var collision := map.get_node("Collision") as TileMapLayer
	var cells := []
	for y in range(14, 19):
		var cell := Vector2i(20, y)
		cells.append({"cell": [cell.x, cell.y], "blocked": collision.get_cell_source_id(cell) != -1})
	var exit := map.get_node("Exits/ToPlayersHouse") as Area2D
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player := player_scene.instantiate()
	var detection := player.get_node("DetectionShape") as CollisionShape2D
	var exit_shape := exit.get_node("CollisionShape2D") as CollisionShape2D
	var door := Vector2(656, 528)
	var player_size: Vector2 = detection.shape.size
	var exit_size: Vector2 = exit_shape.shape.size
	var player_rect := Rect2(door + detection.position - player_size / 2, player_size)
	var exit_rect := Rect2(exit.position + exit_shape.position - exit_size / 2, exit_size)
	var reachable := collision.get_cell_source_id(collision.local_to_map(door)) == -1 and player_rect.intersects(exit_rect)
	var old_rect := Rect2(Vector2(656, 496) - exit_size / 2, exit_size)
	var regression_proven := not player_rect.intersects(old_rect)
	var connected := exit.is_connected("body_entered", Callable(exit, "_on_body_entered"))
	var lab := map.get_node("Exits/ToOaksLab") as Area2D
	var lab_shape := lab.get_node("CollisionShape2D") as CollisionShape2D
	var lab_front := Vector2(1296, 816)
	var lab_rect := Rect2(lab.position + lab_shape.position - lab_shape.shape.size / 2, lab_shape.shape.size)
	var lab_player := Rect2(lab_front + detection.position - player_size / 2, player_size)
	var lab_reachable := collision.get_cell_source_id(collision.local_to_map(lab_front)) == -1 and lab_player.intersects(lab_rect)
	print("PALLET_DOOR_GEOMETRY ", JSON.stringify({"cells": cells,
		"exitPosition": [exit.position.x, exit.position.y],
		"signalConnected": connected, "reachable": reachable, "labReachable": lab_reachable, "oldPositionNoOverlap": regression_proven}))
	player.free()
	map.free()
	quit(0 if reachable and lab_reachable and regression_proven and connected else 1)
