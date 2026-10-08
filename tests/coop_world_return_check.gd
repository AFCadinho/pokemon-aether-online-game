extends SceneTree

class ReturnPlayer extends CharacterBody2D:
	var reset_count := 0
	func reset_movement_state() -> void:
		reset_count += 1

var failed := false
var state: Node
const GARY := "kanto_route_22_gary_bulbasaur"
const OUTRO := "fixture_gary_coop_outro"

func _init() -> void:
	_run.call_deferred()

func _world() -> Node2D:
	var world: Node2D = load("res://scenes/world.tscn").instantiate()
	world.set_script(load("res://tests/fixtures/coop_return_world_probe.gd"))
	var maps := world.get_node("CurrentMap")
	for child: Node in maps.get_children():
		child.free()
	var map_node := Node2D.new()
	map_node.name = "kanto_route_22"
	maps.add_child(map_node)
	world.get_node("Player").set_script(ReturnPlayer)
	world.get_node("UIOverlay").free()
	world.get_node("ContentCreatorPhotoMode").free()
	var overlay := CanvasLayer.new()
	overlay.name = "UIOverlay"
	overlay.add_to_group("ui_overlay")
	world.add_child(overlay)
	root.add_child(world)
	current_scene = world
	state.current_map = map_node
	world.player.global_position = Vector2(1488, 432)
	world.is_in_battle = true
	world.active_battle_kind = "coop"
	world.coop_finishing = true
	world.player.set_process(false)
	world.player.set_physics_process(false)
	return world

func _saved(map_id := "kanto_route_22") -> Dictionary:
	return {"mapId": map_id, "activityState": "idle", "position": {"x": 1488, "y": 432}}

func _activity(outcome := "win") -> Dictionary:
	return {"activityId": "gary_route22", "status": "finished", "outcome": outcome}

func _run() -> void:
	state = root.get_node("GameState")
	state.reset_gameplay_runtime_state()
	root.get_node("CoopService").set_process(false)
	var world := _world()
	var player_id: int = world.player.get_instance_id()
	state.lock_input()
	state.acquire_overworld_input_lock(&"test_teleport")
	world._complete_coop_world_return(_activity(), _saved())
	_check(world.player.get_instance_id() == player_id and not world.is_in_battle and not world.coop_finishing,
		"Gary victory keeps the original player and closes the battle")
	_check(world.player.is_processing() and world.player.is_physics_processing() and not state.input_locked,
		"the confirmed return resumes player processing and clears the stale global battle lock")
	_check(state.overworld_input_lock_owners.has(&"test_teleport") and state.overworld_input_lock_owners.has(&"coop_trainer_outro"),
		"the outro owns its handoff without clearing an unrelated scoped lock")
	await process_frame
	_check(world.reload_requests == 0, "unchanged Gary location does not reload the house placeholder")
	world._release_coop_trainer_outro_input()
	_check(state.is_overworld_input_locked(), "outro cleanup preserves the other lock")
	state.release_overworld_input_lock(&"test_teleport")
	_check(not state.is_overworld_input_locked(), "movement unlocks when the remaining owner releases")
	world.free()
	current_scene = null
	state.reset_gameplay_runtime_state()

	# Use the actual DialogueBox and actual metadata-backed outro, with cached fixture content.
	var wild := _activity()
	wild.activityId = "wild_grass:kanto_route_22"
	for terminal: Dictionary in [_activity("loss"), wild]:
		world = _world()
		world._complete_coop_world_return(terminal, _saved())
		_check(not state.is_overworld_input_locked() and world.player.is_processing(),
			"same-tile Gary losses and wild returns resume without an invented trainer outro")
		await process_frame
		_check(world.reload_requests == 0, "unchanged non-outro returns keep the world")
		world.free()
		current_scene = null
		state.reset_gameplay_runtime_state()

	world = _world()
	world.present_results = true
	var trainers: Node = root.get_node("TrainerMetadataService")
	var dialogues: Node = root.get_node("DialogueMetadataService")
	trainers.trainer_metadata_cache[GARY] = {"success": true, "metadata": {"outroDialogueId": OUTRO}}
	var cache_key: String = dialogues._get_cache_key(dialogues._get_http_locale(), OUTRO)
	dialogues.dialogue_metadata_cache[cache_key] = {"success": true, "metadata": {"lines": ["We won!"], "speakerName": "Gary"}}
	var box: Control = world.get_node("DialogueBox/Box")
	state.set_pending_coop_battle_result(_activity())
	world._acquire_coop_trainer_outro_input()
	var completion := {"done": false}
	_present(world, completion)
	_check(box.is_open and state.is_overworld_input_locked(), "Gary's real closing dialogue retains input ownership")
	world._clear_finished_coop_legacy_input()
	_check(state.input_locked, "a live dialogue is not forcibly unlocked")
	box.hide_dialogue()
	_check(state.overworld_input_lock_owners.has(&"coop_trainer_outro"), "the closing press remains fenced on its own frame")
	await process_frame
	await process_frame
	_check(completion.done and not state.is_overworld_input_locked(), "closing the outro releases movement on the following frame")
	world.free()
	current_scene = null
	state.reset_gameplay_runtime_state()

	world = _world()
	world.present_results = true
	trainers.trainer_metadata_cache[GARY] = {"success": false}
	state.set_pending_coop_battle_result(_activity())
	world._acquire_coop_trainer_outro_input()
	state.lock_input()
	completion = {"done": false}
	_present(world, completion)
	await process_frame
	await process_frame
	_check(completion.done and not state.is_overworld_input_locked(), "unavailable outro metadata cannot strand the movement lock")
	world.free()
	current_scene = null
	state.reset_gameplay_runtime_state()

	world = _world()
	world._acquire_coop_trainer_outro_input()
	var replacement_map := Node2D.new()
	state.current_map = replacement_map
	state.acquire_overworld_input_lock(&"new_world_story")
	world.free()
	current_scene = null
	_check(not state.overworld_input_lock_owners.has(&"coop_trainer_outro") and state.overworld_input_lock_owners.has(&"new_world_story"),
		"an outgoing outro releases its own lock without clearing a replacement world's lock")
	replacement_map.free()
	state.reset_gameplay_runtime_state()

	# A shared win may still respawn a defeated participant. That destination is authoritative.
	world = _world()
	var destination := _saved("kanto_players_house")
	world._complete_coop_world_return(_activity(), destination)
	_check(world.coop_world_reload_pending and not world.player.is_processing() and state.is_overworld_input_locked(),
		"a changed destination blocks the old player until world replacement")
	_check(world._is_player_position_save_blocked_by_teleport(), "the old world cannot autosave over a settled respawn destination")
	await process_frame
	_check(world.reload_requests == 1, "a changed map uses the reload path")
	world.free()
	current_scene = null
	_check(state.has_prepared_world_state() and not state.is_overworld_input_locked(),
		"world teardown releases input while preserving the prepared return profile")
	_check(state.consume_prepared_world_state().savedState == destination, "the next world consumes the exact authoritative destination")
	state.reset_gameplay_runtime_state()

	# Ordinary trainer maps keep their existing reload/interaction refresh boundary.
	world = _world()
	var ordinary := _activity()
	ordinary.activityId = "kanto_route_1_lass_zoe"
	world._complete_coop_world_return(ordinary, _saved())
	_check(world.coop_world_reload_pending, "ordinary trainers retain their existing map refresh")
	await process_frame
	world.free()
	current_scene = null
	state.reset_gameplay_runtime_state()
	trainers.trainer_metadata_cache.erase(GARY)
	dialogues.dialogue_metadata_cache.erase(cache_key)
	# Drain deferred reload/result callbacks after freeing the final fixture world.
	for _frame in 3:
		await process_frame
	print("COOP_WORLD_RETURN_", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _present(world: Node, completion: Dictionary) -> void:
	await world._show_pending_coop_battle_result()
	completion.done = true

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error(message)
