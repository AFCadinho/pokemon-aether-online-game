extends SceneTree

const ROUTE_4_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_4.tscn"
const BIKE_STORE_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn"
const CERULEAN_CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const MAP_METADATA_SCRIPT := "res://scripts/world/map_metadata.gd"
const KANTO_WORLD_SCRIPTS := "res://scripts/world/kanto"
const STATIC_LAYER_MUTATIONS := [
	"collision.set_cell(",
	"collision.erase_cell(",
	"collision.clear(",
	"water.set_cell(",
	"water.erase_cell(",
	"water.clear(",
]
const REMOVED_STATIC_COLLISION_SCRIPTS := [
	"res://scripts/world/kanto/open_field_placeholder_map.gd",
	"res://scripts/world/kanto/routes/kanto_route_4.gd",
	"res://scripts/world/kanto/towns/cerulean_bike_shop.gd",
]

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for script_path: String in REMOVED_STATIC_COLLISION_SCRIPTS:
		_check(not FileAccess.file_exists(script_path), "%s is removed" % script_path.get_file())
	var mutation_users: Array[String] = []
	_scan_for_static_layer_mutation(KANTO_WORLD_SCRIPTS, mutation_users)
	_check(
		mutation_users.is_empty(),
		"Kanto world scripts do not mutate authored Collision or Water layers: %s"
			% str(mutation_users)
	)

	await _check_route_4()
	await _check_static_startup(BIKE_STORE_SCENE, ["Collision"])
	await _check_static_startup(CERULEAN_CITY_SCENE, ["Collision", "Water"])
	quit(1 if failed else 0)


func _scan_for_static_layer_mutation(directory_path: String, mutation_users: Array[String]) -> void:
	var directory := DirAccess.open(directory_path)
	if directory == null:
		failed = true
		push_error("FAIL Could not scan %s" % directory_path)
		return
	directory.list_dir_begin()
	var entry := directory.get_next()
	while entry != "":
		var entry_path := directory_path.path_join(entry)
		if directory.current_is_dir():
			_scan_for_static_layer_mutation(entry_path, mutation_users)
		elif entry.ends_with(".gd"):
			var source := FileAccess.get_file_as_string(entry_path)
			for mutation: String in STATIC_LAYER_MUTATIONS:
				if source.contains(mutation):
					mutation_users.append(entry_path)
					break
		entry = directory.get_next()
	directory.list_dir_end()


func _check_route_4() -> void:
	var route := (load(ROUTE_4_SCENE) as PackedScene).instantiate()
	_check(
		route.get_script() != null and route.get_script().resource_path == MAP_METADATA_SCRIPT,
		"Route 4 uses metadata without Collision code"
	)
	var collision := route.find_map_tilemap_layer("Collision") as TileMapLayer
	var before := _cell_state(collision)
	_check(_route_4_boundary_matches(collision), "Route 4 stores its complete authored boundary")
	root.add_child(route)
	await process_frame
	_check(before == _cell_state(collision), "Route 4 leaves authored Collision unchanged during startup")
	route.queue_free()
	await process_frame


func _check_static_startup(scene_path: String, layer_names: Array[String]) -> void:
	var map := (load(scene_path) as PackedScene).instantiate()
	var before := {}
	for layer_name: String in layer_names:
		var layer := map.find_map_tilemap_layer(layer_name) as TileMapLayer
		_check(layer != null and not layer.get_used_cells().is_empty(), "%s stores authored %s cells" % [scene_path.get_file(), layer_name])
		before[layer_name] = _cell_state(layer)
	root.add_child(map)
	await process_frame
	for layer_name: String in layer_names:
		var layer := map.find_map_tilemap_layer(layer_name) as TileMapLayer
		_check(
			before[layer_name] == _cell_state(layer),
			"%s leaves authored %s unchanged during startup" % [scene_path.get_file(), layer_name]
		)
	map.queue_free()
	await process_frame


func _route_4_boundary_matches(layer: TileMapLayer) -> bool:
	for x: int in range(100):
		if _is_open(layer, Vector2i(x, 0)) or _is_open(layer, Vector2i(x, 49)):
			return false
	for y: int in range(1, 49):
		if _is_open(layer, Vector2i(0, y)):
			return false
		var expected_right_open := (y >= 28 and y <= 34) or (y >= 36 and y <= 39)
		if _is_open(layer, Vector2i(99, y)) != expected_right_open:
			return false
	return true


func _is_open(layer: TileMapLayer, cell: Vector2i) -> bool:
	return layer != null and layer.get_cell_source_id(cell) == -1


func _cell_state(layer: TileMapLayer) -> Dictionary:
	var result := {}
	for cell: Vector2i in layer.get_used_cells():
		result[cell] = [
			layer.get_cell_source_id(cell),
			layer.get_cell_atlas_coords(cell),
			layer.get_cell_alternative_tile(cell),
		]
	return result


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error("FAIL %s" % message)
