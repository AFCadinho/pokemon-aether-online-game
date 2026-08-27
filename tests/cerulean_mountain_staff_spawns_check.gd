extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn"
const CATALOG_PATH := "res://generated/world_access_catalog.json"
const MOUNTAIN_SPAWNS := {
	"WestMountain": Vector2(112, 1520),
	"SouthMountain": Vector2(1584, 2096),
}

var failed := false


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var packed := load(CITY_SCENE) as PackedScene
	_check(packed != null, "Cerulean City loads for mountain spawn checks")
	if packed == null:
		quit(1)
		return

	var city := packed.instantiate()
	city.process_mode = Node.PROCESS_MODE_DISABLED
	root.add_child(city)
	var collision := city.get_node_or_null("Tiles/Collision") as TileMapLayer
	var water := city.get_node_or_null("Tiles/Water") as TileMapLayer
	var ground := _find_visual_layer(city, 1)
	_check(collision != null and water != null and ground != null, "Cerulean exposes spawn surface layers")

	for spawn_name_value: Variant in MOUNTAIN_SPAWNS:
		var spawn_name := str(spawn_name_value)
		var spawn := city.get_node_or_null("Spawns/%s" % spawn_name) as Marker2D
		_check(spawn != null, "Cerulean places %s" % spawn_name)
		if spawn == null or collision == null or water == null or ground == null:
			continue
		_check(spawn.position == MOUNTAIN_SPAWNS[spawn_name_value], "%s keeps its intended position" % spawn_name)
		var collision_cell := collision.local_to_map(collision.to_local(spawn.global_position))
		var water_cell := water.local_to_map(water.to_local(spawn.global_position))
		var ground_cell := ground.local_to_map(ground.to_local(spawn.global_position))
		_check(collision.get_cell_source_id(collision_cell) == -1, "%s starts off collision" % spawn_name)
		_check(water.get_cell_source_id(water_cell) == -1, "%s starts off water" % spawn_name)
		_check(ground.get_cell_source_id(ground_cell) != -1, "%s stands on Ground" % spawn_name)
		for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			_check(
				collision.get_cell_source_id(collision_cell + direction) == -1,
				"%s has a walkable neighboring tile" % spawn_name
			)

	_check_catalog()
	city.free()
	quit(1 if failed else 0)


func _find_visual_layer(city: Node, layer_id: int) -> TileMapLayer:
	var visuals := city.get_node_or_null("CeruleanCityVisual")
	if visuals == null:
		return null
	for child: Node in visuals.get_children():
		var layer := child as TileMapLayer
		if layer != null and int(layer.get_meta("tiled_layer_id", -1)) == layer_id:
			return layer
	return null


func _check_catalog() -> void:
	var payload_value: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	_check(payload_value is Dictionary, "World Access catalog loads for mountain spawns")
	if not payload_value is Dictionary:
		return
	var area := ((payload_value as Dictionary).get("areas", {}) as Dictionary).get(
		"kanto_cerulean_city",
		{}
	) as Dictionary
	var points := area.get("spawnPoints", {}) as Dictionary
	for point_id: String in ["west_mountain", "south_mountain"]:
		var point := points.get(point_id, {}) as Dictionary
		_check(not point.is_empty(), "Staff teleporter exposes %s" % point_id)
		_check(bool(point.get("safeForStaffTeleport", false)), "%s is safe for staff teleport" % point_id)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
		return
	failed = true
	push_error(message)
