extends SceneTree

var failed := false

class DoorProbe extends "res://scripts/world/map_exit.gd":
	var shown_error: Dictionary = {}
	func _show_transition_error(response: Dictionary = {}) -> void:
		shown_error = response

class PlayerStub extends Node2D:
	var route_gate_interaction_in_progress := false

class WorldStub extends Node:
	var is_in_battle := false
	var wild_battle_resume_pending := false
	var events: Array[String] = []
	var saved_position := Vector2.ZERO
	var player: Node2D
	var sync_succeeds := true
	var sync_error := "forced_teleport_pending"
	var locked_while_syncing := false
	var in_progress := false
	func sync_player_position_for_world_action() -> Dictionary:
		events.append("save")
		locked_while_syncing = get_node("/root/GameState").is_overworld_input_locked()
		await get_tree().process_frame
		if not sync_succeeds:
			return {"success": false, "status": 409, "detail": {"code": sync_error}}
		saved_position = player.position
		return {"success": true}
	func begin_authorized_teleport(_ignore_movement: bool) -> Dictionary:
		events.append("begin")
		in_progress = true
		return {"success": true}
	func apply_authorized_teleport_state(_state: Dictionary) -> Dictionary:
		events.append("apply")
		in_progress = false
		return {"success": true}
	func cancel_authorized_teleport() -> void:
		in_progress = false

class TransitionStub extends Node:
	var world: WorldStub
	var requests := 0
	func enter_transition(_id: String, _facing: String) -> Dictionary:
		world.events.append("enter")
		requests += 1
		return {"success": true, "allowed": true, "state": {"mapId": "fixture"}}

func _init() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _run() -> void:
	var original_service := root.get_node("WorldTransitionService")
	original_service.name = "OriginalWorldTransitionService"
	var service := TransitionStub.new()
	service.name = "WorldTransitionService"
	root.add_child(service)
	var world := WorldStub.new()
	root.add_child(world)
	service.world = world
	var player := PlayerStub.new()
	root.add_child(player)
	world.player = player
	var door := DoorProbe.new()
	root.add_child(door)
	var game_state := root.get_node("GameState")
	for transition: String in ["kanto_vermilion_city__to_guild_base", "guild_base_main_hall__to_left_room", "guild_base_main_hall__to_town"]:
		world.events.clear()
		world.saved_position = Vector2(1168, 624)  # Last autosave is still at the garden gate.
		player.position = Vector2(1680, 368)
		door.target_scene_path = "res://scenes/overworld/kanto/guild_base/main_hall.tscn" if transition.begins_with("kanto_") else "res://town.tscn"
		door.is_transitioning = true
		await door._enter_authorized_transition(player, world, transition, "up")
		_check(world.events == ["save", "begin", "enter", "apply"], "The door position is saved before teleport autosave is blocked: " + transition)
		_check(world.saved_position == player.position and world.locked_while_syncing, "Saving uses the current position while movement is locked")
		_check(not door.is_transitioning and not game_state.overworld_input_lock_owners.has(&"guild_base_door_position"), "Arrival releases the door and its input lock")

	world.events.clear()
	world.sync_succeeds = false
	door.is_transitioning = true
	var requests_before := service.requests
	await door._enter_authorized_transition(player, world, "guild_base_main_hall__to_town", "down")
	_check(world.events == ["save"] and service.requests == requests_before, "A failed position save never requests a room transition")
	_check(not door.is_transitioning and not world.in_progress and not game_state.overworld_input_lock_owners.has(&"guild_base_door_position"), "A failed save releases the door and movement lock")
	_check(int(door.shown_error.get("status", 0)) == 409, "A failed save presents the original error")
	world.events.clear()
	world.sync_error = "guild_base_access_denied"
	await door._enter_authorized_transition(player, world, "guild_base_main_hall__to_town", "down")
	_check(world.events == ["save", "begin", "enter", "apply"], "A removed member can still use the server-owned public exit")
	world.events.clear()
	door.target_scene_path = "res://scenes/overworld/kanto/guild_base/left_room.tscn"
	await door._enter_authorized_transition(player, world, "guild_base_main_hall__to_left_room", "down")
	_check(world.events == ["save"], "Lost membership never bypasses a private room save rejection")

	world.events.clear()
	door.target_scene_path = "res://ordinary_room.tscn"
	await door._enter_authorized_transition(player, world, "ordinary_map__to_room", "up")
	_check(world.events == ["begin", "enter", "apply"], "Ordinary map doors keep their existing request flow")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))
		for code: String in ["guild_base_door_required", "guild_base_access_denied", "guild_base_transition_required"]:
			_check(catalog.has(BackendErrorLocalizationService.CODE_TO_KEY[code]), "Guild Base errors have a translated explanation: " + locale + "/" + code)
	door.free()
	player.free()
	world.free()
	service.free()
	original_service.name = "WorldTransitionService"
	print("guild_base_door_sync_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)
