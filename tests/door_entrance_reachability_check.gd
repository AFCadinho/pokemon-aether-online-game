extends SceneTree

const ENTRANCES := [
	["res://scenes/overworld/kanto/towns/pallet_town/pallet_town.tscn", "ToRivalsHouse", "FromRivalsHouse", Vector2(1136, 400)],
	["res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn", "ToBikeStore", "FromBikeStore", Vector2(624, 1648)],
]
const PLAYER_SCRIPT := "res://scripts/world/player.gd"

class ExitProbe:
	extends "res://scripts/world/map_exit.gd"
	var entered := 0

	func _on_body_entered(body: Node2D) -> void:
		if body.name == player_node_name:
			entered += 1

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for entrance: Array in ENTRANCES:
		_check_entrance(entrance[0], entrance[1], entrance[2], entrance[3])
	quit(1 if failed else 0)


func _check_entrance(scene_path: String, exit_name: String, spawn_name: String, door_tile: Vector2) -> void:
	print("Checking ", exit_name)
	var town := (load(scene_path) as PackedScene).instantiate()
	var door := town.get_node("Exits/" + exit_name) as Area2D
	var hint := door.get_node("DoorTransitionHint") as Node2D
	var collision := town.find_child("Collision", true, false) as TileMapLayer
	var arrival := town.get_node("Spawns/" + spawn_name) as Marker2D
	_check(collision.get_cell_source_id(collision.local_to_map(collision.to_local(door_tile))) == -1,
		"the door tile is walkable")
	_check(door.call("contains_world_position", door_tile),
		"the transition contains the reachable door tile")
	_check(hint.global_position == door_tile, "the hint marks the same door tile")
	_check(not door.call("contains_world_position", arrival.global_position),
		"returning from the house does not immediately re-enter")

	# Exercise the player's tile-completion fallback without physics overlap
	# signals, so entering the house does not depend on frame timing.
	door.set_script(ExitProbe)
	var player := load(PLAYER_SCRIPT).new() as Node2D
	player.name = "Player"
	town.get_node("Entities/Players").add_child(player)
	var game_state := root.get_node("GameState")
	var previous_map: Node = game_state.current_map
	game_state.current_map = town
	player.global_position = door_tile
	_check(player.call("check_for_map_exit"), "a completed step onto the door detects an exit")
	_check(door.get("entered") == 1, "the completed step invokes the map transition")
	player.global_position = arrival.global_position
	_check(not player.call("check_for_map_exit"), "the outdoor arrival stays outside the transition")
	game_state.current_map = previous_map
	town.free()


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL %s" % message)
