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
	var start := Vector2i(first.get_node("Spawns/FromElevator").position / 32)
	for index in range(1, 5):
		var anchor: Marker2D = first.get_node("DoorAnchors/Room%d" % index)
		var spawn: Marker2D = first.get_node("Spawns/FromRoom%d" % index)
		_check(anchor.position.x == spawn.position.x, "room arrival aligns with door slot " + str(index))
	_check(first.get_node("DoorAnchors").get_child_count() == 5 and first.get_node("Spawns").get_child_count() == 5, "the floor exposes exactly four room slots and one lift connection")
	_check(first.get_node("FloorVisibilityMask").constrain_camera_to_active_floor, "the floor camera follows its mask")
	var other_collision := second.find_map_tilemap_layer("Collision") as TileMapLayer
	var original_start := collision.get_cell_source_id(start)
	other_collision.set_cell(start, 0, Vector2i.ZERO)
	_check(collision.tile_set != other_collision.tile_set and collision.get_cell_source_id(start) == original_start, "two instances keep independent runtime collision")
	var record := Builder.new()._load_scene_record(TEMPLATE, {})
	_check(first.get_map_id() == "guild_base_player_floor" and record.success, "the shared floor template is registered for authorized instance travel")
	_check(first.get_node("Exits").get_child_count() == 5 and first.furnishing_editor == null, "all four room doors and the lift use server-authorized travel")
	var cabin: Node = load("res://scenes/overworld/kanto/guild_base/elevator_cabin.tscn").instantiate()
	_check(cabin.get_node("Exits/ToElevator").target_scene_path.ends_with("guild_base/elevator.tscn"), "the lift still defaults to the ground-floor waiting room")
	cabin.free()
	first.free()
	second.free()
	await process_frame
	print("guild_base_player_floor_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
