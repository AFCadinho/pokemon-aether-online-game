extends SceneTree

const CITY := "res://scenes/overworld/kanto/towns/fuchsia_city/fuchsia_city.tscn"
const GATE := "res://scenes/overworld/kanto/transition_buildings/safari_zone_gate.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var city := (load(CITY) as PackedScene).instantiate()
	var gate := (load(GATE) as PackedScene).instantiate()
	root.add_child(city)
	root.add_child(gate)
	var template := (load("res://scenes/overworld/kanto/reusable_interiors/vertical_transition_building_template.tscn") as PackedScene).instantiate()
	_check(gate.get_node("Visuals").scene_file_path == template.get_node("Visuals").scene_file_path, "gate inherits the vertical interior")
	_check(gate.lighting_profile == "indoor" and gate.weather_profile == "disabled", "gate uses indoor lighting without weather")
	_check(gate.world_access_group_id == city.map_id, "gate belongs to Fuchsia on the town map")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	for leg in [[city,"ToSafariZoneGate",gate,"FromSouth","up"],[gate,"ToSouth",city,"FromSafariZoneGate","down"]]:
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
	var game_state: Node = root.get_node("GameState")
	game_state.call("acquire_overworld_input_lock", &"safari_gate_test")
	_check(not player.call("_is_story_grid_step_blocked",Vector2(336,368),Vector2(336,336),Vector2.UP), "real player can step along the open aisle")
	var collision: TileMapLayer = gate.get_node("Collision")
	var guard: Node = gate.get_node("Entities/NPCs/GateNPC")
	_check(guard.visible and guard.passage_closed and not guard.requires_party_pokemon, "visible attendant closes the pending passage independently of party state")
	_check(guard.npc_definition_id == "kanto_fuchsia_safari_zone_gate_attendant" and guard.blocked_dialogue_id == "area_closed_blocked", "attendant uses registered closed-area dialogue")
	for x in range(8,13):
		var closed_tile := Vector2(x,7)*32+Vector2(16,16)
		_check(guard.guards_world_position(closed_tile), "guard covers the entire northern throat")
		_check(player.call("_is_story_grid_step_blocked",closed_tile+Vector2(0,32),closed_tile,Vector2.UP), "real player cannot bypass the attendant")
	var north: Area2D = gate.get_node("Exits/ToNorth")
	_check(not north.monitoring and north.get_node("CollisionShape2D").disabled and north.target_scene_path.is_empty(), "pending Safari exit is disabled")
	var outgoing := 0
	for definition in catalog.transitions.values():
		if definition.sourceMapId == gate.map_id:
			outgoing += 1
			_check(definition.destinationAreaId == city.map_id, "only the Fuchsia return is authorized")
	_check(outgoing == 1, "no transition targets the missing Safari map")
	var mask: Node = gate.get_node("FloorVisibilityMask")
	_check(mask.floor_regions[&"ground_floor"].has_point(gate.get_node("Spawns/FromSouth").position), "arrival is inside the visible floor")
	var city_exit: Area2D = city.get_node("Exits/ToSafariZoneGate")
	_check(city_exit.position == Vector2(1200,176), "Safari exit keeps its authored position")
	_check(city_exit.get_node("CollisionShape2D").position == Vector2(-16,-16), "Safari trigger keeps its authored offset")
	_check(city_exit.get_node("CollisionShape2D").shape.size == Vector2(128,32), "Safari trigger spans four tiles")
	_check(city.get_node("Spawns/FromSafariZoneGate").position == Vector2(1200,208), "Safari return keeps its authored position")
	player.reparent(city.get_node("Entities/Players"))
	player.refresh_map_layers()
	var loader = load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.module_for_scene(GATE) == loader.EXTENDED_MODULE_NAME and loader.scene_for_map(gate.map_id) == GATE, "browser resolves the gate scene")
	game_state.call("release_overworld_input_lock", &"safari_gate_test")
	template.free()
	city.free()
	gate.free()
	print("SAFARI_ZONE_GATE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)
