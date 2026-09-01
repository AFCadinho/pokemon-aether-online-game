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
	_check(_is_open(route_24_collision, Vector2i(59, 4)), "Route 24 opens its upper Route 25 passage")
	_check(_is_open(route_24_collision, Vector2i(59, 11)), "Route 24 opens its lower Route 25 passage")
	_check(_is_open(route_24_collision, Vector2i(59, 18)), "Route 24 opens its south Route 25 passage")
	_check(not _is_open(route_24_collision, Vector2i(59, 7)), "Route 24 separates both Route 25 passages")
	_check(not _is_open(route_24_collision, Vector2i(59, 15)), "Route 24 separates its lower and south passages")
	_check(not _is_open(route_24_collision, Vector2i(59, 20)), "Route 24 closes the east boundary below all passages")
	_check(
		_boundary_matches(
			route_24_collision,
			Vector2i(60, 60),
			{
				"bottom": [
					Vector2i(21, 27),
					Vector2i(29, 33),
					Vector2i(35, 39),
					Vector2i(41, 45),
				],
				"right": [Vector2i(3, 6), Vector2i(9, 14), Vector2i(17, 19)],
			}
		),
		"Route 24 stores its complete authored boundary"
	)
	var route_24_water := route_24.find_map_tilemap_layer("Water") as TileMapLayer
	_check(
		_water_ranges_match(route_24_water, [Vector2i(21, 27), Vector2i(35, 39)], 55, 59),
		"Route 24 stores both complete Surf approaches"
	)

	var route_25_collision := route_25.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(_is_vertical_range_open(route_25_collision, 0, 14, 17), "Route 25 opens its upper Route 24 passage")
	_check(_is_vertical_range_open(route_25_collision, 0, 20, 25), "Route 25 opens its lower Route 24 passage")
	_check(_is_vertical_range_open(route_25_collision, 0, 28, 30), "Route 25 opens its south Route 24 passage")
	_check(not _is_open(route_25_collision, Vector2i(0, 19)), "Route 25 separates its upper and lower passages")
	_check(not _is_open(route_25_collision, Vector2i(0, 27)), "Route 25 separates its lower and south passages")
	_check(not _is_open(route_25_collision, Vector2i(0, 31)), "Route 25 closes the west boundary below all passages")
	_check(
		_boundary_matches(
			route_25_collision,
			Vector2i(80, 50),
			{"left": [Vector2i(14, 17), Vector2i(20, 25), Vector2i(28, 30)]}
		),
		"Route 25 stores its complete authored boundary"
	)

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
	var collision := map.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := map.find_map_tilemap_layer("Water") as TileMapLayer
	var collision_before := _cell_state(collision)
	var water_before := _cell_state(water)
	root.add_child(map)
	await process_frame
	_check(
		collision_before == _cell_state(collision),
		"%s keeps its authored Collision unchanged during startup" % scene_path.get_file()
	)
	_check(
		water_before == _cell_state(water),
		"%s keeps its authored Water unchanged during startup" % scene_path.get_file()
	)
	return map


func _cell_state(layer: TileMapLayer) -> Dictionary:
	var result := {}
	for cell: Vector2i in layer.get_used_cells():
		result[cell] = [
			layer.get_cell_source_id(cell),
			layer.get_cell_atlas_coords(cell),
			layer.get_cell_alternative_tile(cell),
		]
	return result


func _is_open(layer: TileMapLayer, cell: Vector2i) -> bool:
	return layer != null and layer.get_cell_source_id(cell) == -1


func _is_vertical_range_open(layer: TileMapLayer, x: int, start_y: int, end_y: int) -> bool:
	for y in range(start_y, end_y + 1):
		if not _is_open(layer, Vector2i(x, y)):
			return false
	return true


func _boundary_matches(layer: TileMapLayer, map_size: Vector2i, openings: Dictionary) -> bool:
	for x: int in range(map_size.x):
		if _is_open(layer, Vector2i(x, 0)) != _offset_is_open(openings.get("top", []), x):
			return false
		if _is_open(layer, Vector2i(x, map_size.y - 1)) != _offset_is_open(openings.get("bottom", []), x):
			return false
	for y: int in range(1, map_size.y - 1):
		if _is_open(layer, Vector2i(0, y)) != _offset_is_open(openings.get("left", []), y):
			return false
		if _is_open(layer, Vector2i(map_size.x - 1, y)) != _offset_is_open(openings.get("right", []), y):
			return false
	return true


func _offset_is_open(ranges: Array, offset: int) -> bool:
	for opening: Vector2i in ranges:
		if offset >= opening.x and offset <= opening.y:
			return true
	return false


func _water_ranges_match(
	layer: TileMapLayer,
	x_ranges: Array[Vector2i],
	start_y: int,
	end_y: int
) -> bool:
	for x_range: Vector2i in x_ranges:
		for x: int in range(x_range.x, x_range.y + 1):
			for y: int in range(start_y, end_y + 1):
				var cell := Vector2i(x, y)
				if layer.get_cell_source_id(cell) != 0:
					return false
				if layer.get_cell_atlas_coords(cell) != Vector2i.ZERO:
					return false
	return true


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
