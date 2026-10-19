extends SceneTree

const DIRECTORY := "res://scenes/overworld/kanto/towns/celadon_city/"
const STORE_PATH := DIRECTORY + "celadon_department_store.tscn"
const MAP_ID := "kanto_celadon_department_store"
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")
const VALIDATOR := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var store: Node2D = load(STORE_PATH).instantiate()
	var city: Node2D = load(DIRECTORY + "celadon_city.tscn").instantiate()
	var collision: TileMapLayer = store.get_node("Tiles/Collision")
	var spawn: Marker2D = store.get_node("Spawns/FromOutside")
	var exit_node: Area2D = store.get_node("Exits/ToOutside")
	var reached := _reachable(collision, Vector2i(42, 36), Vector2i(spawn.position / 32.0))
	_check(store.map_id == MAP_ID and store.world_access_group_id == city.map_id, "Department Store belongs to Celadon")
	_check(store.world_access_area_type == "interior" and store.lighting_profile == "indoor" and store.weather_profile == "disabled", "Indoor lighting and weather")
	_check(store.get_node("FloorVisibilityMask").get_active_floor_region() == Rect2(0, 0, 1344, 1152), "Black mask covers the exterior of the map")
	_check(reached.has(Vector2i(20, 10)), "Public shop floor connects the entrance to the upper departments")
	for tile: Vector2i in [Vector2i(6, 10), Vector2i(15, 10), Vector2i(25, 10), Vector2i(34, 10), Vector2i(7, 25), Vector2i(33, 25), Vector2i(7, 32), Vector2i(33, 32)]:
		_check(reached.has(tile), "All eight departments have a reachable customer side: " + str(tile))
	for y in range(11, 18):
		for x in range(19, 23):
			_check(reached.has(Vector2i(x, y)), "Four stair columns and both landings remain open")
	for y in range(12, 15):
		for x in range(2, 40):
			if x >= 18 and x <= 23:
				continue
			_check(collision.get_cell_source_id(Vector2i(x, y)) != -1, "Balcony cannot be crossed away from the staircase")
	for y in range(23, 25):
		for x in range(19, 23):
			_check(collision.get_cell_source_id(Vector2i(x, y)) != -1, "Fountain is solid")
	for tile: Vector2i in [Vector2i(15, 19), Vector2i(26, 19), Vector2i(15, 22), Vector2i(26, 22), Vector2i(16, 30), Vector2i(25, 30), Vector2i(7, 23)]:
		_check(collision.get_cell_source_id(tile) != -1, "Solid rail/furniture base: " + str(tile))
	# The artist intentionally leaves black canvas padding without collision.
	# Verify containment from the playable side rather than treating that void as floor.
	var outer := _reachable(collision, Vector2i(43, 37), Vector2i(spawn.position / 32.0))
	_check(outer.size() == reached.size(), "Room boundaries prevent reaching the surrounding void")
	for tile: Vector2i in reached:
		_check(tile.x > 0 and tile.x < 41 and tile.y > 0 and tile.y < 35, "Public floor cannot escape into the void")
	for door_name: String in ["ToOutside", "ToOutside2"]:
		var door := store.get_node("Exits/" + door_name) as Area2D
		var center := Vector2i(door.position / 32.0)
		for dx in [-1,0,1]:
			var tile := center + Vector2i(dx,0)
			_check(reached.has(tile) and door.contains_world_position(Vector2(tile * 32 + Vector2i(16,16))), "Each three-tile south exit is reachable and covered")
		_check(not door.contains_world_position(spawn.position), "Arrival avoids both south exits")
	_check(not exit_node.contains_world_position(spawn.position), "Arrival avoids immediate return")
	var city_collision: TileMapLayer = city.get_node("Tiles/Collision")
	var city_reached := _reachable(city_collision, Vector2i(80, 70), Vector2i(city.get_node("Spawns/FromRoute7").position / 32.0))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for suffix: String in ["", "East"]:
		var entry: Area2D = city.get_node("Exits/ToDepartmentStore" + suffix)
		var tile := Vector2i(12 if suffix.is_empty() else 16, 13)
		_check(city.get_node("Visual/Doors").get_cell_source_id(tile) != -1, "Entrance aligns with a visible department-store door")
		_check(city_reached.has(tile) and entry.contains_world_position(Vector2(tile * 32 + Vector2i(16, 0))), "Door can be entered from Route 7")
		_check(entry.target_scene_path == STORE_PATH and entry.target_spawn_name == "FromOutside" and entry.transition_facing_direction == "up", "Both city doors enter the shop")
		_check(entry.is_connected("body_entered", Callable(entry, "_on_body_entered")), "City entry signal")
		_check(catalog.transitions[entry.transition_id].destination.position == {"x": spawn.position.x, "y": spawn.position.y}, "Server authorizes the matching shop arrival")
	var return_spawn: Marker2D = city.get_node("Spawns/FromDepartmentStore")
	_check(city_reached.has(Vector2i(return_spawn.position / 32.0)), "Return spawn is reachable and on clear pavement")
	for entry: Area2D in city.get_node("Exits").get_children():
		_check(not entry.contains_world_position(return_spawn.position), "Return avoids every city entry trigger")
	_check(exit_node.target_scene_path == city.scene_file_path and exit_node.target_spawn_name == "FromDepartmentStore" and exit_node.transition_facing_direction == "down", "Shop exit returns to Celadon facing out")
	_check(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "Shop exit signal")
	_check(catalog.transitions[exit_node.transition_id].destination.position == {"x": return_spawn.position.x, "y": return_spawn.position.y}, "Server and city return agree")
	_check(catalog.areas[MAP_ID].locationGroupId == city.map_id, "Server groups the new interior with its city")
	_check(LOADER.module_for_scene(STORE_PATH) == LOADER.EXTENDED_MODULE_NAME, "Browser knows the new interior")
	var visual: Node = store.get_node("Visual")
	var errors: Array[String] = VALIDATOR.new().validate(visual, "res://generated/tiled_visuals/celadon_department_store/celadon_department_store.visual.tileset.tres")
	_check(errors.is_empty(), "Imported atlas layout: " + str(errors))
	var fountain: TileMapLayer = visual.get_node("Objects")
	var coords := fountain.get_cell_atlas_coords(Vector2i(20, 24))
	var source := fountain.tile_set.get_source(fountain.get_cell_source_id(Vector2i(20, 24))) as TileSetAtlasSource
	_check(source.get_tile_animation_frames_count(coords) > 1, "Fountain retains native tile animation")
	store.free()
	city.free()
	print("CELADON_DEPARTMENT_STORE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _reachable(collision: TileMapLayer, size: Vector2i, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := tile + direction
			if not Rect2i(Vector2i.ZERO, size).has_point(next) or seen.has(next) or collision.get_cell_source_id(next) != -1:
				continue
			seen[next] = true
			queue.append(next)
	return seen


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
