extends SceneTree

const CABIN := "res://scenes/overworld/kanto/towns/celadon_city/rocket_hideout_elevator.tscn"
const PREFIX := "kanto_rocket_hideout_elevator"
var failed := false

class WorldProbe extends Node2D:
	var cabin: Node
	var player: Node2D
	var driver: Node
	var is_in_battle := false
	var wild_battle_resume_pending := false
	var applied := 0
	var cancelled := 0
	var begin_was_locked := false

	func load_map(_path := "", _spawn := "") -> void:
		pass

	func is_map_transition_in_progress() -> bool:
		return false

	func begin_authorized_teleport(_ignore_movement := false) -> Dictionary:
		var game := get_node("/root/GameState")
		begin_was_locked = game.is_overworld_input_locked()
		if begin_was_locked:
			return {"success": false, "error": "Another system owns input"}
		game.acquire_overworld_input_lock(&"elevator_test_teleport")
		return {"success": true}

	func apply_authorized_teleport_state(state: Dictionary) -> Dictionary:
		driver._configure_authorized_map_instance(cabin, state)
		player.teleport_within_current_map(Vector2(state.position.x, state.position.y), Vector2.UP)
		await get_tree().process_frame
		applied += 1
		get_node("/root/GameState").release_overworld_input_lock(&"elevator_test_teleport")
		return {"success": true}

	func cancel_authorized_teleport() -> void:
		cancelled += 1
		get_node("/root/GameState").release_overworld_input_lock(&"elevator_test_teleport")

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 120
	var game := root.get_node("GameState")
	game.unlock_input()
	root.get_node("LocalizationManager").set_locale("en")
	var service := root.get_node("WorldTransitionService")
	var original_service: Script = service.get_script()
	service.set_script(load("res://tests/support/rocket_elevator_transition_probe.gd"))
	var errors := root.get_node("GameErrorDialogService")
	var original_errors: Script = errors.get_script()
	errors.set_script(load("res://tests/support/rocket_elevator_error_probe.gd"))
	var world := WorldProbe.new()
	world.driver = load("res://scripts/world/world.gd").new()
	root.add_child(world)
	current_scene = world
	world.cabin = load(CABIN).instantiate()
	world.add_child(world.cabin)
	game.current_map = world.cabin
	world.player = load("res://scenes/player.tscn").instantiate()
	world.player.set_script(load("res://tests/fixtures/spin_tile_player.gd"))
	world.cabin.get_node("Entities/Players").add_child(world.player)
	world.player.teleport_within_current_map(Vector2(112,176), Vector2.UP)
	var panel := world.cabin.get_node("Entities/Interactables/Panel")
	_check(panel.destination_floors == PackedStringArray(["B1F", "B2F", "B4F"]), "The saved cabin retains all three floor labels")
	var default_panel: Node = load("res://scripts/world/interactables/rocket_hideout_lift.gd").new()
	_check(default_panel.destination_floors == panel.destination_floors, "The panel defaults retain the floor labels after an editor property reset")
	default_panel.free()
	var collision := world.cabin.get_node("Tiles/Collision") as TileMapLayer
	var atlas_errors: Array[String] = load("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(world.cabin.get_node("Visual"), "res://generated/tiled_visuals/rocket_hideout_elevator/rocket_hideout_elevator.visual.tileset.tres")
	_check(atlas_errors.is_empty(), "The supplied cabin visual has a valid imported atlas")
	var loader := load("res://scripts/services/web_asset_module_service.gd")
	_check(loader.module_for_scene(CABIN) == loader.EXTENDED_MODULE_NAME, "The shared cabin belongs to the browser's extended map pack")
	var walkable := 0
	# Check the playable cabin and its immediate perimeter. Unreachable cells
	# outside the authored walls need not be painted as collision markers.
	for y in range(4,9):
		for x in range(2,9):
			var expected := (x >= 3 and x <= 7 and y >= 5 and y <= 7) or Vector2i(x,y) == Vector2i(5,8)
			_check((collision.get_cell_source_id(Vector2i(x,y)) == -1) == expected, "Cabin footprint at %s" % Vector2i(x,y))
			if expected:
				walkable += 1
	_check(walkable == 16 and world.player.can_move_to(Vector2(144,176)), "Real Player can approach the panel over the cabin floor")
	_check(collision.get_cell_source_id(Vector2i(5,9)) >= 0, "The doorway has a blocked back edge")
	_check(not world.player.can_move_to(Vector2(112,144)), "The panel wall blocks the real Player")
	_check(panel._is_player_facing_interactable(world.player), "The panel can be used facing its supplied control artwork")
	for floor: String in ["b1f", "b2f", "b4f"]:
		world.driver._configure_authorized_map_instance(world.cabin, {"mapId": PREFIX + ":7:" + floor})
		await process_frame
		for candidate: String in ["b1f", "b2f", "b4f"]:
			var exit := world.cabin.get_node("Exits/To" + candidate.to_upper())
			_check(exit.get_node("CollisionShape2D").disabled == (candidate != floor), "Only the current floor's physical exit is enabled")
			var hint := exit.get_node("DoorTransitionHint") as Node2D
			_check(hint.visible == (candidate == floor), "Only the current floor's exit hint is shown")
			_check(hint.global_position == Vector2(176,240) and hint.get_flow_vector() == Vector2.DOWN, "The cabin hint points out from clear interior floor")
		if floor == "b1f":
			await physics_frame
			await physics_frame
			Input.action_press("interact")
			await process_frame
			Input.action_release("interact")
		else:
			panel._start_manual_interaction(world.player)
		await process_frame
		_check(world.get_node_or_null("RocketHideoutLiftMenu") != null, "Physical input opens the panel at its painted position")
		if world.get_node_or_null("RocketHideoutLiftMenu") == null:
			quit(1)
			return
		var dialog := world.get_node("RocketHideoutLiftMenu").get_child(0) as AetherConfirmationDialog
		var choices := dialog.find_child("Floors",true,false) as OptionButton
		_check(choices.item_count == 3, "The shared cabin offers all served floors")
		for index in choices.item_count:
			_check(choices.is_item_disabled(index) == (["b1f","b2f","b4f"][index] == floor), "The current floor is labeled and disabled")
			if choices.is_item_disabled(index):
				_check(choices.get_item_text(index) == floor.to_upper() + " (current floor)", "Current-floor labels interpolate the trusted floor")
		_check(game.is_overworld_input_locked(), "The menu owns player input")
		dialog.canceled.emit()
		await process_frame
		await process_frame
		_check(not game.is_overworld_input_locked() and service.requests.is_empty(), "Cancel stays on the source floor and releases input")

	world.driver._configure_authorized_map_instance(world.cabin, {"mapId": PREFIX + ":7:b1f"})
	service.response = {"success": true, "allowed": true, "state": {"mapId": PREFIX + ":7:b4f", "mapScenePath": CABIN, "position": {"x":112,"y":176}, "spawnMarker":"FromPanel"}}
	await _select(world, panel, 2)
	_check(service.requests == [PREFIX + "__ride_to_b4f"] and world.applied == 1, "Selection executes the real ride MapExit and authorized state handoff")
	_check(not world.begin_was_locked, "The ride animation hands input to World without blocking teleport admission")
	_check(world.cabin.current_floor == "b4f" and world.cabin.map_id == PREFIX + ":7:b4f", "The normal World configuration hook applies the server-selected instance")
	_check(world.player.global_position == Vector2(112,176), "Arrival stays safely at the panel")
	_check(not game.is_overworld_input_locked() and not world.cabin.get_node("Doors").visible, "Ride success opens the doors and restores control")
	_check(world.cabin.get_node("Exits/ToB4F/DoorTransitionHint").visible, "A successful ride restores the selected exit hint")

	service.response = {"success": false, "error": "Fixture destination closed"}
	await _select(world, panel, 0)
	_check(world.cancelled == 1 and errors.shown == 1, "Rejected travel uses normal World cancellation and error feedback")
	_check(world.cabin.current_floor == "b4f" and not game.is_overworld_input_locked(), "Rejected travel preserves the floor and releases all owned locks")
	_check(world.cabin.get_node("Exits/ToB4F/DoorTransitionHint").visible, "Rejected travel restores the existing floor's hint")

	panel._start_manual_interaction(world.player)
	await process_frame
	game.acquire_overworld_input_lock(&"elevator_test_other")
	var dialog := world.get_node("RocketHideoutLiftMenu").get_child(0) as AetherConfirmationDialog
	dialog.canceled.emit()
	await process_frame
	_check(game.overworld_input_lock_owners.has(&"elevator_test_other"), "Closing the panel retains another system's lock")
	game.release_overworld_input_lock(&"elevator_test_other")
	for floor in ["b1f","b2f","b4f"]:
		var map: Node2D = load(CABIN.get_base_dir() + "/rocket_hideout_" + floor + ".tscn").instantiate()
		var exit := map.get_node("Exits/ToElevator")
		var grid := map.get_node("Tiles/Collision") as TileMapLayer
		var hint := exit.get_node("DoorTransitionHint") as Node2D
		_check(hint.position == Vector2(0,32) and hint.global_position == map.get_node("Spawns/FromLift").global_position, "%s lift hint sits on the clear approach floor instead of underneath the door artwork" % floor)
		_check(grid.get_cell_source_id(Vector2i(hint.global_position / 32.0)) < 0 and hint.get_flow_vector() == Vector2.UP, "%s lift hint points into the door from walkable floor" % floor)
		for offset in [-1,0,1]:
			_check(grid.get_cell_source_id(Vector2i(exit.position / 32.0) + Vector2i(offset,0)) == -1, "The full %s lift doorway is walkable" % floor)
		_check(not exit.contains_world_position(map.get_node("Spawns/FromLift").position), "%s arrival avoids immediate cabin reentry" % floor)
		_check(exit.target_scene_path == CABIN and map.get_node_or_null("Entities/Interactables/Lift") == null, "%s enters the shared cabin rather than a floor menu" % floor)
		map.free()
	for locale in ["en","nl","pt_BR","zh_CN"]:
		var strings: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/" + locale + ".json"))
		for suffix in ["title","prompt","current_floor"]:
			_check(strings.has("ui.rocket_hideout.lift." + suffix), "%s localizes the %s lift label" % [locale,suffix])
	panel._start_manual_interaction(world.player)
	await process_frame
	world.remove_child(world.cabin)
	world.cabin.queue_free()
	await process_frame
	_check(not game.is_overworld_input_locked() and world.get_node_or_null("RocketHideoutLiftMenu") == null, "Removing the cabin closes its menu and releases panel input")
	var interrupted: Node = load(CABIN).instantiate()
	world.add_child(interrupted)
	interrupted.play_departure()
	await process_frame
	game.acquire_overworld_input_lock(&"elevator_test_other")
	world.remove_child(interrupted)
	interrupted.queue_free()
	await process_frame
	_check(game.overworld_input_lock_owners.size() == 1 and game.overworld_input_lock_owners.has(&"elevator_test_other"), "Removing a moving cabin cancels its tween and releases only its own input")
	game.release_overworld_input_lock(&"elevator_test_other")
	world.driver.remote_player_visual_queue.free()
	world.driver.free()
	current_scene = null
	world.free()
	game.current_map = null
	service.set_script(original_service)
	errors.set_script(original_errors)
	print("ROCKET_HIDEOUT_LIFT ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _select(world: Node, panel: Node, index: int) -> void:
	panel._start_manual_interaction(world.player)
	await process_frame
	var dialog := world.get_node("RocketHideoutLiftMenu").get_child(0) as AetherConfirmationDialog
	var choices := dialog.find_child("Floors",true,false) as OptionButton
	choices.select(index)
	dialog.confirmed.emit()
	for frame in range(240):
		await process_frame
		if world.cabin.get_node("Doors").visible:
			for floor: String in ["B1F", "B2F", "B4F"]:
				_check(not world.cabin.get_node("Exits/To" + floor + "/DoorTransitionHint").visible, "A departing lift hides its exit hints")
		if not panel.is_interacting and not world.cabin.get_node("Doors").visible and not world.cabin.get_node("Exits/RideTo" + ["B1F","B2F","B4F"][index]).is_transitioning:
			return
	_check(false, "The lift ride finishes within the bounded runtime check")

func _check(ok: bool, description: String) -> void:
	if not ok:
		failed = true
		push_error(description)
