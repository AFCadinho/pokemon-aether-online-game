extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const ROUTE_4_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_4.tscn"
const ROUTE_24_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_24.tscn"
const ROUTE_9_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_9.tscn"
const ROUTE_5_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_5.tscn"

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	await _check_cerulean_openings()
	await _check_route_4_openings_and_water()
	await _check_route_24_openings_and_water()
	await _check_route_5_openings()
	await _check_route_9_opening()
	quit(1 if failed else 0)


func _check_cerulean_openings() -> void:
	var authored_city := (load(CITY_SCENE) as PackedScene).instantiate()
	var authored_water := authored_city.get_node("Tiles/Water") as TileMapLayer
	var authored_lower_north_water := {}
	for x: int in range(46, 65):
		for y: int in range(15, 21):
			var cell := Vector2i(x, y)
			authored_lower_north_water[cell] = authored_water.get_cell_source_id(cell) != -1
	authored_city.free()

	var city := await _instantiate_map(CITY_SCENE)
	var collision := city.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := city.find_map_tilemap_layer("Water") as TileMapLayer

	_check(_is_open(collision, Vector2i(49, 0)) and _is_open(collision, Vector2i(49, -1)), "Cerulean opens the Route 24 left water boundary")
	_check(_is_open(collision, Vector2i(56, 0)) and _is_open(collision, Vector2i(56, -1)), "Cerulean opens the Route 24 bridge boundary")
	_check(_is_open(collision, Vector2i(62, 0)) and _is_open(collision, Vector2i(62, -1)), "Cerulean opens the Route 24 right water boundary")
	_check(_is_open(collision, Vector2i(69, 0)) and _is_open(collision, Vector2i(69, -1)), "Cerulean opens the Route 24 path boundary")
	_check(_is_open(collision, Vector2i(0, 18)) and _is_open(collision, Vector2i(-1, 18)), "Cerulean opens the Route 4 water boundary")
	_check(_is_open(collision, Vector2i(12, 69)) and _is_open(collision, Vector2i(12, 70)), "Cerulean opens the Route 5 left path")
	_check(_is_open(collision, Vector2i(16, 69)) and _is_open(collision, Vector2i(16, 70)), "Cerulean opens the Route 5 grass approach")
	_check(_is_open(collision, Vector2i(21, 69)) and _is_open(collision, Vector2i(21, 70)), "Cerulean opens the Route 5 right path")
	_check(_is_open(collision, Vector2i(74, 44)) and _is_open(collision, Vector2i(75, 44)), "Cerulean keeps Route 9 on its separate east boundary")
	_check(not _is_open(water, Vector2i(49, 2)), "Cerulean marks the Route 24 left water spawn as water")
	_check(_is_open(water, Vector2i(56, 2)), "Cerulean keeps the Route 24 bridge spawn off water")
	_check(not _is_open(water, Vector2i(62, 2)), "Cerulean marks the Route 24 right water spawn as water")
	_check(_is_open(water, Vector2i(69, 2)), "Cerulean keeps the Route 24 path spawn off water")
	_check(not _is_open(water, Vector2i(2, 18)), "Cerulean marks the Route 4 water spawn as water")
	_check(_is_open(water, Vector2i(2, 25)), "Cerulean keeps the Route 4 road spawn off water")
	_check(
		not _is_open(water, Vector2i(49, 15)),
		"Cerulean preserves water beside the west foot of the Route 24 bridge"
	)
	_check(_is_open(water, Vector2i(56, 15)), "Cerulean keeps the lower Route 24 bridge off water")
	_check(
		not _is_open(water, Vector2i(62, 15)),
		"Cerulean preserves water beside the east foot of the Route 24 bridge"
	)
	var preserves_authored_water := true
	for cell_value: Variant in authored_lower_north_water:
		var cell := cell_value as Vector2i
		var authored_has_water := bool(authored_lower_north_water[cell_value])
		if (water.get_cell_source_id(cell) != -1) != authored_has_water:
			preserves_authored_water = false
			break
	_check(
		preserves_authored_water,
		"Cerulean preserves the hand-painted Water mask below its Route 24 transition"
	)
	await _free_map(city)


func _check_route_4_openings_and_water() -> void:
	var route := await _instantiate_map(ROUTE_4_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := route.find_map_tilemap_layer("Water") as TileMapLayer

	_check(_is_open(collision, Vector2i(99, 31)), "Route 4 opens its water exit")
	_check(_is_open(collision, Vector2i(99, 37)), "Route 4 keeps its road exit open")
	_check(not _is_open(water, Vector2i(99, 31)), "Route 4 water arrival restores Surf")
	_check(_is_open(water, Vector2i(99, 37)), "Route 4 road arrival remains on foot")
	await _free_map(route)


func _check_route_24_openings_and_water() -> void:
	var route := await _instantiate_map(ROUTE_24_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer
	var water := route.find_map_tilemap_layer("Water") as TileMapLayer

	_check(_is_open(collision, Vector2i(15, 59)), "Route 24 opens its left water exit")
	_check(_is_open(collision, Vector2i(22, 59)), "Route 24 opens its bridge exit")
	_check(_is_open(collision, Vector2i(28, 59)), "Route 24 opens its right water exit")
	_check(_is_open(collision, Vector2i(35, 59)), "Route 24 opens its path exit")
	for separator_x: int in [11, 19, 25, 31, 38]:
		_check(not _is_open(collision, Vector2i(separator_x, 59)), "Route 24 closes separator x=%d" % separator_x)
	_check(not _is_open(water, Vector2i(15, 58)), "Route 24 left water arrival restores Surf")
	_check(_is_open(water, Vector2i(22, 58)), "Route 24 bridge arrival remains on foot")
	_check(not _is_open(water, Vector2i(28, 58)), "Route 24 right water arrival restores Surf")
	_check(_is_open(water, Vector2i(35, 58)), "Route 24 path arrival remains on foot")
	await _free_map(route)


func _check_route_5_openings() -> void:
	var route := await _instantiate_map(ROUTE_5_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer

	_check(_is_open(collision, Vector2i(4, 17)), "Route 5 opens its left exit")
	_check(_is_open(collision, Vector2i(12, 17)), "Route 5 opens its grass exit")
	_check(_is_open(collision, Vector2i(20, 17)), "Route 5 opens its right exit")
	_check(not _is_open(collision, Vector2i(8, 17)), "Route 5 closes the first gap between exits")
	_check(not _is_open(collision, Vector2i(16, 17)), "Route 5 closes the second gap between exits")
	await _free_map(route)


func _check_route_9_opening() -> void:
	var route := await _instantiate_map(ROUTE_9_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer

	_check(_is_open(collision, Vector2i(0, 8)), "Route 9 opens its west-facing Cerulean exit")
	_check(not _is_open(collision, Vector2i(0, 4)), "Route 9 keeps the rest of its west boundary closed")
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
