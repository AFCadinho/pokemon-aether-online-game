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
	var collision: TileMapLayer = room.get_node("Tiles/Collision")
	var spawn: Marker2D = room.get_node("Spawns/FromOutside")
	var entrance: Area2D = city.get_node("Exits/ToPrizeCorner")
	var exit_node: Area2D = room.get_node("Exits/ToOutside")
	var city_spawn: Marker2D = city.get_node("Spawns/FromPrizeCorner")
	_check(room.map_id == MAP_ID and room.world_access_group_id == city.map_id, "Prize Corner shares Celadon access")
	_check(room.world_access_area_type == "interior" and room.lighting_profile == "indoor" and room.weather_profile == "disabled", "Indoor lighting and weather")
	var reached := _reachable(collision, Vector2i(15, 17), Vector2i(7, 12))
	_check(reached.has(Vector2i(spawn.position / 32.0)), "Saved arrival is on connected public floor")
	_check(reached.size() == 63, "All 63 public floor cells form one connected room")
	for tile: Vector2i in [Vector2i(4, 8), Vector2i(7, 8), Vector2i(10, 8), Vector2i(1, 9), Vector2i(13, 9), Vector2i(7, 14)]:
		_check(reached.has(tile), "Service approaches, side aisles and exit are reachable: " + str(tile))
	for tile: Vector2i in [Vector2i(4, 7), Vector2i(7, 7), Vector2i(10, 7), Vector2i(3, 10), Vector2i(11, 10), Vector2i(2, 6), Vector2i(12, 6)]:
		_check(collision.get_cell_source_id(tile) != -1, "Counter, statues and plants block their floor footprints: " + str(tile))
	for tile: Vector2i in [Vector2i(4, 6), Vector2i(7, 6), Vector2i(10, 6)]:
		_check(not reached.has(tile), "Public cannot enter staff space")
	for x in range(-1, 16):
		_check(collision.get_cell_source_id(Vector2i(x, -1)) != -1 and collision.get_cell_source_id(Vector2i(x, 17)) != -1, "North/south outer containment")
	for y in range(-1, 18):
		_check(collision.get_cell_source_id(Vector2i(-1, y)) != -1 and collision.get_cell_source_id(Vector2i(15, y)) != -1, "East/west outer containment")
	for x in 15:
		_check(collision.get_cell_source_id(Vector2i(x, 14)) != -1 or x == 7, "Cutaway front only opens at the single exit tile")
	_check(entrance.target_scene_path == SCENE and entrance.target_spawn_name == "FromOutside", "City door enters Prize Corner")
	_check(exit_node.target_scene_path == city.scene_file_path and exit_node.target_spawn_name == "FromPrizeCorner", "Return goes to the matching city door")
	_check(entrance.transition_facing_direction == "up" and exit_node.transition_facing_direction == "down", "Reciprocal arrival facing")
	_check(not entrance.contains_world_position(city_spawn.position) and not exit_node.contains_world_position(spawn.position), "No immediate return-trigger loop")
	_check(exit_node.contains_world_position(Vector2(240, 464)), "Exit trigger covers the single-tile threshold")
	_check(not exit_node.contains_world_position(Vector2(272, 464)), "Exit does not cover the adjacent blocked front tile")
	var city_reached := _reachable(city.get_node("Tiles/Collision"), Vector2i(80, 70), Vector2i(city.get_node("Spawns/FromRoute7").position / 32.0))
	_check(city_reached.has(Vector2i(44, 27)) and city_reached.has(Vector2i(44, 29)), "Door and return are reachable from Route 7")
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
		var target_collision: TileMapLayer = pair[1].get_node("Tiles/Collision")
		_check(target_collision.get_cell_source_id(target_collision.local_to_map(server_position)) == -1, "Server arrival remains walkable")
		_check(target_collision.get_cell_source_id(target_collision.local_to_map(pair[2].position)) == -1, "Saved marker remains walkable")
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
	for tile: Vector2i in reached:
		player.position = spawn.position
		_check(player.can_move_to(Vector2(tile * 32) + Vector2(16, 16)), "Player can use public floor: " + str(tile))
	for tile: Vector2i in [Vector2i(7, 7), Vector2i(3, 10), Vector2i(0, 12), Vector2i(6, 14), Vector2i(8, 14)]:
		_check(not player.can_move_to(Vector2(tile * 32) + Vector2(16, 16)), "Player cannot cross furnishings or the front boundary: " + str(tile))
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

func _reachable(collision: TileMapLayer, size: Vector2i, start: Vector2i) -> Dictionary:
	var queue: Array[Vector2i] = [start]
	var reached := {start: true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for offset: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next := tile + offset
			if not Rect2i(Vector2i.ZERO, size).has_point(next) or reached.has(next) or collision.get_cell_source_id(next) != -1:
				continue
			reached[next] = true
			queue.append(next)
	return reached

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
