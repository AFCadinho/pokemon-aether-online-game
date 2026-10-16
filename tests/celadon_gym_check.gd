extends SceneTree

const DIRECTORY := "res://scenes/overworld/kanto/towns/celadon_city/"
const GYM_PATH := DIRECTORY + "celadon_gym.tscn"
const MAP_ID := "kanto_celadon_gym"
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")
const VALIDATOR := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var gym := (load(GYM_PATH) as PackedScene).instantiate()
	var city := (load(DIRECTORY + "celadon_city.tscn") as PackedScene).instantiate()
	var collision := gym.get_node("Tiles/Collision") as TileMapLayer
	var spawn := gym.get_node("Spawns/FromOutside") as Marker2D
	var reached := _reachable(collision, Vector2i(42, 68), Vector2i(spawn.position / 32.0))
	_check(gym.map_id == MAP_ID and gym.world_access_group_id == city.map_id, "Gym identity and Celadon access group")
	_check(gym.world_access_area_type == "interior" and gym.lighting_profile == "indoor" and gym.weather_profile == "disabled", "Indoor lighting and weather")
	_check(gym.music_profile_id == "gym.interior", "Shared Gym music profile")
	_check(reached.size() == 730 and reached.get(Vector2i(20, 10), -1) == 120, "Garden route reaches the leader in 120 steps across 730 public tiles")
	for x: int in [6, 12, 18, 28, 34]:
		for y: int in [18, 23, 35, 40, 52]:
			_check(reached.has(Vector2i(x, y)), "Reachable garden room at " + str(Vector2i(x, y)))
	for gate: Vector2i in [Vector2i(6, 18), Vector2i(6, 30), Vector2i(6, 47), Vector2i(12, 30), Vector2i(12, 47), Vector2i(28, 18), Vector2i(28, 35), Vector2i(34, 18), Vector2i(34, 30), Vector2i(34, 47), Vector2i(20, 54)]:
		for y in range(gate.y, gate.y + 4):
			for x in range(gate.x, gate.x + 2):
				_check(reached.has(Vector2i(x, y)), "Both columns stay open beneath the pergola: " + str(Vector2i(x, y)))
	for y in range(12, 17):
		for x in range(19, 22):
			_check(reached.has(Vector2i(x, y)), "Stair treads and both landings are open")
	for y in 68:
		for x in 42:
			var tile := Vector2i(x, y)
			if collision.get_cell_source_id(tile) != -1 or reached.has(tile):
				continue
			var decorative := (y >= 56 and y <= 63 and (x < 18 or x > 22)) or Rect2i(7, 7, 9, 6).has_point(tile) or Rect2i(26, 7, 9, 6).has_point(tile)
			_check(decorative, "No unintended stranded floor: " + str(tile))
	_check(not reached.has(Vector2i(13, 9)) and not reached.has(Vector2i(28, 9)) and not reached.has(Vector2i(3, 56)), "Stage and entrance gardens remain physically enclosed")
	for tile: Vector2i in [Vector2i(15, 52), Vector2i(15, 53), Vector2i(25, 53), Vector2i(15, 44), Vector2i(15, 50), Vector2i(16, 50), Vector2i(3, 17)]:
		_check(collision.get_cell_source_id(tile) != -1, "Flowers and hedges are solid: " + str(tile))
	var objects := gym.get_node("Visual/Objects") as TileMapLayer
	for fountain_y: int in [24, 41]:
		for y in range(fountain_y, fountain_y + 4):
			for x in range(19, 23):
				var tile := Vector2i(x, y)
				_check(collision.get_cell_source_id(tile) != -1, "Fountain footprint is solid")
				var source := objects.tile_set.get_source(objects.get_cell_source_id(tile)) as TileSetAtlasSource
				var coords := objects.get_cell_atlas_coords(tile)
				_check(source.get_tile_animation_frames_count(coords) == 24, "All fountain parts retain 24 animation frames")
				for frame in 24:
					_check(is_equal_approx(source.get_tile_animation_frame_duration(coords, frame), 0.1), "Fountain animation timing is preserved")
		for approach: Vector2i in [Vector2i(18, fountain_y + 1), Vector2i(23, fountain_y + 1), Vector2i(20, fountain_y - 1), Vector2i(20, fountain_y + 4)]:
			_check(reached.has(approach), "Free circulation around both fountains")
	var entrance := city.get_node("Exits/ToGym")
	var exit_node := gym.get_node("Exits/ToOutside")
	var city_spawn := city.get_node("Spawns/FromGym") as Marker2D
	_check(entrance.target_scene_path == GYM_PATH and entrance.target_spawn_name == "FromOutside", "City doorway enters the Gym")
	_check(exit_node.target_scene_path == city.scene_file_path and exit_node.target_spawn_name == "FromGym", "Gym returns to its city doorway")
	_check(entrance.transition_facing_direction == "up" and exit_node.transition_facing_direction == "down", "Arrivals face into their destination")
	_check(not entrance.contains_world_position(city_spawn.position) and not exit_node.contains_world_position(spawn.position), "Arrivals avoid immediate return")
	_check(city.get_node("Visual/Doors").get_cell_source_id(Vector2i(11, 48)) != -1 and entrance.contains_world_position(Vector2(368, 1552)), "City trigger aligns with the visible Gym door")
	for x in range(19, 22):
		_check(reached.has(Vector2i(x, 64)) and exit_node.contains_world_position(Vector2(x * 32 + 16, 2064)), "Full three-tile south exit is traversable")
	var city_reached := _reachable(city.get_node("Tiles/Collision"), Vector2i(80, 70), Vector2i(city.get_node("Spawns/FromRoute7").position / 32.0))
	_check(city_reached.has(Vector2i(11, 48)) and city_reached.has(Vector2i(11, 50)), "Gym door and return can be reached from Route 7")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(MAP_ID) and catalog.areas[MAP_ID].locationGroupId == city.map_id, "Server registers the Gym as a Celadon interior")
	for pair: Array in [[entrance, gym, spawn], [exit_node, city, city_spawn]]:
		var transition: Area2D = pair[0]
		_check(transition.is_connected("body_entered", Callable(transition, "_on_body_entered")), "Door entry signal")
		var target: Dictionary = catalog.transitions[transition.transition_id].destination
		_check(target.mapId == pair[1].map_id and target.spawnMarker == str(pair[2].name), "Canonical server arrival marker")
		_check(target.position == {"x": pair[2].position.x, "y": pair[2].position.y}, "Server and scene agree on arrival coordinates")
	_check(LOADER.module_for_scene(GYM_PATH) == LOADER.EXTENDED_MODULE_NAME, "Browser can load Celadon Gym")
	var errors: Array[String] = VALIDATOR.new().validate(gym.get_node("Visual"), "res://generated/tiled_visuals/celadon_gym/celadon_gym.visual.tileset.tres")
	_check(errors.is_empty(), "Imported atlas layout: " + str(errors))
	gym.free()
	city.free()
	print("CELADON_GYM ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _reachable(collision: TileMapLayer, size: Vector2i, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var reached := {start: 0}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var candidate := tile + offset
			if not Rect2i(Vector2i.ZERO, size).has_point(candidate) or reached.has(candidate) or collision.get_cell_source_id(candidate) != -1:
				continue
			reached[candidate] = int(reached[tile]) + 1
			queue.append(candidate)
	return reached


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
