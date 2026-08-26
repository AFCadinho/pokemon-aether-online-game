extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const ROUTE_24_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const ROUTE_9_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_9.tscn"
const ROUTE_5_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_5.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_cerulean_openings()
	await _check_route_24_openings_and_water()
	await _check_route_9_openings()
	await _check_route_5_opening()
	quit(1 if failed else 0)


func _check_cerulean_openings() -> void:
	var city := await _instantiate_map(CITY_SCENE)
	var collision := city.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := city.find_map_tilemap_layer("Water") as TileMapLayer

	_check(_is_open(collision, Vector2i(58, 0)) and _is_open(collision, Vector2i(58, -1)), "Cerulean opens the Route 24 water boundary")
	_check(_is_open(collision, Vector2i(69, 0)) and _is_open(collision, Vector2i(69, -1)), "Cerulean opens the Route 24 path boundary")
	_check(_is_open(collision, Vector2i(12, 69)) and _is_open(collision, Vector2i(12, 70)), "Cerulean opens the Route 9 left path")
	_check(_is_open(collision, Vector2i(16, 69)) and _is_open(collision, Vector2i(16, 70)), "Cerulean opens the Route 9 grass approach")
	_check(_is_open(collision, Vector2i(21, 69)) and _is_open(collision, Vector2i(21, 70)), "Cerulean opens the Route 9 right path")
	_check(_is_open(collision, Vector2i(74, 44)) and _is_open(collision, Vector2i(75, 44)), "Cerulean keeps Route 5 on its separate east boundary")
	_check(not _is_open(water, Vector2i(58, 2)), "Cerulean marks the Route 24 water spawn as water")
	_check(_is_open(water, Vector2i(69, 2)), "Cerulean keeps the Route 24 path spawn off water")
	await _free_map(city)


func _check_route_24_openings_and_water() -> void:
	var route := await _instantiate_map(ROUTE_24_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := route.find_map_tilemap_layer("Water") as TileMapLayer

	_check(_is_open(collision, Vector2i(4, 17)), "Route 24 opens its water exit")
	_check(_is_open(collision, Vector2i(12, 17)), "Route 24 opens its path exit")
	_check(not _is_open(collision, Vector2i(8, 17)), "Route 24 keeps the boundary between both exits closed")
	_check(not _is_open(water, Vector2i(4, 16)), "Route 24 water arrival restores Surf")
	_check(_is_open(water, Vector2i(12, 16)), "Route 24 path arrival remains on foot")
	await _free_map(route)


func _check_route_9_openings() -> void:
	var route := await _instantiate_map(ROUTE_9_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer

	_check(_is_open(collision, Vector2i(4, 17)), "Route 9 opens its left exit")
	_check(_is_open(collision, Vector2i(12, 17)), "Route 9 opens its grass exit")
	_check(_is_open(collision, Vector2i(20, 17)), "Route 9 opens its right exit")
	_check(not _is_open(collision, Vector2i(8, 17)), "Route 9 closes the first gap between exits")
	_check(not _is_open(collision, Vector2i(16, 17)), "Route 9 closes the second gap between exits")
	await _free_map(route)


func _check_route_5_opening() -> void:
	var route := await _instantiate_map(ROUTE_5_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer

	_check(_is_open(collision, Vector2i(0, 8)), "Route 5 opens its west-facing Cerulean exit")
	_check(not _is_open(collision, Vector2i(0, 4)), "Route 5 keeps the rest of its west boundary closed")
	await _free_map(route)


func _instantiate_map(scene_path: String) -> Node:
	var packed := load(scene_path) as PackedScene
	var map := packed.instantiate()
	root.add_child(map)
	await process_frame
	return map


func _free_map(map: Node) -> void:
	map.queue_free()
	await process_frame


func _is_open(layer: TileMapLayer, cell: Vector2i) -> bool:
	return layer != null and layer.get_cell_source_id(cell) == -1


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
