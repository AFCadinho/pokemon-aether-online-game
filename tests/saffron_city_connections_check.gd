extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/saffron_city/saffron_city.tscn"
const GATE5 := "res://scenes/overworld/kanto/transition_buildings/route_5_saffron_gate.tscn"
const GATE6 := "res://scenes/overworld/kanto/transition_buildings/route_6_saffron_gate.tscn"
const ROUTE5 := "res://scenes/overworld/kanto/routes/kanto_route_5.tscn"
const ROUTE6 := "res://scenes/overworld/kanto/routes/kanto_route_6.tscn"
var failed := false
var maps: Dictionary = {}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for path in [CITY, GATE5, GATE6, ROUTE5, ROUTE6]:
		var packed := load(path) as PackedScene
		_expect(packed != null, "scene loads: " + path.get_file())
		if packed == null:
			quit(1)
			return
		var map := packed.instantiate()
		root.add_child(map)
		maps[path] = map
	var city: Node = maps[CITY]
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	var atlas_errors: Array = validator.validate(city.get_node("Visual"), "res://generated/tiled_visuals/saffron_city/saffron_city.visual.tileset.tres")
	_expect(atlas_errors.is_empty(), "Saffron import passes compact atlas validation")
	var ground := city.get_node("Visual/Ground") as TileMapLayer
	_expect(ground.get_used_rect() == Rect2i(0, 0, 96, 88), "Saffron uses the complete 96x88 city")
	_expect(ground.get_used_cells().size() == 8448, "all city ground tiles were imported")
	_expect(city.get_node("Visual").scene_file_path == "res://generated/tiled_visuals/saffron_city/saffron_city.visual.tscn", "city instances the current generated visual")
	var tree_bottom := city.get_node("Visual/TreeBottom") as TileMapLayer
	var tree_top := city.get_node("Visual/TreeTop") as TileMapLayer
	_expect(tree_bottom.get_used_cells().size() == 2248 and tree_top.get_used_cells().size() == 2248, "latest import contains all 562 complete tree sprites")
	var gate_border_complete := true
	for cell in [Vector2i(0, 34), Vector2i(4, 34), Vector2i(6, 35), Vector2i(88, 35), Vector2i(90, 34), Vector2i(95, 34), Vector2i(6, 43), Vector2i(88, 43)]:
		gate_border_complete = gate_border_complete and tree_bottom.get_cell_source_id(cell) != -1
	_expect(gate_border_complete, "updated tree bases close both side-gate borders")
	_expect(city.get_node("Visual/ObjectsTop") is TileMapLayer, "city includes upper building scenery")
	_expect(city.get_node("Spawns/FromRoute5").position == Vector2(1520, 176), "north arrival matches Tiled connection")
	_expect(city.get_node("Spawns/FromRoute6").position == Vector2(1584, 2672), "south arrival matches Tiled connection")
	for gate_path in [GATE5, GATE6]:
		var gate: Node = maps[gate_path]
		_expect(gate.lighting_profile == "indoor" and gate.weather_profile == "disabled", "gate uses indoor lighting and weather")
		var mask: Node = gate.get_node("FloorVisibilityMask")
		_expect(not mask.follow_player_floor, "gate inherits a fixed indoor visibility mask")
		for spawn in gate.get_node("Spawns").get_children():
			_expect(mask.floor_regions[&"ground_floor"].has_point(spawn.position), "gate arrival is inside its visible floor")
		var collision := gate.get_node("Collision") as TileMapLayer
		var corridor_clear := true
		for y in range(8, 19):
			corridor_clear = corridor_clear and collision.get_cell_source_id(Vector2i(10, y)) == -1
		_expect(corridor_clear, "gate has a clear vertical walking corridor")
		_expect(not gate.get_node("Entities/NPCs/GateNPC").requires_party_pokemon, "gate attendant does not block traversal")

	var legs := [
		[ROUTE5, "ToSaffronNorth", GATE5, "FromNorth", "down"],
		[GATE5, "ToSouth", CITY, "FromRoute5", "down"],
		[CITY, "ToRoute6Gate", GATE6, "FromNorth", "down"],
		[GATE6, "ToSouth", ROUTE6, "FromSaffronSouth", "down"],
		[ROUTE6, "ToSaffronSouth", GATE6, "FromSouth", "up"],
		[GATE6, "ToNorth", CITY, "FromRoute6", "up"],
		[CITY, "ToRoute5Gate", GATE5, "FromSouth", "up"],
		[GATE5, "ToNorth", ROUTE5, "FromSaffronNorth", "up"],
	]
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in legs:
		var source: Node = maps[leg[0]]
		var destination: Node = maps[leg[2]]
		var exit_node: Node = source.get_node("Exits/" + leg[1])
		_expect(exit_node.target_scene_path == leg[2] and exit_node.target_spawn_name == leg[3], "round-trip endpoint: " + exit_node.transition_id)
		_expect(exit_node.transition_facing_direction == leg[4], "arrival direction: " + exit_node.transition_id)
		_expect(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "exit trigger is connected")
		var arrival: Node2D = destination.get_node("Spawns/" + leg[3])
		var safe := true
		for target_exit in destination.get_node("Exits").get_children():
			# Include the body's center offset and radius, not only marker feet.
			for offset in [Vector2.ZERO, Vector2(0, -16), Vector2(0, 8)]:
				safe = safe and not target_exit.contains_world_position(arrival.global_position + offset)
		_expect(safe, "arrival does not retrigger an exit: " + leg[3])
		var entry: Dictionary = catalog.transitions.get(exit_node.transition_id, {})
		_expect(entry.get("destinationAreaId") == destination.map_id and entry.get("sourceMapId") == source.map_id, "catalog matches runtime transition")
	_expect(catalog.areas.has("kanto_saffron_city") and catalog.areas.has("kanto_route_6_saffron_gate"), "city and both gates are registered")
	for map in maps.values():
		map.queue_free()
	print("SAFFRON_CITY_CONNECTIONS ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _expect(ok: bool, label: String) -> void:
	if ok:
		print("PASS: ", label)
	else:
		failed = true
		push_error(label)
