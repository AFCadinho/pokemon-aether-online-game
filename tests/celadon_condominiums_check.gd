extends SceneTree

const DIRECTORY := "res://scenes/overworld/kanto/towns/celadon_city/"
const FLOORS := {
	"1f": [Vector2i(22, 29), "FromMainExitToCeladon", "FromRearExitToCeladon"],
	"2f": [Vector2i(22, 28), "FromMainStairsDown", "FromRearStairsDown"],
	"3f": [Vector2i(22, 28), "FromMainStairsDown", "FromRearStairsDown"],
	"roof": [Vector2i(18, 28), "FromMainStairsDown", "FromRearStairsDown"],
	"roof_room": [Vector2i(14, 13), "FromRoofExit", ""],
}
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")
const VALIDATOR := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false
var maps := {}


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var city := (load(DIRECTORY + "celadon_city.tscn") as PackedScene).instantiate()
	maps[city.scene_file_path] = city
	for floor_name: String in FLOORS:
		var path := DIRECTORY + "celadon_condominiums_" + floor_name + ".tscn"
		var scene := (load(path) as PackedScene).instantiate()
		maps[path] = scene
	for floor_name: String in FLOORS:
		var path := DIRECTORY + "celadon_condominiums_" + floor_name + ".tscn"
		var scene: Node2D = maps[path]
		var spec: Array = FLOORS[floor_name]
		var collision := scene.get_node("Tiles/Collision") as TileMapLayer
		_check(scene.world_access_group_id == city.map_id, floor_name + " shares Celadon access settings")
		_check(scene.lighting_profile == ("outdoor" if floor_name == "roof" else "indoor"), floor_name + " lighting")
		_check(scene.weather_profile == ("outdoor" if floor_name == "roof" else "disabled"), floor_name + " weather")
		_check(LOADER.module_for_scene(path) == LOADER.EXTENDED_MODULE_NAME, floor_name + " browser map registration")
		_check(catalog.areas.has(scene.map_id), floor_name + " server map registration")
		var main := _reachable(scene, spec[0], str(spec[1]))
		var rear := {} if str(spec[2]).is_empty() else _reachable(scene, spec[0], str(spec[2]))
		for tile: Vector2i in main:
			_check(not rear.has(tile), floor_name + " keeps front and rear stairwells separate")
		for y in spec[0].y:
			for x in spec[0].x:
				var tile := Vector2i(x, y)
				if collision.get_cell_source_id(tile) == -1:
					_check(main.has(tile) or rear.has(tile), "%s has no stranded floor at %s" % [floor_name, tile])
		for spawn: Marker2D in scene.get_node("Spawns").get_children():
			_check(collision.get_cell_source_id(Vector2i(spawn.position / 32.0)) == -1, floor_name + " safe spawn " + str(spawn.name))
		for exit_node: Area2D in scene.get_node("Exits").get_children():
			var tile := Vector2i(exit_node.position / 32.0)
			var zone: Dictionary = rear if str(exit_node.name).begins_with("Rear") or str(exit_node.name) == "RoofRoomEntrance" else main
			_check(zone.has(tile), floor_name + " reaches " + str(exit_node.name) + " from the correct entrance")
			_check(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "Connected entry signal")
			_check(catalog.transitions.has(exit_node.transition_id), "Server transition " + exit_node.transition_id)
			var target: Node2D = maps[exit_node.target_scene_path]
			var spawn := target.get_node("Spawns/" + exit_node.target_spawn_name) as Marker2D
			for target_exit: Area2D in target.get_node("Exits").get_children():
				_check(not target_exit.contains_world_position(spawn.position), "Arrival avoids immediate return through " + str(target_exit.name))
			var exported: Dictionary = catalog.transitions[exit_node.transition_id].destination
			_check(exported.mapId == target.map_id and exported.spawnMarker == str(spawn.name), "Canonical transition destination")
			_check(exported.position == {"x": spawn.position.x, "y": spawn.position.y}, "Server arrival matches the scene")
		var errors: Array[String] = VALIDATOR.new().validate(scene.get_node("Visual"), "res://generated/tiled_visuals/celadon_condominiums_%s/celadon_condominiums_%s.visual.tileset.tres" % [floor_name, floor_name])
		_check(errors.is_empty(), floor_name + " atlas layout: " + str(errors))
	var city_reached := _reachable(city, Vector2i(80, 70), "FromRoute7")
	for kind: String in ["Main", "Rear"]:
		var entry := city.get_node("Exits/ToCondominiums" + kind)
		var spawn := city.get_node("Spawns/FromCondominiums" + kind)
		_check(city_reached.has(Vector2i(entry.position / 32.0)) and city_reached.has(Vector2i(spawn.position / 32.0)), kind + " city entrance and return are reachable from Route 7")
		_check(catalog.transitions.has(entry.transition_id), kind + " city entry is registered")
		var destination: Node2D = maps[entry.target_scene_path]
		var destination_spawn := destination.get_node("Spawns/" + entry.target_spawn_name)
		for exit_node: Area2D in destination.get_node("Exits").get_children():
			_check(not exit_node.contains_world_position(destination_spawn.position), kind + " entry avoids immediate exit")
	# Current edited furniture, closed dividers and the roof courtyard must be solid.
	for spec: Array in [["1f", Vector2i(4, 15)], ["1f", Vector2i(2, 22)], ["2f", Vector2i(9, 15)], ["3f", Vector2i(6, 18)], ["roof", Vector2i(9, 12)], ["roof", Vector2i(5, 19)], ["roof_room", Vector2i(5, 5)]]:
		var scene: Node2D = maps[DIRECTORY + "celadon_condominiums_" + spec[0] + ".tscn"]
		_check(scene.get_node("Tiles/Collision").get_cell_source_id(spec[1]) != -1, "Solid furniture/wall " + str(spec))
	for scene: Node in maps.values():
		scene.free()
	print("CELADON_CONDOMINIUMS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _reachable(scene: Node2D, size: Vector2i, marker: String) -> Dictionary:
	var collision := scene.get_node("Tiles/Collision") as TileMapLayer
	var start := Vector2i(scene.get_node("Spawns/" + marker).position / 32.0)
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
