extends SceneTree

const DIRECTORY := "res://scenes/overworld/kanto/towns/celadon_city/"
const SCENE_PATH := DIRECTORY + "game_corner.tscn"
const MAP_ID := "kanto_celadon_game_corner"
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")
const VALIDATOR := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var corner := (load(SCENE_PATH) as PackedScene).instantiate()
	var city := (load(DIRECTORY + "celadon_city.tscn") as PackedScene).instantiate()
	var collision := corner.get_node("Tiles/Collision") as TileMapLayer
	var spawn := corner.get_node("Spawns/FromOutside") as Marker2D
	var reached := _reachable(collision, Vector2i(28, 21), Vector2i(spawn.position / 32.0))
	_check(corner.map_id == MAP_ID and corner.world_access_group_id == city.map_id, "Game Corner shares Celadon access settings")
	_check(corner.world_access_area_type == "interior" and corner.lighting_profile == "indoor" and corner.weather_profile == "disabled", "Indoor lighting and weather")
	for y in 21:
		for x in 28:
			var tile := Vector2i(x, y)
			if collision.get_cell_source_id(tile) == -1:
				_check(reached.has(tile), "No stranded public floor at " + str(tile))
	for tile: Vector2i in [Vector2i(13, 8), Vector2i(3, 9), Vector2i(24, 9), Vector2i(6, 12), Vector2i(21, 12), Vector2i(23, 5)]:
		_check(reached.has(tile), "Reception, salons, aisles and stair approach are reachable: " + str(tile))
	var seat_count := 0
	for bank: Vector3i in [Vector3i(9, 10, 6), Vector3i(17, 10, 6), Vector3i(3, 12, 4), Vector3i(23, 12, 4)]:
		for y in range(bank.y, bank.y + bank.z):
			for x: int in [bank.x - 1, bank.x + 2]:
				seat_count += 1
				_check(reached.has(Vector2i(x, y)), "Cushion standing spot is reachable: " + str(Vector2i(x, y)))
				_check(collision.get_cell_source_id(Vector2i(bank.x, y)) != -1 and collision.get_cell_source_id(Vector2i(bank.x + 1, y)) != -1, "Machines remain solid beside each cushion")
	_check(seat_count == 40, "All forty playing positions were checked")
	_check(corner.get_node("Visual/Objects").z_index < corner.get_node("Entities").z_index, "Cushions draw below the player")
	for tile: Vector2i in [Vector2i(13, 6), Vector2i(13, 7), Vector2i(13, 5), Vector2i(2, 8), Vector2i(22, 8), Vector2i(6, 6), Vector2i(20, 6), Vector2i(24, 5), Vector2i(25, 5), Vector2i(1, 17), Vector2i(26, 17)]:
		_check(collision.get_cell_source_id(tile) != -1, "Solid counter, furniture, staff enclosure or unfinished stair: " + str(tile))
	var entrance := city.get_node("Exits/ToGameCorner")
	var exit_node := corner.get_node("Exits/ToOutside")
	var city_spawn := city.get_node("Spawns/FromGameCorner") as Marker2D
	_check(entrance.target_scene_path == SCENE_PATH and entrance.target_spawn_name == "FromOutside", "City door enters Game Corner")
	_check(exit_node.target_scene_path == city.scene_file_path and exit_node.target_spawn_name == "FromGameCorner", "Game Corner returns to its own city door")
	_check(entrance.transition_facing_direction == "up" and exit_node.transition_facing_direction == "down", "Arrivals face away from their return triggers")
	_check(not entrance.contains_world_position(city_spawn.position) and not exit_node.contains_world_position(spawn.position), "Arrivals avoid immediate bounce-back")
	_check(entrance.contains_world_position(Vector2(1264, 880)), "Entry covers the visible city doorway at (39,27)")
	for x in range(12, 15):
		var tile := Vector2i(x, 18)
		_check(reached.has(tile) and exit_node.contains_world_position(Vector2(tile * 32) + Vector2(16, 16)), "Complete three-tile south exit")
	var city_reached := _reachable(city.get_node("Tiles/Collision"), Vector2i(80, 70), Vector2i(city.get_node("Spawns/FromRoute7").position / 32.0))
	_check(city_reached.has(Vector2i(39, 27)) and city_reached.has(Vector2i(39, 29)), "Door and city return are reachable from Route 7")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(MAP_ID) and catalog.areas[MAP_ID].locationGroupId == city.map_id, "Server knows this city interior")
	for pair: Array in [[entrance, corner, spawn], [exit_node, city, city_spawn]]:
		var transition: Area2D = pair[0]
		_check(transition.is_connected("body_entered", Callable(transition, "_on_body_entered")), "Player entry signal is connected")
		_check(catalog.transitions.has(transition.transition_id), "Transition is registered on the server")
		var destination: Dictionary = catalog.transitions[transition.transition_id].destination
		_check(destination.mapId == pair[1].map_id and destination.spawnMarker == str(pair[2].name), "Canonical server arrival marker")
		_check(destination.position == {"x": pair[2].position.x, "y": pair[2].position.y}, "Server arrival matches scene coordinates")
	_check(corner.get_node("Exits").get_child_count() == 1, "No dangling transition to an unconnected Rocket Hideout")
	_check(LOADER.module_for_scene(SCENE_PATH) == LOADER.EXTENDED_MODULE_NAME, "Browser can load Game Corner")
	var errors: Array[String] = VALIDATOR.new().validate(corner.get_node("Visual"), "res://generated/tiled_visuals/celadon_game_corner/celadon_game_corner.visual.tileset.tres")
	_check(errors.is_empty(), "Imported atlas layout: " + str(errors))
	corner.free()
	city.free()
	print("CELADON_GAME_CORNER ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _reachable(collision: TileMapLayer, size: Vector2i, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var reached := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate := tile + offset
			if not Rect2i(Vector2i.ZERO, size).has_point(candidate) or reached.has(candidate) or collision.get_cell_source_id(candidate) != -1:
				continue
			reached[candidate] = true
			queue.append(candidate)
	return reached


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
