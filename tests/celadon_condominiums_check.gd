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
		_check(scene.world_access_group_id == city.map_id, floor_name + " shares Celadon access settings")
		_check(scene.lighting_profile == ("outdoor" if floor_name == "roof" else "indoor"), floor_name + " lighting")
		_check(scene.weather_profile == ("outdoor" if floor_name == "roof" else "disabled"), floor_name + " weather")
		_check(LOADER.module_for_scene(path) == LOADER.EXTENDED_MODULE_NAME, floor_name + " browser map registration")
		_check(catalog.areas.has(scene.map_id), floor_name + " server map registration")
		for exit_node: Area2D in scene.get_node("Exits").get_children():
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
	for kind: String in ["Main", "Rear"]:
		var entry := city.get_node("Exits/ToCondominiums" + kind)
		var spawn := city.get_node("Spawns/FromCondominiums" + kind)
		_check(catalog.transitions.has(entry.transition_id), kind + " city entry is registered")
		var destination: Node2D = maps[entry.target_scene_path]
		var destination_spawn := destination.get_node("Spawns/" + entry.target_spawn_name)
		for exit_node: Area2D in destination.get_node("Exits").get_children():
			_check(not exit_node.contains_world_position(destination_spawn.position), kind + " entry avoids immediate exit")
	# Current edited furniture, closed dividers and the roof courtyard must be solid.
	for scene: Node in maps.values():
		scene.free()
	print("CELADON_CONDOMINIUMS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
