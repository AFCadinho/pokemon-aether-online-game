extends SceneTree

const TELEPORT_OWNER := &"authorized_teleport"
var failed := false


class ErrorProbe extends Node:
	var shown := 0

	func show_response(_result: Dictionary, _fallback := "") -> void:
		shown += 1
		await get_tree().process_frame


class WorldProbe extends Node2D:
	var source_map: Node2D
	var begin_succeeds := true
	var apply_succeeds := true
	var changes_map := true
	var departing := false
	var allow_departure := false
	var arriving := false
	var allow_arrival := false
	var completed := false
	var cancelled := false

	func begin_authorized_teleport(ignore_movement := false, ignore_lock := false) -> Dictionary:
		assert(ignore_movement and ignore_lock)
		if not begin_succeeds:
			return {"success": false, "error": "World busy"}
		get_node("/root/GameState").acquire_overworld_input_lock(TELEPORT_OWNER)
		return {"success": true}

	func play_aethernet_departure_effect() -> void:
		departing = true
		while not allow_departure:
			await get_tree().process_frame

	func apply_authorized_teleport_state(_state: Dictionary) -> Dictionary:
		if changes_map:
			# Match World._clear_current_map: remove and free the source map
			# while the real Keeper is awaiting the teleport application.
			remove_child(source_map)
			source_map.queue_free()
			await get_tree().process_frame
			await get_tree().process_frame
		arriving = true
		while not allow_arrival:
			await get_tree().process_frame
		get_node("/root/GameState").release_overworld_input_lock(TELEPORT_OWNER)
		completed = true
		return {"success": apply_succeeds, "error": "Arrival rejected"}

	func cancel_aethernet_teleport_effect() -> void:
		get_node("/root/GameState").release_overworld_input_lock(TELEPORT_OWNER)
		cancelled = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var service := root.get_node("TransitService")
	var original_service_script: Script = service.get_script()
	service.set_script(load("res://tests/support/aethernet_transit_service_probe.gd"))
	for scenario: String in ["map_change", "same_map", "other_owner", "travel_rejected", "apply_rejected", "begin_rejected", "menu_cancelled"]:
		await _check_scenario(scenario, service)
	service.set_script(original_service_script)
	root.get_node("GameState").unlock_input()
	await process_frame
	print("aethernet_movement_lock_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _check_scenario(scenario: String, service: Node) -> void:
	var game_state := root.get_node("GameState")
	game_state.unlock_input()
	service.travel_succeeds = scenario != "travel_rejected"
	service.travel_requests = 0
	var world := WorldProbe.new()
	world.begin_succeeds = scenario != "begin_rejected"
	world.apply_succeeds = scenario != "apply_rejected"
	world.changes_map = scenario in ["map_change", "other_owner"]
	root.add_child(world)
	current_scene = world
	world.source_map = Node2D.new()
	world.add_child(world.source_map)
	var player := Node2D.new()
	world.add_child(player)
	var errors := ErrorProbe.new()
	world.add_child(errors)
	var keeper: Node2D = load("res://tests/support/aethernet_keeper_probe.gd").new()
	var look := Node2D.new()
	look.name = "Look"
	keeper.add_child(look)
	var sprite := AnimatedSprite2D.new()
	sprite.name = "AnimatedSprite2D"
	look.add_child(sprite)
	var feet := Marker2D.new()
	feet.name = "FeetMarker"
	keeper.add_child(feet)
	var area := Area2D.new()
	area.name = "InteractionArea"
	keeper.add_child(area)
	world.source_map.add_child(keeper)
	keeper.GameErrorDialogService = errors
	# Deliberately freeing the waiting Keeper in map-change scenarios can make
	# Godot report abandoned GDScriptFunctionState instances at process exit.
	# Keep the real BaseNPC caller so this covers the original lock leak.
	keeper._start_manual_interaction(player)
	for frame in 120:
		if world.get_child_count() > 3:
			break
		await process_frame
	var menu: Node
	for child: Node in world.get_children():
		if child is TransitMenu:
			menu = child
	_check(menu != null, scenario + ": real Keeper opens travel menu")
	if menu != null:
		_check(game_state.is_overworld_input_locked(), scenario + ": menu retains interaction lock")
		menu.call("_finish", "" if scenario == "menu_cancelled" else "kanto_pewter_city")
	if scenario not in ["begin_rejected", "menu_cancelled"]:
		_check(world.departing and game_state.is_overworld_input_locked(), scenario + ": departure stays locked")
		_check(not game_state.overworld_input_legacy_locked, scenario + ": interaction lock hands over to teleport")
		if scenario == "other_owner":
			game_state.acquire_overworld_input_lock(&"other_activity")
		world.allow_departure = true
		for frame in 120:
			if world.arriving or world.cancelled:
				break
			await process_frame
		_check(service.travel_requests == 1 and service.locked_during_request, scenario + ": server request stays locked")
		if scenario == "travel_rejected":
			_check(world.cancelled and not world.arriving, "rejected travel cancels its teleport")
		else:
			_check(world.arriving and game_state.is_overworld_input_locked(), scenario + ": arrival stays locked")
			if world.changes_map:
				_check(not is_instance_valid(keeper), "map change destroys source Keeper before arrival completes")
			world.allow_arrival = true
	else:
		_check(service.travel_requests == 0 and not world.departing, scenario + ": no travel starts")
	for frame in 5:
		await process_frame
	if scenario in ["map_change", "same_map", "other_owner", "apply_rejected"]:
		_check(world.completed, scenario + ": teleport application completes")
	if scenario == "other_owner":
		_check(game_state.is_overworld_input_locked() and game_state.overworld_input_lock_owners.has(&"other_activity") and not game_state.overworld_input_lock_owners.has(TELEPORT_OWNER), "teleport completion preserves another owner's scoped lock")
		game_state.release_overworld_input_lock(&"other_activity")
	_check(not game_state.is_overworld_input_locked() and game_state.overworld_input_lock_owners.is_empty(), scenario + ": movement unlocks at completion or cancellation")
	_check(errors.shown == (1 if scenario in ["begin_rejected", "travel_rejected", "apply_rejected"] else 0), scenario + ": expected error handling")
	current_scene = null
	world.queue_free()
	await process_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS ", description)
	else:
		failed = true
		push_error(description)
