extends SceneTree

var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var map = load("res://scenes/overworld/kanto/routes/kanto_route_10.tscn").instantiate()
	for side: String in ["North", "South"]:
		var guard = map.get_node("Entities/NPCs/RockTunnel%sGuard" % side)
		var exit = map.get_node("Exits/ToRockTunnel%s" % side)
		_check(guard.guard_role == "transition_guard", "%s guards a transition" % guard.name)
		_check(guard.call("_resolve_guarded_exit") == exit, "%s guards its own entrance" % guard.name)
		_check(guard.npc_id == "kanto_route_10_rock_tunnel_%s_guard" % side.to_lower(), "%s uses its server identity" % guard.name)
		_check(guard.blocked_dialogue_id == "kanto_route_10_rock_tunnel_oak_advice_required", "%s explains the Oak quest requirement" % guard.name)
		_check_rock_tunnel_presence(map, guard, exit.get_node("CollisionShape2D"))
	map.free()
	await _check_story_refresh()
	quit(1 if failed else 0)


func _check_rock_tunnel_presence(map: Node, guard: Node, exit_shape: CollisionShape2D) -> void:
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	_check(collision.get_cell_source_id(collision.local_to_map(guard.position)) == -1, "%s stands on walkable terrain" % guard.name)
	_check(guard.position != map.get_node("Spawns/FromRockTunnelNorth").position and guard.position != map.get_node("Spawns/FromRockTunnelSouth").position, "%s leaves return spawn tiles clear" % guard.name)
	guard.set("transition_access_resolved", true)
	guard.set("transition_access", {"allowed": false})
	guard.call("_sync_guard_presence")
	_check(guard.visible and bool(guard.call("guards_world_position", exit_shape.global_position)), "%s is visible and blocks denied entry" % guard.name)
	guard.set("transition_access", {"allowed": true})
	guard.call("_sync_guard_presence")
	_check(not guard.visible and not bool(guard.call("guards_world_position", exit_shape.global_position)), "%s disappears and opens authorized entry" % guard.name)
	_check(not bool(guard.call("blocks_world_position", guard.position)), "%s leaves no invisible collision" % guard.name)


func _check_story_refresh() -> void:
	var guard = load("res://scenes/npcs/gate_npc.tscn").instantiate()
	guard.set_script(load("res://tests/support/gate_refresh_stub.gd"))
	guard.guard_role = "transition_guard"
	guard.guarded_transition_id = "kanto_route_10__to_rock_tunnel_north"
	guard.requires_party_pokemon = false
	guard.next_access_allowed = true
	root.add_child(guard)
	await process_frame
	_check(guard.refresh_count == 1 and guard.last_force_refresh and not guard.visible, "loading a guard refreshes stale access before opening the passage")
	guard.refresh_count = 0
	guard.transition_access = {"allowed": false}
	guard.transition_access_resolved = true
	guard._sync_guard_presence()
	var story_service := root.get_node("StoryService")
	guard.next_access_allowed = true
	story_service.emit_signal("story_changed", 1)
	await process_frame
	_check(guard.refresh_count == 1 and guard.last_force_refresh, "Oak quest changes force a fresh server access check")
	_check(not guard.visible and guard.is_gate_open(), "starting the Rock Tunnel quest removes the guard")
	guard.next_access_allowed = false
	story_service.emit_signal("story_changed", 2)
	await process_frame
	_check(guard.visible and not guard.is_gate_open(), "rewinding the story restores the guard and closes the passage")
	guard.free()


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
		return
	failed = true
	push_error("FAIL " + label)
