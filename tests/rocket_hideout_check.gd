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
		var spec: Array = SPECS[key]
		var map: Node2D = maps[DIRECTORY + "rocket_hideout_" + key + ".tscn"]
		var collision := map.get_node("Tiles/Collision") as TileMapLayer
		var first := _reachable(collision, spec[0], Vector2i(map.get_node("Spawns/" + spec[1]).position / 32.0))
		var second := {} if str(spec[2]).is_empty() else _reachable(collision, spec[0], Vector2i(map.get_node("Spawns/" + spec[2]).position / 32.0))
		_check(map.world_access_group_id == "kanto_rocket_hideout" and map.world_access_area_type == "interior", key + " dungeon identity")
		_check(map.lighting_profile == "indoor" and map.weather_profile == "disabled", key + " indoor lighting/weather")
		_check(map.get_node("Visual/Ground").modulate.is_equal_approx(Color("d1edc0")), key + " source floor tint")
		_check(map.get_node("Visual/GroundDetail").modulate.is_equal_approx(Color("daeaff")), key + " source wall tint")
		for tile: Vector2i in first:
			_check(not second.has(tile), key + " preserves separate access wings")
		for y in spec[0].y:
			for x in spec[0].x:
				var tile := Vector2i(x, y)
				if collision.get_cell_source_id(tile) == -1:
					_check(first.has(tile) or second.has(tile), "%s has no stranded floor at %s" % [key, tile])
		for spawn: Marker2D in map.get_node("Spawns").get_children():
			_check(collision.get_cell_source_id(Vector2i(spawn.position / 32.0)) == -1, key + " safe spawn " + str(spawn.name))
		for exit_node: Area2D in map.get_node("Exits").get_children():
			transition_count += 1
			_check(catalog.transitions.has(exit_node.transition_id), "Server knows " + exit_node.transition_id)
			var manual := str(exit_node.name).begins_with("RideTo")
			if manual:
				_check(not exit_node.monitoring and exit_node.get_child_count() == 0, "Lift travel needs manual floor selection")
			else:
				var zone: Dictionary = second if (key == "b1f" and str(exit_node.name) == "DownToB2F") or (key == "b4f" and str(exit_node.name) == "ToElevator") else first
				_check(zone.has(Vector2i(exit_node.position / 32.0)), key + " reaches the correct staircase wing")
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
	var corner_reached := _reachable(corner.get_node("Tiles/Collision"), Vector2i(28, 21), Vector2i(13, 16))
	var entrance := corner.get_node("Exits/ToRocketHideout")
	_check(corner_reached.has(Vector2i(24, 5)) and corner_reached.has(Vector2i(25, 5)), "Casino entrance reaches both stair tiles")
	_check(entrance.target_scene_path == DIRECTORY + "rocket_hideout_b1f.tscn" and entrance.transition_facing_direction == "right", "Casino enters the B1F vestibule")
	# Spin logic uses separate markers and keeps the visual puzzle tiles walkable.
	for point: Array in [["b2f", Vector2i(4, 8)], ["b2f", Vector2i(6, 8)], ["b3f", Vector2i(4, 13)], ["b3f", Vector2i(6, 13)], ["b4f", Vector2i(24, 14)], ["b4f", Vector2i(25, 14)]]:
		_check(maps[DIRECTORY + "rocket_hideout_" + point[0] + ".tscn"].get_node("Tiles/Collision").get_cell_source_id(point[1]) == -1, "Walkable puzzle floor or overhead statue " + str(point))
	for point: Array in [["b2f", Vector2i(4, 7)], ["b3f", Vector2i(5, 14)], ["b4f", Vector2i(23, 16)], ["b4f", Vector2i(26, 16)]]:
		_check(maps[DIRECTORY + "rocket_hideout_" + point[0] + ".tscn"].get_node("Tiles/Collision").get_cell_source_id(point[1]) != -1, "Solid partition or statue base " + str(point))
	for map: Node in maps.values():
		map.free()
	print("ROCKET_HIDEOUT ", "FAIL" if failed else "PASS")
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
