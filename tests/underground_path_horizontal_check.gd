extends SceneTree

const ROUTE_8 := "res://scenes/overworld/kanto/routes/kanto_route_8.tscn"
const ROUTE_7_ENTRANCE := "res://scenes/overworld/kanto/interiors/underground_path/route_7_entrance.tscn"
const ROUTE_8_ENTRANCE := "res://scenes/overworld/kanto/interiors/underground_path/route_8_entrance.tscn"
const HORIZONTAL_TUNNEL := "res://scenes/overworld/kanto/interiors/underground_path/tunnel_horizontal.tscn"

var failures := 0


func _initialize() -> void:
	_check_scene(ROUTE_7_ENTRANCE, "kanto_underground_path_route_7_entrance", Vector2i(24, 18))
	_check_scene(ROUTE_8_ENTRANCE, "kanto_underground_path_route_8_entrance", Vector2i(24, 18))
	_check_scene(HORIZONTAL_TUNNEL, "kanto_underground_path_horizontal", Vector2i(96, 16))
	var route_8 := (load(ROUTE_8) as PackedScene).instantiate()
	_check(route_8.has_node("Spawns/FromUndergroundPath"), "Route 8 has its underground arrival spawn")
	_check(route_8.has_node("Exits/ToUndergroundPath"), "Route 8 connects to its entrance")
	_check(
		str(route_8.get_node("Exits/ToUndergroundPath").get("target_scene_path")) == ROUTE_8_ENTRANCE,
		"Route 8 entrance exit targets its scene"
	)
	route_8.free()
	quit(0 if failures == 0 else 1)


func _check_scene(path: String, expected_map_id: String, expected_size: Vector2i) -> void:
	var packed := load(path) as PackedScene
	_check(packed != null, path + " loads")
	if packed == null:
		return
	var scene := packed.instantiate()
	_check(str(scene.get("map_id")) == expected_map_id, expected_map_id + " map id")
	_check(scene.has_node("Visual/Ground"), expected_map_id + " has imported Tiled visual")
	var visual_map: Dictionary = scene.get_node("Visual").get_meta("tiled_visual_map", {})
	_check(
		Vector2i(int(visual_map.get("width", 0)), int(visual_map.get("height", 0))) == expected_size,
		expected_map_id + " visual dimensions"
	)
	_check(scene.has_node("Tiles/Collision"), expected_map_id + " exposes an empty collision layer")
	if scene.has_node("Tiles/Collision"):
		_check(
			(scene.get_node("Tiles/Collision") as TileMapLayer).get_used_cells().is_empty(),
			expected_map_id + " leaves collision cells empty"
		)
	var exits := scene.get_node_or_null("Exits")
	_check(exits != null and exits.get_child_count() > 0, expected_map_id + " has gameplay exits")
	if exits != null:
		for exit_node in exits.get_children():
			var target_scene := str(exit_node.get("target_scene_path"))
			_check(ResourceLoader.exists(target_scene), expected_map_id + " exit target exists")
			var target_packed := load(target_scene) as PackedScene if ResourceLoader.exists(target_scene) else null
			var target_spawn := str(exit_node.get("target_spawn_name"))
			var target_has_spawn := false
			if target_packed != null:
				var target_instance := target_packed.instantiate()
				target_has_spawn = target_instance.has_node("Spawns/" + target_spawn)
				target_instance.free()
			_check(target_has_spawn, expected_map_id + " exit target spawn exists")
			_check(str(exit_node.get("transition_id")).strip_edges() != "", expected_map_id + " exit has an authorized transition id")
	scene.free()


func _check(condition: bool, description: String) -> void:
	if condition:
		return
	failures += 1
	push_error("Horizontal underground path: " + description)
