extends SceneTree
var failed := false
func _init() -> void:
	_run.call_deferred()
func _run() -> void:
	var route := (load("res://scenes/overworld/kanto/routes/kanto_route_18.tscn") as PackedScene).instantiate()
	var mine := (load("res://scenes/overworld/kanto/caves/route_18_mine/route_18_mine.tscn") as PackedScene).instantiate()
	var guard: Node = route.get_node("Entities/NPCs/MineForeman")
	var entrance: Area2D = route.get_node("Exits/ToUndergroundMine")
	_check(guard.npc_id == "kanto_route_18_mine_foreman_niels" and guard.guarded_transition_id == entrance.transition_id, "foreman handles the exact mine entry transition")
	_check(guard.guard_role == "attendant" and not guard.requires_party_pokemon and not guard.requires_staff_role, "foreman stays beside stairs and adds only the skill requirement")
	_check(guard.blocked_dialogue_id == "kanto_route_18_mine_guard_blocked" and guard.allowed_dialogue_id == "kanto_route_18_mine_guard_allowed", "both gate responses are localized")
	_check(guard.position.distance_to(entrance.position) <= 64 and route.find_map_tilemap_layer("Collision").get_cell_source_id(Vector2i(guard.position/32)) == -1, "foreman stands on clear ground beside entrance")
	var landing: Vector2 = route.get_node("Spawns/FromUndergroundMine").position
	_check(Vector2i(guard.position/32) != Vector2i(landing/32), "foreman never occupies return landing")
	_check(not guard.handles_world_transition(mine.get_node("Exits/ToRoute18").transition_id), "foreman does not guard leaving the mine")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/support/fuchsia_movement_probe.gd"))
	_check(not player.overlaps_exit_at(entrance,landing), "return landing avoids entry retrigger with authored shape offset")
	# Keep the saved scene's properties while exercising the real GateNPC
	# conversation and MapExit denial routing against deterministic responses.
	var properties := {}
	for property: Dictionary in guard.get_property_list():
		if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != "script":
			properties[property.name] = guard.get(property.name)
	guard.set_script(load("res://tests/fixtures/route18_mine_guard_probe.gd"))
	for key: String in properties: guard.set(key,properties[key])
	var state: Node = root.get_node("GameState")
	var previous: Node = state.current_map
	state.current_map = route
	route.encounter_area_id = ""
	root.add_child(route)
	# A simple body avoids visual/player startup; the real detection shape was
	# already used above to verify the actual arrival contact.
	var body := Node2D.new()
	root.add_child(body)
	body.position = landing
	await guard.show_gate_dialogue()
	_check(guard.spoken == ["kanto_route_18_mine_guard_blocked"] and not guard.is_gate_open(), "below-level conversation uses authoritative denial")
	guard.server_access = {"allowed":true,"dialogueId":""}
	await guard.show_gate_dialogue()
	_check(guard.refreshes == 2 and guard.is_gate_open() and guard.spoken.back() == "kanto_route_18_mine_guard_allowed", "conversation refreshes stale access and admits newly qualified players")
	await entrance.call("_present_denied_transition",entrance.transition_id,{"allowed":false,"reasonCode":"ROCK_SMASH_LEVEL_REQUIRED","dialogueId":"kanto_route_18_mine_guard_blocked"},body)
	_check(guard.spoken.back() == "kanto_route_18_mine_guard_blocked" and not guard.is_gate_open(), "direct stair attempt is explained by the bound NPC")
	_check(guard.visible and guard.guard_role == "attendant", "foreman remains beside entrance after admission changes")
	for actor in route.get_node("Entities/NPCs").get_children(): actor.set_process(false)
	player.map_layers_initialized = true
	player.map_layers_owner = route
	player.resolved_map_cache = route
	player.collision_tilemap = route.get_node("Tiles/Collision")
	player.water_tilemap = route.get_node("Tiles/Water")
	_check(player.can_move_to(landing) and player.can_move_to(landing+Vector2.LEFT*32), "denied admission never blocks return landing or westward escape")
	state.current_map = previous
	body.free()
	player.free()
	route.free()
	mine.free()
	if not failed: print("PASS Route 18 mine guard: placement, fresh admission dialogue, stair denial and free return")
	quit(1 if failed else 0)
func _check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
