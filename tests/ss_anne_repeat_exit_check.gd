extends SceneTree

const MAP_PATH := "res://scenes/overworld/kanto/towns/ss_anne/ss_anne_1f.tscn"
var failed := false


class PlayerStub extends Node2D:
	var route_gate_interaction_in_progress := false
	var last_direction := Vector2.DOWN


class TransitionServiceStub extends Node:
	var arrivals: Dictionary = {}
	var requests := 0

	func enter_transition(transition_id: String, _facing: String) -> Dictionary:
		requests += 1
		await get_tree().process_frame
		return {"success": true, "allowed": true, "state": arrivals[transition_id]}


class WorldStub extends Node:
	var is_in_battle := false
	var wild_battle_resume_pending := false
	var in_progress := false
	var applied := 0
	var player: Node2D

	func load_map(_path: String, _spawn: String) -> void:
		push_error("Same-map doors should use authorized positioning.")

	func is_map_transition_in_progress() -> bool:
		return in_progress

	func begin_authorized_teleport(_lock: bool) -> Dictionary:
		in_progress = true
		return {"success": true}

	func apply_authorized_teleport_state(state: Dictionary) -> Dictionary:
		await get_tree().process_frame
		player.global_position = state["position"]
		applied += 1
		in_progress = false
		return {"success": true}

	func cancel_authorized_teleport() -> void:
		in_progress = false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Keep the same scene and actual MapExit instances for every round trip.
	# Only the server authorization and World positioning are replaced.
	var map: Node = load(MAP_PATH).instantiate()
	var game_state := root.get_node("GameState")
	var previous_map: Node = game_state.current_map
	game_state.current_map = map
	var original_service := root.get_node("WorldTransitionService")
	original_service.name = "OriginalWorldTransitionService"
	var service := TransitionServiceStub.new()
	service.name = "WorldTransitionService"
	root.add_child(service)
	var world := WorldStub.new()
	world.add_to_group("world")
	root.add_child(world)
	var player := PlayerStub.new()
	player.name = "Player"
	root.add_child(player)
	world.player = player
	var exits: Node = map.get_node("Exits")
	map.remove_child(exits)
	exits.owner = null
	for door: Node in exits.get_children():
		door.owner = null
		# Physics and animated editor hints are unnecessary for this guard test.
		for child: Node in door.get_children():
			child.free()
		if door.target_scene_path == MAP_PATH:
			var spawn: Node2D = map.get_node("Spawns/" + door.target_spawn_name)
			service.arrivals[door.transition_id] = {"position": spawn.position}
	root.add_child(exits)

	var pairs: Array[Array] = []
	for cabin in range(1, 8):
		pairs.append([
			exits.get_node("1F_Corridor__cabin_%02d" % cabin),
			exits.get_node("1F_Cabin_%02d__return_to_corridor" % cabin),
		])
	pairs.append([exits.get_node("1F_Corridor__galley_door"), exits.get_node("Kitchen__return_to_1f")])
	for pair: Array in pairs:
		for visit in range(3):
			for door: Node in pair:
				await _use_door(door, player, service, world, visit)
	_check(service.requests == 48 and world.applied == 48,
		"all seven cabins and the kitchen support three complete round trips")
	_check(game_state.current_map == map, "round trips preserve the existing map")

	exits.free()
	player.free()
	world.free()
	service.free()
	original_service.name = "WorldTransitionService"
	game_state.current_map = previous_map
	map.free()
	if not failed:
		print("SS_ANNE_REPEAT_EXIT PASS: 8 rooms, 3 round trips each, duplicate entries suppressed")
	quit(1 if failed else 0)


func _use_door(door: Node, player: Node2D, service: Node, world: Node, visit: int) -> void:
	var before_requests: int = service.requests
	var before_applied: int = world.applied
	door.call("_on_body_entered", player)
	_check(door.is_transitioning, "%s visit %d starts a transition" % [door.name, visit + 1])
	# Both the overlap signal and player's step fallback may report the door.
	door.call("_on_body_entered", player)
	for frame in range(12):
		await process_frame
		if not door.is_transitioning:
			break
	_check(service.requests == before_requests + 1 and world.applied == before_applied + 1,
		"%s completes exactly one authorized arrival" % door.name)
	_check(not door.is_transitioning, "%s can be used again after arrival" % door.name)
	_check(player.global_position == service.arrivals[door.transition_id]["position"],
		"%s reaches its configured spawn" % door.name)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
