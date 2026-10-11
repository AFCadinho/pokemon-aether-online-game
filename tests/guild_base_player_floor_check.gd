extends SceneTree

const TEMPLATE := "res://scenes/overworld/kanto/guild_base/player_floor.tscn"
const Builder := preload("res://tools/world_access_catalog_builder.gd")
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var first: Node2D = load(TEMPLATE).instantiate()
	var second: Node2D = load(TEMPLATE).instantiate()
	root.add_child(first)
	root.add_child(second)
	_check(first.room_key == "player_floor" and first.room_size == Vector2i(31, 15), "the runtime template matches the player-floor TMX")
	_check(first.get_node("Visual").get_child_count() == 7, "all seven authored layers are preserved")
	_check(first.get_node("Visual/DoorMats").position == Vector2(16, 0) and first.get_node("Visual/DoorMats").z_index < 2, "door mats keep their offset and render beneath players")
	_check(first.get_node("Visual/FrontWallVoid").position == Vector2(0, -8), "the front void keeps its authored offset")
	var collision := first.find_map_tilemap_layer("Collision") as TileMapLayer
	_check(collision.tile_set.get_physics_layers_count() == 1 and not collision.get_used_cells().is_empty(), "the template supplies physical collision")
	for tile: Vector2i in [Vector2i(3, 9), Vector2i(27, 9), Vector2i(6, 10), Vector2i(24, 10), Vector2i(15, 5), Vector2i(15, 11)]:
		_check(not first.is_walkable_tile(tile) and collision.get_cell_source_id(tile) != -1, "fixed scenery and walls block walking: " + str(tile))
	var start := Vector2i(first.get_node("Spawns/FromElevator").position / 32)
	for index in range(1, 5):
		var anchor: Marker2D = first.get_node("DoorAnchors/Room%d" % index)
		var spawn: Marker2D = first.get_node("Spawns/FromRoom%d" % index)
		_check(anchor.position.x == spawn.position.x, "room arrival aligns with door slot " + str(index))
		var point := Vector2i(spawn.position / 32)
		_check(collision.get_cell_source_id(point) == -1 and _reachable(first, start, point), "the lift connects to room slot " + str(index))
		_check(first.is_walkable_tile(Vector2i(anchor.position / 32)), "room slot has a clear door approach " + str(index))
	_check(first.get_node("DoorAnchors").get_child_count() == 5 and first.get_node("Spawns").get_child_count() == 5, "the floor exposes exactly four room slots and one lift connection")
	_check(first.get_node("FloorVisibilityMask").constrain_camera_to_active_floor, "the floor camera follows its mask")
	var other_collision := second.find_map_tilemap_layer("Collision") as TileMapLayer
	other_collision.set_cell(start, 0, Vector2i.ZERO)
	_check(collision.tile_set != other_collision.tile_set and collision.get_cell_source_id(start) == -1, "two instances keep independent runtime collision")
	var record := Builder.new()._load_scene_record(TEMPLATE, {})
	_check(first.get_map_id().is_empty() and not record.success and str(record.error).is_empty(), "unassigned floors stay outside the world-access catalog")
	_check(first.get_node("Exits").get_child_count() == 0 and first.furnishing_editor == null, "room ownership and travel await the floor allocation system")
	var cabin: Node = load("res://scenes/overworld/kanto/guild_base/elevator_cabin.tscn").instantiate()
	_check(cabin.get_node("Exits/ToElevator").target_scene_path.ends_with("guild_base/elevator.tscn"), "the lift still defaults to the ground-floor waiting room")
	cabin.free()
	first.free()
	second.free()
	await process_frame
	print("guild_base_player_floor_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _reachable(map: Node, start: Vector2i, destination: Vector2i) -> bool:
	var queue: Array[Vector2i] = [start]
	var seen := {start: true}
	var cursor := 0
	while cursor < queue.size():
		var point := queue[cursor]
		cursor += 1
		if point == destination:
			return true
		for direction: Vector2i in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next := point + direction
			if map.is_walkable_tile(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return false

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
