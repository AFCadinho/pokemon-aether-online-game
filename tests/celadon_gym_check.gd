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
	var spawn := gym.get_node("Spawns/FromOutside") as Marker2D
	_check(gym.map_id == MAP_ID and gym.world_access_group_id == city.map_id, "Gym identity and Celadon access group")
	_check(gym.world_access_area_type == "interior" and gym.lighting_profile == "indoor" and gym.weather_profile == "disabled", "Indoor lighting and weather")
	_check(gym.music_profile_id == "gym.interior", "Shared Gym music profile")
	var objects := gym.get_node("Visual/Objects") as TileMapLayer
	var objects_top := gym.get_node("Visual/ObjectsTop") as TileMapLayer
	for fountain_y: int in [24, 41]:
		for y in range(fountain_y, fountain_y + 4):
			for x in range(19, 23):
				var tile := Vector2i(x, y)
				var layer := objects_top if objects_top.get_cell_source_id(tile) != -1 else objects
				_check(layer.get_cell_source_id(tile) != -1, "Fountain part is present across the drawing layers")
				if layer.get_cell_source_id(tile) == -1:
					continue
				var source := layer.tile_set.get_source(layer.get_cell_source_id(tile)) as TileSetAtlasSource
				var coords := layer.get_cell_atlas_coords(tile)
				_check(source.get_tile_animation_frames_count(coords) == 24, "All fountain parts retain 24 animation frames")
				for frame in 24:
					_check(is_equal_approx(source.get_tile_animation_frame_duration(coords, frame), 0.1), "Fountain animation timing is preserved")
	var entrance := city.get_node("Exits/ToGym")
	var exit_node := gym.get_node("Exits/ToOutside")
	var city_spawn := city.get_node("Spawns/FromGym") as Marker2D
	_check(entrance.target_scene_path == GYM_PATH and entrance.target_spawn_name == "FromOutside", "City doorway enters the Gym")
	_check(exit_node.target_scene_path == city.scene_file_path and exit_node.target_spawn_name == "FromGym", "Gym returns to its city doorway")
	_check(entrance.transition_facing_direction == "up" and exit_node.transition_facing_direction == "down", "Arrivals face into their destination")
	_check(not entrance.contains_world_position(city_spawn.position) and not exit_node.contains_world_position(spawn.position), "Arrivals avoid immediate return")
	_check(city.get_node("Visual/Doors").get_cell_source_id(Vector2i(11, 48)) != -1 and entrance.contains_world_position(Vector2(368, 1536)), "City trigger aligns with the visible Gym door")
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


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
