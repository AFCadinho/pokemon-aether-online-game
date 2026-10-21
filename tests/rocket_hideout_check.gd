extends SceneTree

const DIRECTORY := "res://scenes/overworld/kanto/towns/celadon_city/"
const SPECS := {
	"b1f": [Vector2i(37, 44), "FromUpToGameCorner", "FromDownToB2F"],
	"b2f": [Vector2i(37, 30), "FromNorthUpToB1F", ""],
	"b3f": [Vector2i(27, 35), "FromUpToB2F", ""],
	"b4f": [Vector2i(33, 39), "FromUpToB3F", "FromLift"],
}
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")
const VALIDATOR := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false
var maps := {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var corner := (load(DIRECTORY + "game_corner.tscn") as PackedScene).instantiate()
	maps[corner.scene_file_path] = corner
	for key: String in SPECS:
		var path := DIRECTORY + "rocket_hideout_" + key + ".tscn"
		maps[path] = (load(path) as PackedScene).instantiate()
	var cabin_path := DIRECTORY + "rocket_hideout_elevator.tscn"
	maps[cabin_path] = (load(cabin_path) as PackedScene).instantiate()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var transition_count := 1 # Game Corner entry.
	for key: String in SPECS:
		var map: Node2D = maps[DIRECTORY + "rocket_hideout_" + key + ".tscn"]
		_check(map.world_access_group_id == "kanto_rocket_hideout" and map.world_access_area_type == "interior", key + " dungeon identity")
		_check(map.lighting_profile == "indoor" and map.weather_profile == "disabled", key + " indoor lighting/weather")
		_check(map.get_node("Visual/Ground").modulate.is_equal_approx(Color("d1edc0")), key + " source floor tint")
		_check(map.get_node("Visual/GroundDetail").modulate.is_equal_approx(Color("daeaff")), key + " source wall tint")
		var ground := map.get_node("Visual/Ground") as TileMapLayer
		var void_source_id := ground.get_cell_source_id(Vector2i.ZERO)
		var void_coords := ground.get_cell_atlas_coords(Vector2i.ZERO)
		var atlas := ground.tile_set.get_source(void_source_id) as TileSetAtlasSource
		var void_image := atlas.texture.get_image().get_region(atlas.get_tile_texture_region(void_coords))
		var black_padding := true
		for py in void_image.get_height():
			for px in void_image.get_width():
				var pixel := void_image.get_pixel(px, py)
				black_padding = black_padding and (pixel.a == 0.0 or (pixel.r == 0.0 and pixel.g == 0.0 and pixel.b == 0.0))
		_check(black_padding, key + " padding reference is visually empty")
		for exit_node: Area2D in map.get_node("Exits").get_children():
			transition_count += 1
			_check(catalog.transitions.has(exit_node.transition_id), "Server knows " + exit_node.transition_id)
			var manual := str(exit_node.name).begins_with("RideTo")
			if manual:
				_check(not exit_node.monitoring and exit_node.get_child_count() == 0, "Lift travel needs manual floor selection")
			else:
				_check(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "Stair entry signal")
			var target: Node2D = maps[exit_node.target_scene_path]
			var target_spawn := target.get_node("Spawns/" + exit_node.target_spawn_name) as Marker2D
			for target_exit: Area2D in target.get_node("Exits").get_children():
				_check(not target_exit.contains_world_position(target_spawn.position), "Arrival avoids bounce-back into " + str(target_exit.name))
			var destination: Dictionary = catalog.transitions[exit_node.transition_id].destination
			_check(destination.mapId == target.map_id and destination.spawnMarker == str(target_spawn.name), "Canonical destination marker")
			_check(destination.position == {"x": target_spawn.position.x, "y": target_spawn.position.y}, "Server arrival matches the scene")
		if key != "b3f":
			var entrance := map.get_node("Exits/ToElevator")
			_check(entrance.target_scene_path == cabin_path and entrance.target_spawn_name == "FromFloor", "Lift door enters the shared cabin")
			_check(map.get_node_or_null("Entities/Interactables/Lift") == null, "Floor has no obsolete lift menu")
		_check(LOADER.module_for_scene(map.scene_file_path) == LOADER.EXTENDED_MODULE_NAME, key + " browser module")
		_check(catalog.areas[map.map_id].locationGroupId == "kanto_rocket_hideout", key + " server registration")
		var errors: Array[String] = VALIDATOR.new().validate(map.get_node("Visual"), "res://generated/tiled_visuals/rocket_hideout_%s/rocket_hideout_%s.visual.tileset.tres" % [key, key])
		_check(errors.is_empty(), key + " atlas layout: " + str(errors))
	transition_count += maps[cabin_path].get_node("Exits").get_child_count()
	_check(transition_count == 19, "Ten stair directions, three cabin entries, three rides and three cabin exits are configured")
	var entrance := corner.get_node("Exits/ToRocketHideout")
	_check(entrance.target_scene_path == DIRECTORY + "rocket_hideout_b1f.tscn" and entrance.transition_facing_direction == "right", "Casino enters the B1F vestibule")
	# Spin logic uses separate markers and keeps the visual puzzle tiles walkable.
	for map: Node in maps.values():
		map.free()
	print("ROCKET_HIDEOUT ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
