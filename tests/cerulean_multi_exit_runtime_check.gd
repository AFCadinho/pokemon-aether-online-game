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
	var water := city.find_map_tilemap_layer("Water") as TileMapLayer

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

	await _free_map(route)


func _check_route_24_openings_and_water() -> void:
	var route := await _instantiate_map(ROUTE_24_SCENE)

	await _free_map(route)


func _check_route_5_openings() -> void:
	var route := await _instantiate_map(ROUTE_5_SCENE)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer

	var exit_cells: Array[Vector2i] = []
	for suffix: String in ["Left", "Grass", "Right"]:
		var exit := route.get_node("Exits/ToCerulean" + suffix) as Area2D
		var cell := collision.local_to_map(collision.to_local(exit.global_position))
		exit_cells.append(cell)

	await _free_map(route)


func _check_route_9_opening() -> void:
	var route := await _instantiate_map(ROUTE_9_SCENE)

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


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
