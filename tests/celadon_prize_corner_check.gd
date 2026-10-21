extends SceneTree

const DIRECTORY := "res://scenes/overworld/kanto/towns/celadon_city/"
const SCENE := DIRECTORY + "celadon_prize_corner.tscn"
const MAP_ID := "kanto_celadon_prize_corner"
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")
const VALIDATOR := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var room: Node2D = load(SCENE).instantiate()
	var city: Node2D = load(DIRECTORY + "celadon_city.tscn").instantiate()
	var spawn: Marker2D = room.get_node("Spawns/FromOutside")
	var entrance: Area2D = city.get_node("Exits/ToPrizeCorner")
	var exit_node: Area2D = room.get_node("Exits/ToOutside")
	var city_spawn: Marker2D = city.get_node("Spawns/FromPrizeCorner")
	_check(room.map_id == MAP_ID and room.world_access_group_id == city.map_id, "Prize Corner shares Celadon access")
	_check(room.world_access_area_type == "interior" and room.lighting_profile == "indoor" and room.weather_profile == "disabled", "Indoor lighting and weather")
	_check(entrance.target_scene_path == SCENE and entrance.target_spawn_name == "FromOutside", "City door enters Prize Corner")
	_check(exit_node.target_scene_path == city.scene_file_path and exit_node.target_spawn_name == "FromPrizeCorner", "Return goes to the matching city door")
	_check(entrance.transition_facing_direction == "up" and exit_node.transition_facing_direction == "down", "Reciprocal arrival facing")
	_check(not entrance.contains_world_position(city_spawn.position) and not exit_node.contains_world_position(spawn.position), "No immediate return-trigger loop")
	_check(exit_node.contains_world_position(Vector2(240, 464)), "Exit trigger covers the single-tile threshold")
	_check(not exit_node.contains_world_position(Vector2(272, 464)), "Exit does not cover the adjacent blocked front tile")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas.has(MAP_ID) and catalog.areas[MAP_ID].locationGroupId == city.map_id, "Server registers the interior")
	for pair: Array in [[entrance, room, spawn], [exit_node, city, city_spawn]]:
		var transition: Area2D = pair[0]
		_check(transition.is_connected("body_entered", Callable(transition, "_on_body_entered")), "Player entry signal connected")
		var destination: Dictionary = catalog.transitions[transition.transition_id].destination
		_check(destination.mapId == pair[1].map_id and destination.spawnMarker == str(pair[2].name), "Canonical server marker")
		# The saved local markers and authoritative server landings can occupy
		# adjacent clear tiles; verify both against the actual destination map.
		var server_position := Vector2(float(destination.position.x), float(destination.position.y))
		var return_exit: Area2D = exit_node if pair[1] == room else entrance
		_check(not return_exit.contains_world_position(server_position), "Server arrival avoids the return trigger")
	_check(LOADER.module_for_scene(SCENE) == LOADER.EXTENDED_MODULE_NAME, "Browser module includes Prize Corner")
	for pair: Array in [["Ground", 255], ["GroundDetail", 115], ["Objects", 27], ["ObjectsTop", 26]]:
		_check(room.get_node("Visual/" + pair[0]).get_used_cells().size() == pair[1], "Imported artist layer: " + pair[0])
	var errors: Array[String] = VALIDATOR.new().validate(room.get_node("Visual"), "res://generated/tiled_visuals/celadon_prize_corner/celadon_prize_corner.visual.tileset.tres")
	_check(errors.is_empty(), "Imported atlas layout: " + str(errors))
	# Use the real player movement predicate against the real scene collision.
	var player: Node2D = load("res://scenes/player.tscn").instantiate()
	var body: CollisionShape2D = player.get_node("DetectionShape")
	var body_size := (body.shape as RectangleShape2D).size
	var body_bounds := Rect2(Vector2(1424, 880) + body.position - body_size / 2.0, body_size)
	var trigger: CollisionShape2D = entrance.get_node("CollisionShape2D")
	var trigger_size := (trigger.shape as RectangleShape2D).size
	var trigger_bounds := Rect2(trigger.global_position - trigger_size / 2.0, trigger_size)
	_check(body_bounds.intersects(trigger_bounds), "Actual player body overlaps the city door trigger at (44,27)")
	room.get_node("Entities/Players").add_child(player)
	player.free()
	root.add_child(room)
	await process_frame
	var mask := room.get_node("FloorVisibilityMask")
	_check(mask.get_active_floor_region() == Rect2(0, 0, 480, 544) and mask.z_index == 4096, "Black mask fits the complete canvas")
	for child: Polygon2D in mask.get_children():
		_check(child.polygon.size() == 4 and child.color == Color.BLACK, "Mask polygon initialized")
	room.free()
	city.free()
	print("CELADON_PRIZE_CORNER ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
