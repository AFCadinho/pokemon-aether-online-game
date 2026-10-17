extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_7.tscn"
const GATE := "res://scenes/overworld/kanto/transition_buildings/route_7_saffron_gate.tscn"
const CITY := "res://scenes/overworld/kanto/towns/saffron_city/saffron_city.tscn"
const TEMPLATE := "res://scenes/overworld/kanto/reusable_interiors/horizontal_transition_building_template.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var maps := {}
	for path in [ROUTE, GATE, CITY, TEMPLATE]:
		maps[path] = (load(path) as PackedScene).instantiate()
	var gate: Node = maps[GATE]
	_check(gate.lighting_profile == "indoor" and gate.weather_profile == "disabled", "gate uses indoor lighting and weather")
	_check(gate.get_node("Visuals").scene_file_path == maps[TEMPLATE].get_node("Visuals").scene_file_path, "gate reuses the approved horizontal interior")
	_check(gate.get_node("Tiles/Collision").tile_map_data == maps[TEMPLATE].get_node("Tiles/Collision").tile_map_data, "gate inherits the tested indoor collision")
	var guard: Node = gate.get_node("Entities/NPCs/GateNPC")
	_check(guard.guard_role == "transition_guard" and guard.guarded_transition_id == "kanto_route_7_saffron_gate__to_saffron_city", "guard controls the Saffron entry")
	_check(not guard.requires_party_pokemon and guard.movement_behavior == "idle", "guard uses Saffron access rules and stays at the counter")
	guard.transition_access_resolved = true
	guard.transition_access = {"allowed": false}
	_check(not guard.call("is_gate_open"), "denied Saffron access keeps the guard closed")
	guard.transition_access = {"allowed": true}
	_check(guard.call("is_gate_open"), "allowed Saffron access opens the guard")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var legs := [
		[ROUTE, "ToSaffronGate", GATE, "FromWest", "right"],
		[GATE, "ToEast", CITY, "FromRoute7", "right"],
		[CITY, "ToRoute7Gate", GATE, "FromEast", "left"],
		[GATE, "ToWest", ROUTE, "FromSaffronGate", "left"]]
	for leg in legs:
		var source: Node = maps[leg[0]]
		var destination: Node = maps[leg[2]]
		var exit: Node = source.get_node("Exits/" + leg[1])
		_check(exit.target_scene_path == leg[2] and exit.target_spawn_name == leg[3] and exit.transition_facing_direction == leg[4], "destination and facing for " + exit.transition_id)
		_check(exit.is_connected("body_entered", Callable(exit, "_on_body_entered")), "trigger connected for " + exit.transition_id)
		var spawn: Vector2 = destination.get_node("Spawns/" + leg[3]).position
		var collision: TileMapLayer = destination.get_node("Tiles/Collision")
		_check(collision.get_cell_source_id(collision.local_to_map(spawn)) == -1, "arrival is walkable for " + leg[3])
		for target_exit in destination.get_node("Exits").get_children():
			for offset in [Vector2.ZERO, Vector2(0,-16), Vector2(8,0), Vector2(-8,0)]:
				_check(not target_exit.contains_world_position(spawn + offset), "arrival avoids immediate return for " + leg[3])
		var record: Dictionary = catalog.transitions.get(exit.transition_id, {})
		_check(record.get("sourceMapId") == source.map_id and record.get("destinationAreaId") == destination.map_id, "server catalog matches " + exit.transition_id)
		_check(record.get("destination", {}).get("position", {}) == {"x":spawn.x,"y":spawn.y}, "server and scene agree on arrival position")
	for entry in [[ROUTE,"ToSaffronGate",73,23,72], [CITY,"ToRoute7Gate",4,39,5]]:
		var map: Node = maps[entry[0]]
		var collision := map.get_node("Tiles/Collision") as TileMapLayer
		var exit: Node = map.get_node("Exits/" + entry[1])
		for y in range(entry[3],entry[3]+2):
			var cell := Vector2i(entry[2],y)
			_check(collision.get_cell_source_id(cell) == -1 and exit.contains_world_position(collision.map_to_local(cell)), "entire authored doorway is traversable and covered")
			_check(collision.get_cell_source_id(Vector2i(entry[4],y)) == -1, "door approach stays open")
		for y in [entry[3]-2,entry[3]-1,entry[3]+2]:
			var cell := Vector2i(entry[2],y)
			_check(collision.get_cell_source_id(cell) != -1 and not exit.contains_world_position(collision.map_to_local(cell)), "roof and door frame are solid without warp coverage")
	for x in range(3,17):
		for y in range(8,13):
			_check(gate.get_node("Tiles/Collision").get_cell_source_id(Vector2i(x,y)) == -1, "interior walking corridor remains clear")
	_check(gate.get_node("FloorVisibilityMask").floor_regions[&"ground_floor"].has_point(gate.get_node("Spawns/FromWest").position), "west arrival is visible")
	_check(gate.get_node("FloorVisibilityMask").floor_regions[&"ground_floor"].has_point(gate.get_node("Spawns/FromEast").position), "east arrival is visible")
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.module_for_scene(GATE) == loader.EXTENDED_MODULE_NAME, "browser loads the gate from the extended module")
	for map: Node in maps.values():
		map.free()
	print("ROUTE7_SAFFRON_GATE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
