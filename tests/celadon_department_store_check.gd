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
	var spawn: Marker2D = store.get_node("Spawns/FromOutside")
	var exit_node: Area2D = store.get_node("Exits/ToOutside")
	_check(store.map_id == MAP_ID and store.world_access_group_id == city.map_id, "Department Store belongs to Celadon")
	_check(store.world_access_area_type == "interior" and store.lighting_profile == "indoor" and store.weather_profile == "disabled", "Indoor lighting and weather")
	_check(store.get_node("FloorVisibilityMask").get_active_floor_region() == Rect2(0, 0, 1344, 1152), "Black mask covers the exterior of the map")
	for door_name: String in ["ToOutside", "ToOutside2"]:
		var door := store.get_node("Exits/" + door_name) as Area2D
		_check(not door.contains_world_position(spawn.position), "Arrival avoids both south exits")
	_check(not exit_node.contains_world_position(spawn.position), "Arrival avoids immediate return")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for suffix: String in ["", "East"]:
		var entry: Area2D = city.get_node("Exits/ToDepartmentStore" + suffix)
		_check(entry.target_scene_path == STORE_PATH and entry.target_spawn_name == "FromOutside" and entry.transition_facing_direction == "up", "Both city doors enter the shop")
		_check(entry.is_connected("body_entered", Callable(entry, "_on_body_entered")), "City entry signal")
		_check(catalog.transitions[entry.transition_id].destination.position == {"x": spawn.position.x, "y": spawn.position.y}, "Server authorizes the matching shop arrival")
	var return_spawn: Marker2D = city.get_node("Spawns/FromDepartmentStore")
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


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
