extends SceneTree

const ROUTE_24_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const ROUTE_25_SCENE := "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var route_24 := await _instantiate_map(ROUTE_24_SCENE)
	var route_25 := await _instantiate_map(ROUTE_25_SCENE)

	_check_connection(
		route_24,
		"Upper",
		ROUTE_25_SCENE,
		"FromRoute24Upper",
		"kanto_route_24__to_route_25_upper"
	)
	_check_connection(
		route_24,
		"Lower",
		ROUTE_25_SCENE,
		"FromRoute24Lower",
		"kanto_route_24__to_route_25_lower"
	)
	_check_connection(
		route_24,
		"South",
		ROUTE_25_SCENE,
		"FromRoute24South",
		"kanto_route_24__to_route_25_south"
	)
	_check_connection(
		route_25,
		"Upper",
		ROUTE_24_SCENE,
		"FromRoute25Upper",
		"kanto_route_25__to_route_24_upper"
	)
	_check_connection(
		route_25,
		"Lower",
		ROUTE_24_SCENE,
		"FromRoute25Lower",
		"kanto_route_25__to_route_24_lower"
	)
	_check_connection(
		route_25,
		"South",
		ROUTE_24_SCENE,
		"FromRoute25South",
		"kanto_route_25__to_route_24_south"
	)

	var route_24_collision := route_24.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(_is_open(route_24_collision, Vector2i(44, 4)), "Route 24 opens its upper Route 25 passage")
	_check(_is_open(route_24_collision, Vector2i(44, 10)), "Route 24 opens its lower Route 25 passage")
	_check(_is_open(route_24_collision, Vector2i(44, 18)), "Route 24 opens its south Route 25 passage")
	_check(not _is_open(route_24_collision, Vector2i(44, 7)), "Route 24 separates both Route 25 passages")
	_check(not _is_open(route_24_collision, Vector2i(44, 14)), "Route 24 separates its lower and south passages")
	_check(not _is_open(route_24_collision, Vector2i(44, 22)), "Route 24 closes the east boundary below all passages")

	var route_25_collision := route_25.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(_is_open(route_25_collision, Vector2i(0, 4)), "Route 25 opens its upper Route 24 passage")
	_check(_is_open(route_25_collision, Vector2i(0, 10)), "Route 25 opens its lower Route 24 passage")
	_check(_is_open(route_25_collision, Vector2i(0, 15)), "Route 25 opens its south Route 24 passage")
	_check(not _is_open(route_25_collision, Vector2i(0, 7)), "Route 25 separates both Route 24 passages")
	_check(not _is_open(route_25_collision, Vector2i(0, 14)), "Route 25 separates its lower and south passages")
	_check(not _is_open(route_25_collision, Vector2i(0, 17)), "Route 25 closes the west boundary below all passages")

	route_24.queue_free()
	route_25.queue_free()
	await process_frame
	quit(1 if failed else 0)


func _check_connection(
	map: Node,
	suffix: String,
	target_scene: String,
	target_spawn: String,
	transition_id: String
) -> void:
	var exit := map.get_node_or_null("Exits/ToRoute%s%s" % ["25" if map.name == "KantoRoute24" else "24", suffix])
	var spawn := map.get_node_or_null("Spawns/FromRoute%s%s" % ["25" if map.name == "KantoRoute24" else "24", suffix])
	_check(exit != null, "%s exposes its %s exit" % [map.name, suffix.to_lower()])
	_check(spawn != null, "%s exposes its %s spawn" % [map.name, suffix.to_lower()])
	if exit == null:
		return
	_check(exit.target_scene_path == target_scene, "%s %s exit targets the reciprocal scene" % [map.name, suffix.to_lower()])
	_check(exit.target_spawn_name == target_spawn, "%s %s exit targets the matching spawn" % [map.name, suffix.to_lower()])
	_check(exit.transition_id == transition_id, "%s %s exit has a stable transition ID" % [map.name, suffix.to_lower()])


func _instantiate_map(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	_check(packed != null, "%s loads" % scene_path.get_file())
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame
	return map


func _is_open(layer: TileMapLayer, cell: Vector2i) -> bool:
	return layer != null and layer.get_cell_source_id(cell) == -1


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
