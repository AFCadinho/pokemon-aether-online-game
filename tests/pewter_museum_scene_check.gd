extends SceneTree

const MUSEUM := "res://scenes/overworld/kanto/towns/pewter_city/museum.tscn"
const CITY := "res://scenes/overworld/kanto/towns/pewter_city/pewter_city.tscn"
var failed := false

class GatePlayer:
	extends Node2D
	var route_gate_interaction_in_progress := true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await process_frame
	var museum: Node2D = load(MUSEUM).instantiate()
	var city: Node2D = load(CITY).instantiate()
	_check(museum.lighting_profile == "indoor" and museum.weather_profile == "disabled"
		and museum.music_profile_id == "kanto.pewter_city", "museum uses indoor lighting and Pewter music")
	var visual := museum.get_node("Visual")
	var metadata: Dictionary = visual.get_meta("tiled_visual_map")
	_check(metadata.width == 34 and metadata.height == 24
		and str(visual.get_meta("tiled_source_path")).ends_with("/Pewter Museum of Science.tmx"), "authored museum visual is used")
	var validator = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new()
	_check(validator.validate(visual, "res://generated/tiled_visuals/pewter_museum/pewter_museum.visual.tileset.tres").is_empty(), "museum compact atlas is valid")
	for path in ["Entities/Players", "Entities/NPCs", "Entities/Pokemon", "Entities/Interactables", "FloorVisibilityMask", "Tiles/Collision"]:
		_check(museum.has_node(path), "runtime node " + path)
	var museum_collision := museum.get_node("Tiles/Collision") as TileMapLayer
	var city_collision := city.find_map_tilemap_layer("Collision") as TileMapLayer
	var occupied := {}
	for npc in museum.get_node("Entities/NPCs").get_children():
		var tile := museum_collision.local_to_map(npc.position)
		_check(museum_collision.get_cell_source_id(tile) == -1, "museum NPC stands on clear floor " + npc.name)
		_check(not occupied.has(tile), "museum NPC positions do not overlap")
		occupied[tile] = true
		_check(not npc.npc_id.is_empty() and npc.npc_sprite_frames != null, "museum NPC has metadata and sprite " + npc.name)
	_check(occupied.size() == 4, "four museum dialogue NPCs are present")
	var attendant := city.get_node("Entities/NPCs/MuseumAttendantIris")
	_check(attendant.guarded_transition_id == "kanto_pewter_city__to_museum"
		and not attendant.is_gate_open() and not attendant.requires_party_pokemon, "admission is guarded on every visit")
	_check(attendant.guards_world_position(Vector2(1392, 368)), "attendant intercepts walking into museum")
	_check(not attendant.guards_world_position(Vector2(1392, 432)), "return arrival is outside the payment gate")
	_check(city_collision.get_cell_source_id(city_collision.local_to_map(attendant.position)) == -1, "attendant stands on clear floor")
	var cancelled = load("res://tests/fixtures/pewter_museum_cancelled_admission.gd").new()
	await cancelled._offer_admission()
	_check(cancelled.offered_fee == 100 and cancelled.pending_admission_state.is_empty(), "cancelling admission never starts paid travel")
	cancelled.free()
	var lock_probe = load("res://tests/fixtures/pewter_museum_admission_lock_probe.gd").new()
	var gate_player := GatePlayer.new()
	root.add_child(lock_probe)
	await lock_probe.on_route_gate_blocked(gate_player)
	_check(not lock_probe.legacy_lock_at_arrival and not gate_player.route_gate_interaction_in_progress,
		"guard releases conversation and route locks before changing maps")
	lock_probe.legacy_lock_at_arrival = true
	await lock_probe._start_manual_interaction(gate_player)
	_check(not lock_probe.legacy_lock_at_arrival and not lock_probe.is_interacting,
		"manual conversation releases its input lock before changing maps")
	lock_probe.free()
	gate_player.free()
	for entry in [[city, "ToMuseum", museum, MUSEUM, "FromPewterCity", Vector2(1392, 368), "up"],
		[museum, "ToPewterCity", city, CITY, "FromMuseum", Vector2(432, 720), "down"]]:
		var exit_node: Node = entry[0].get_node("Exits/" + entry[1])
		_check(exit_node.target_scene_path == entry[3] and exit_node.target_spawn_name == entry[4]
			and exit_node.transition_facing_direction == entry[6], "matching connection " + entry[1])
		_check(exit_node.contains_world_position(entry[5]), "exit covers door " + entry[1])
		_check(exit_node.is_connected("body_entered", Callable(exit_node, "_on_body_entered")), "exit signal connected " + entry[1])
		var spawn: Node2D = entry[2].get_node("Spawns/" + entry[4])
		var collision := museum_collision if entry[2] == museum else city_collision
		_check(collision.get_cell_source_id(collision.local_to_map(spawn.position)) == -1, "arrival is walkable " + entry[4])
		for target_exit in entry[2].get_node("Exits").get_children():
			if target_exit.has_method("contains_world_position"):
				_check(not target_exit.contains_world_position(spawn.position), "arrival avoids exit loop " + entry[4])
	_check(city_collision.get_cell_source_id(Vector2i(43, 11)) == -1, "Pewter museum doorway is clear")
	var reachable := _reachable_cells(museum_collision, Vector2i(13, 19), occupied)
	for cell in [Vector2i(12, 22), Vector2i(13, 22), Vector2i(8, 9), Vector2i(17, 11), Vector2i(22, 14), Vector2i(30, 10), Vector2i(20, 6)]:
		_check(reachable.has(cell), "museum aisle or exit reachable " + str(cell))
	for cell in [Vector2i(0, 0), Vector2i(3, 3), Vector2i(4, 9), Vector2i(12, 11), Vector2i(19, 9), Vector2i(25, 8), Vector2i(27, 15), Vector2i(10, 20)]:
		_check(museum_collision.get_cell_source_id(cell) != -1, "wall, exhibit or furniture blocked " + str(cell))
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	_check(catalog.areas[museum.map_id].scenePath == MUSEUM and catalog.areas[museum.map_id].areaType == "interior", "museum registered as playable interior")
	for entry in [["kanto_pewter_city__to_museum", museum.map_id, "FromPewterCity", Vector2(432, 624)],
		["kanto_pewter_city_museum__to_pewter_city", city.map_id, "FromMuseum", Vector2(1392, 432)]]:
		var transition: Dictionary = catalog.transitions.get(entry[0], {})
		_check(transition.get("destinationAreaId") == entry[1]
			and transition.get("destination", {}).get("spawnMarker") == entry[2]
			and transition.get("destination", {}).get("position") == {"x": entry[3].x, "y": entry[3].y}, "authorized transition " + entry[0])
	museum.free()
	city.free()
	print("PEWTER_MUSEUM ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _reachable_cells(collision: TileMapLayer, start: Vector2i, occupied: Dictionary) -> Dictionary:
	var visited := {start: true}
	var pending: Array[Vector2i] = [start]
	while not pending.is_empty():
		var cell: Vector2i = pending.pop_front()
		for direction in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var next: Vector2i = cell + direction
			if next.x < 0 or next.x >= 34 or next.y < 0 or next.y >= 24:
				continue
			if not visited.has(next) and not occupied.has(next) and collision.get_cell_source_id(next) == -1:
				visited[next] = true
				pending.append(next)
	return visited


func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
