extends SceneTree

const ROUTE := "res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn"
const GATE := "res://scenes/overworld/kanto/transition_buildings/route_16_gate.tscn"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var route := (load(ROUTE) as PackedScene).instantiate()
	var gate := (load(GATE) as PackedScene).instantiate()
	var template := (load("res://scenes/overworld/kanto/reusable_interiors/horizontal_transition_building_template.tscn") as PackedScene).instantiate()
	_check(gate.get_node("Visuals").scene_file_path == template.get_node("Visuals").scene_file_path, "approved horizontal interior")
	_check(gate.lighting_profile == "indoor" and gate.weather_profile == "disabled", "indoor lighting without weather")
	_check(gate.world_access_group_id == route.map_id, "gate belongs to Route 16 East")
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	# Inspect all endpoints off-tree, with the real player shape and authored layers.
	for leg in [[route,"ToRoute16Gate",gate,"FromEast","left"],[gate,"ToEast",route,"FromRoute16Gate","right"]]:
		var exit_node: Node = leg[0].get_node("Exits/" + leg[1])
		var arrival: Marker2D = leg[2].get_node("Spawns/" + leg[3])
		_check(exit_node.target_scene_path == leg[2].scene_file_path and exit_node.target_spawn_name == leg[3], "round-trip target and spawn")
		_check(exit_node.transition_facing_direction == leg[4], "arrival faces into destination")
		_check(exit_node.is_connected("body_entered",Callable(exit_node,"_on_body_entered")), "exit signal connected")
		var collision: TileMapLayer = leg[2].find_map_tilemap_layer("Collision")
		_check(collision.get_cell_source_id(collision.local_to_map(arrival.position)) == -1, "arrival has free ground")
		for other in leg[2].get_node("Exits").get_children():
			_check(not player.overlaps_exit_at(other,arrival.position), "actual player shape avoids return trigger")
		var entry: Dictionary = catalog.transitions[exit_node.transition_id]
		_check(entry.sourceMapId == leg[0].map_id and entry.destinationAreaId == leg[2].map_id, "catalog endpoint matches")
		_check(entry.destination.position == {"x":arrival.position.x,"y":arrival.position.y}, "server arrival position matches")
	for y in range(29,31):
		var point := Vector2(208,y*32+16)
		_check(route.get_node("Tiles/Collision").get_cell_source_id(Vector2i(6,y)) == -1, "gate entrance stays walkable")
		_check(player.overlaps_exit_at(route.get_node("Exits/ToRoute16Gate"),point), "entire external door aperture transfers")
	var collision: TileMapLayer = gate.get_node("Tiles/Collision")
	for cell in template.get_node("Tiles/Collision").get_used_cells():
		_check(collision.get_cell_source_id(cell) != -1, "existing template blocking preserved")
	var guard: Node = gate.get_node("Entities/NPCs/GateNPC")
	guard.feet_marker = guard.get_node("FeetMarker")
	_check(guard.passage_closed and not guard.requires_party_pokemon and guard.blocked_dialogue_id == "area_closed_blocked", "pending Route 16 passage closed with registered dialogue")
	for y in range(8,13):
		_check(collision.get_cell_source_id(Vector2i(2,y)) != -1, "static cap covers full west throat")
		_check(guard.guards_world_position(Vector2(176,y*32+16)), "guard covers full west throat")
		_check(player.overlaps_exit_at(gate.get_node("Exits/ToEast"),Vector2(560,y*32+16)), "full east aperture transfers")
	var west: Area2D = gate.get_node("Exits/ToWest")
	_check(not west.monitoring and west.get_node("CollisionShape2D").disabled and west.target_scene_path.is_empty(), "missing Route 16 never loads")
	var outgoing := 0
	for entry: Dictionary in catalog.transitions.values():
		if entry.sourceMapId == gate.map_id: outgoing += 1
	_check(outgoing == 1, "only implemented return registered")
	# Real movement uses these authored layers, including the permanent west cap.
	gate.add_child(player)
	player.map_layers_initialized = true
	player.map_layers_owner = gate
	player.resolved_map_cache = gate
	player.collision_tilemap = collision
	for y in range(8,13):
		_check(not player.can_move_to(Vector2(80,y*32+16)), "real movement cannot cross cap")
		_check(player.call("_is_story_grid_step_blocked",Vector2(208,y*32+16),Vector2(176,y*32+16),Vector2.LEFT), "real movement respects closed guard across aisle")
	for spawn in gate.get_node("Spawns").get_children():
		_check(player.can_move_to(spawn.position) and not guard.guards_world_position(spawn.position), "all gate arrivals are free")
		_check(gate.get_node("FloorVisibilityMask").floor_regions[&"ground_floor"].has_point(spawn.position), "arrivals inside visible room")
	player.free()
	template.free()
	route.free()
	gate.free()
	if not failed: print("PASS Route 16 gate: paired transitions, full door coverage, safe arrivals and closed pending west passage")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
