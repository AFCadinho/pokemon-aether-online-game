extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const GATE := "res://scenes/overworld/kanto/transition_buildings/route_19_fuchsia_gate.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var gate := (load(GATE) as PackedScene).instantiate()
	root.add_child(city)
	root.add_child(gate)
	var template := (load("res://scenes/overworld/kanto/reusable_interiors/vertical_transition_building_template.tscn") as PackedScene).instantiate()
	_check(gate.get_node("Visuals").scene_file_path == template.get_node("Visuals").scene_file_path, "south gate uses the vertical interior")
	_check(gate.lighting_profile == "indoor" and gate.weather_profile == "disabled", "gate uses indoor lighting without weather")
	_check(gate.world_access_group_id == city.map_id, "gate belongs to Fuchsia on the town map")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[city,"ToRoute19Gate",gate,"FromNorth","down"],[gate,"ToNorth",city,"FromRoute19Gate","up"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "round-trip destination matches")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces into destination")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "exit signal is connected")
		var collision: TileMapLayer = leg[2].find_map_tilemap_layer("Collision")
		for target_exit in leg[2].get_node("Exits").get_children():
			for offset in [Vector2.ZERO,Vector2(0,-16),Vector2(0,8)]:
				_check(not target_exit.contains_world_position(arrival.position+offset), "arrival avoids immediate return")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "server catalog matches scene endpoints")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	gate.get_node("Entities/Players").add_child(player)
	player.refresh_map_layers()
	var state: Node = root.get_node("GameState")
	state.call("acquire_overworld_input_lock", &"route19_gate_test")
	_check(not player.call("_is_story_grid_step_blocked",Vector2(336,368),Vector2(336,336),Vector2.UP), "real player can step along the open aisle")
	var collision: TileMapLayer = gate.get_node("Collision")
	var guard: Node = gate.get_node("Entities/NPCs/GateNPC")
	_check(guard.visible and not guard.passage_closed, "attendant opens the completed Route 19 passage")
	var south: Area2D = gate.get_node("Exits/ToSouth")
	_check(south.monitoring and not south.get_node("CollisionShape2D").disabled, "Route 19 exit is enabled")
	_check(south.target_spawn_name == "FromFuchsiaGate", "south exit targets the route arrival")
	for spawn in gate.get_node("Spawns").get_children():
		_check(gate.get_node("FloorVisibilityMask").floor_regions[&"ground_floor"].has_point(spawn.position), "gate arrivals are inside the visible floor")
	var outgoing := 0
	for definition in catalog.transitions.values():
		if definition.sourceMapId == gate.map_id:
			outgoing += 1
			_check(definition.destinationAreaId in [city.map_id, "kanto_route_19"], "both gate destinations are authorized")
	_check(outgoing == 2, "gate has two working exits")
	player.reparent(city.get_node("Entities/Players"))
	player.refresh_map_layers()
	var city_exit: Area2D = city.get_node("Exits/ToRoute19Gate")
	_check(city_exit.position == Vector2(656,1552), "south exit keeps its authored position")
	_check(city_exit.get_node("CollisionShape2D").position == Vector2(16,16), "south trigger keeps its authored offset")
	_check(city_exit.get_node("CollisionShape2D").shape.size == Vector2(128,32), "south trigger keeps its four-tile width")
	_check(city.get_node("Spawns/FromRoute19Gate").position == Vector2(656,1520), "south return keeps its authored position")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.module_for_scene(GATE) == loader.EXTENDED_MODULE_NAME and loader.scene_for_map(gate.map_id) == GATE, "browser resolves the southern gate")
	state.call("release_overworld_input_lock", &"route19_gate_test")
	template.free()
	city.free()
	gate.free()
	print("ROUTE_19_FUCHSIA_GATE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
