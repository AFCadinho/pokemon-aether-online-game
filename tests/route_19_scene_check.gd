extends SceneTree

var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var route := (load("res://scenes/overworld/kanto/routes/kanto_route_19.tscn") as PackedScene).instantiate()
	var gate := (load("res://scenes/overworld/kanto/transition_buildings/route_19_fuchsia_gate.tscn") as PackedScene).instantiate()
	root.add_child(route)
	root.add_child(gate)
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	route.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	var state: Node = root.get_node("GameState")
	state.call("acquire_overworld_input_lock", &"route19_test")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[route,"ToFuchsiaGate",gate,"FromSouth"],[gate,"ToSouth",route,"FromFuchsiaGate"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "paired scene destination")
		_check(not leg[2].get_node("Exits").get_child(0).contains_world_position(arrival.position), "arrival avoids return trigger")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "paired server destination")
	for y in range(8,40):
		_check(player.can_move_to(Vector2(560,y*32+16)), "gate stair avenue reaches the beach")
	for x in range(16,19):
		_check(player.can_move_to(Vector2(x*32+16,240)), "full gate opening is walkable")
		_check(route.get_node("Exits/ToFuchsiaGate").contains_world_position(Vector2(x*32+16,240)), "full gate opening detects exits")
	_check(route.is_water_tile_for_actor(Vector2(25*32+16,60*32+16),player), "sea is water")
	_check(not player.can_move_to(Vector2(25*32+16,60*32+16)), "sea blocks walking")
	var collision: TileMapLayer = route.find_map_tilemap_layer("Collision")
	for y in range(72):
		for x in [0,47]:
			_check(collision.get_cell_source_id(Vector2i(x,y)) != -1, "east/west perimeter contains Surf")
	for x in range(48):
		for y in [0,71]:
			_check(collision.get_cell_source_id(Vector2i(x,y)) != -1, "north/south perimeter contains Surf")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.scene_for_map(route.map_id) == route.scene_file_path, "browser resolves Route 19")
	state.call("release_overworld_input_lock", &"route19_test")
	route.free()
	gate.free()
	print("ROUTE_19_SCENE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
