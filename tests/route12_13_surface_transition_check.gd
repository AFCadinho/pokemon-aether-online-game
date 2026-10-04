extends SceneTree

class SurfaceTestPlayer:
	extends Node2D
	var surfing := false

	func is_surfing_activity_active() -> bool:
		return surfing


var failed := false


func _init() -> void:
	call_deferred("run")


func run() -> void:
	var route12 := (load("res://scenes/overworld/kanto/routes/kanto_route_12.tscn") as PackedScene).instantiate()
	var route13 := (load("res://scenes/overworld/kanto/routes/kanto_route_13.tscn") as PackedScene).instantiate()
	_check_route_pair(
		route12,
		"ToRoute13",
		"ToRoute13Water",
		"kanto_route_12__to_route13",
		"kanto_route_12__to_route13_water"
	)
	_check_route_pair(
		route13,
		"ToRoute12",
		"ToRoute12Water",
		"kanto_route_13__to_route12",
		"kanto_route_13__to_route12_water"
	)
	_check_spawn_surface(route12, "FromRoute13", false)
	_check_spawn_surface(route12, "FromRoute13Water", true)
	_check_spawn_surface(route13, "FromRoute12", false)
	_check_spawn_surface(route13, "FromRoute12Water", true)
	route12.free()
	route13.free()
	if not failed:
		print("PASS Route 12–13 land and water transitions preserve arrival surface")
	quit(1 if failed else 0)


func _check_route_pair(
	map: Node,
	land_exit_name: String,
	water_exit_name: String,
	land_transition_id: String,
	water_transition_id: String
) -> void:
	var land_exit: Node = map.get_node("Exits/" + land_exit_name)
	var water_exit: Node = map.get_node("Exits/" + water_exit_name)
	var player := SurfaceTestPlayer.new()
	_check(
		land_exit.call("_resolve_transition_id_for_player", player) == land_transition_id,
		"Land exit chooses its land transition for walking"
	)
	_check(
		water_exit.call("_resolve_transition_id_for_player", player) == land_transition_id,
		"Water exit chooses its land transition for walking"
	)
	player.surfing = true
	_check(
		land_exit.call("_resolve_transition_id_for_player", player) == water_transition_id,
		"Land exit chooses its water transition while Surf is active"
	)
	_check(
		water_exit.call("_resolve_transition_id_for_player", player) == water_transition_id,
		"Water exit chooses its water transition while Surf is active"
	)
	player.free()


func _check_spawn_surface(map: Node, spawn_name: String, expected_water: bool) -> void:
	var water := map.get_node("Tiles/Water") as TileMapLayer
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var spawn := map.get_node("Spawns/" + spawn_name) as Marker2D
	var cell := water.local_to_map(water.to_local(spawn.global_position))
	var is_water := water.get_cell_source_id(cell) != -1
	var is_walkable := collision.get_cell_source_id(cell) == -1
	_check(is_water == expected_water, "%s arrival preserves its land/water surface" % spawn_name)
	_check(is_walkable, "%s arrival avoids collision" % spawn_name)


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error("FAIL: " + label)
