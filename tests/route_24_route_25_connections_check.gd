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

	var route_24_water := route_24.find_map_tilemap_layer("Water") as TileMapLayer
	_check(
		_water_ranges_match(route_24_water, [Vector2i(21, 27), Vector2i(35, 39)], 55, 59),
		"Route 24 stores both complete Surf approaches"
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
