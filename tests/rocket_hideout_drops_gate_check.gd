extends SceneTree

const SCENE := "res://scenes/overworld/kanto/towns/celadon_city/rocket_hideout_b4f.tscn"
const QUEST := "confront_team_rocket_boss"
const KEY_GUARD := "kanto_rocket_hideout_b4f_grunt_1"
const LEFT := "kanto_rocket_hideout_b4f_grunt_2"
const RIGHT := "kanto_rocket_hideout_b4f_grunt_3"
var failed := false
var map: Node2D
var stage: Node2D
var story: Node
var state: Node
var progress: Node
var inventory: Node
var box: Node
var key: Node
var scope: Node
var gate: Node
var giovanni: Node
var player: Node2D
var viewport: SubViewport
var _dialogue_done := false
var _dialogue_ok := false

class ProgressProbe extends Node:
	signal progress_invalidated
	var wins: Dictionary = {}
	var unavailable := ""
	func get_progress(id: String) -> Dictionary:
		var won := bool(wins.get(id, false))
		return {"success": id != unavailable, "progress": {"state": "completed" if won else "first_encounter", "firstDefeated": won}}

class InventoryProbe extends Node:
	signal world_pickup_state_changed
	var collected: Array[String] = []
	func load_collected_world_pickups() -> Dictionary:
		return {"success": true}
	func is_world_pickup_collected(id: String) -> bool:
		return id in collected

class DialogueProbe extends Node:
	signal dialogue_finished
	var is_open := false
	var auto_finish := false
	func start_dialogue(_lines: Array, _speaker := "", _portrait: Texture2D = null, _show := true) -> void:
		is_open = true
		if auto_finish:
			finish.call_deferred()
	func finish() -> void:
		is_open = false
		dialogue_finished.emit()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 120
	state = root.get_node("GameState")
	state.reset_gameplay_runtime_state()
	root.get_node("CoopService").set_process(false)
	story = root.get_node("StoryService")
	progress = root.get_node("TrainerProgressService")
	inventory = root.get_node("InventoryService")
	var original_progress: Script = progress.get_script()
	var original_inventory: Script = inventory.get_script()
	progress.set_script(ProgressProbe)
	inventory.set_script(InventoryProbe)
	story.apply_story(_story("confront_boss"))
	_load_map()
	await _frames(5)
	_check(not key.visible and not scope.visible, "Neither key item exists before its battle")
	_check(not gate.is_gate_open(), "Security gate starts closed")
	_check(_blocked_gate_cells(), "Both tiles of the portal block movement")
	_check(map.is_position_blocked_by_character(Vector2(784,592)) and map.is_position_blocked_by_character(Vector2(816,592)), "Native Player movement cannot cross either closed panel")
	await _capture("closed")

	# The battle reward refresh happens while the grunt's outro is still locked.
	state.acquire_overworld_input_lock(&"fixture_guard_outro")
	box.is_open = true
	progress.wins[KEY_GUARD] = true
	story.apply_story(_story("confront_boss"))
	await _frames(8)
	_check(not key.visible, "Key stays in the grunt's possession during his reaction")
	state.release_overworld_input_lock(&"fixture_guard_outro")
	await _frames(3)
	_check(not key.visible, "An open dialogue still delays the dropped key")
	box.is_open = false
	await _until(func(): return key.visible)
	_check(not key.blocks_movement and key.get("_drop_presenting"), "Key falls visibly before becoming collectible")
	await _until(func(): return key.blocks_movement)
	_check(key.item_sprite.position.is_zero_approx(), "Key lands at the authored pickup position")
	_check(not inventory.is_world_pickup_collected(key.pickup_id), "Drop does not directly grant the key")
	await _capture("key_dropped")

	# Neither guard alone suffices, in either order. Opening waits for the outro.
	progress.wins[LEFT] = true
	progress.progress_invalidated.emit()
	await _frames(5)
	_check(not gate.is_gate_open(), "Left guard alone cannot open the gate")
	progress.wins[LEFT] = false
	progress.wins[RIGHT] = true
	progress.progress_invalidated.emit()
	await _frames(5)
	_check(not gate.is_gate_open(), "Right guard alone cannot open the gate")
	progress.wins[LEFT] = true
	progress.unavailable = RIGHT
	progress.progress_invalidated.emit()
	await _frames(5)
	_check(not gate.is_gate_open(), "Missing trusted guard progress keeps the gate closed")
	progress.unavailable = ""
	state.acquire_overworld_input_lock(&"fixture_guard_outro")
	progress.wins[LEFT] = true
	progress.progress_invalidated.emit()
	await _frames(5)
	_check(_blocked_gate_cells(), "Gate remains solid through the second guard's dialogue")
	state.release_overworld_input_lock(&"fixture_guard_outro")
	await _until(func(): return gate.is_gate_open())
	_check(not map.is_position_blocked_by_character(Vector2(784,592)) and not map.is_position_blocked_by_character(Vector2(816,592)), "Native Player movement can cross both open panels")
	await _capture("open")

	# The Scope slips out before Giovanni reacts. An interruption during its
	# fall must not leave a ghost conversation running or an input lock behind.
	story.apply_story(_story("learn_plan"))
	await _frames(2)
	giovanni.prepare_story_sequence()
	_present_giovanni.call_deferred()
	await _until(func(): return scope.visible)
	_check(giovanni.visible and scope.get("_drop_presenting") and not box.is_open, "Scope falls before Giovanni notices it in dialogue")
	giovanni.abort_story_sequence()
	await _until(func(): return _dialogue_done)
	_check(not _dialogue_ok and not scope.visible and giovanni.visible and not box.is_open, "Aborting the fall restores Giovanni without starting stale dialogue")
	_check(not state.is_overworld_input_locked(), "Aborting the Scope fall releases its input owner")
	_dialogue_done = false
	_dialogue_ok = false
	giovanni.prepare_story_sequence()
	_present_giovanni.call_deferred()
	await _until(func(): return box.is_open)
	_check(giovanni.visible and scope.visible and not scope.get("_drop_presenting"), "Giovanni reacts while the dropped Scope is visibly on the ground")
	_check(not scope.blocks_movement, "The visible Scope still requires story acknowledgement before collection")
	await _capture("giovanni_scope_reaction")
	box.finish()
	await _until(func(): return _dialogue_done)
	_check(not giovanni.visible and scope.visible, "Giovanni leaves after his reaction and abandons the Scope")
	_check(_dialogue_ok and not scope.blocks_movement, "Presented Scope cannot be claimed before story acknowledgement")
	await _capture("scope_left_behind")
	_check(not inventory.is_world_pickup_collected(scope.pickup_id), "Scope is left on the floor, not granted to inventory")

	# A rejected/interrupted acknowledgement restores a repeatable conversation.
	state.acquire_overworld_input_lock(&"unrelated_fixture_lock")
	giovanni.abort_story_sequence()
	await _frames(2)
	_check(giovanni.visible and giovanni.modulate.a == 1.0 and not scope.visible, "Failed acknowledgement restores Giovanni and removes the preview")
	_check(state.is_overworld_input_locked(), "Abort preserves another system's input lock")
	state.release_overworld_input_lock(&"unrelated_fixture_lock")
	box.auto_finish = true
	giovanni.prepare_story_sequence()
	var lines: Array[String] = ["The Tower operation is mine. This is not over."]
	_check(await giovanni.show_dialogue(lines, "Giovanni"), "Interrupted revelation can be replayed")
	story.apply_story(_story("collect_scope"))
	await _frames(3)
	_check(scope.visible and scope.blocks_movement and not giovanni.visible, "Acknowledged revelation leaves the Scope behind")
	inventory.collected.append(scope.pickup_id)
	inventory.world_pickup_state_changed.emit()
	await _frames(2)
	_check(not scope.visible and not scope.blocks_movement, "Picking up the Scope removes it")

	# Reconnecting into earned progression restores the ground item/open door.
	inventory.collected.clear()
	_unload_map()
	_load_map()
	await _frames(5)
	_check(gate.is_gate_open() and not giovanni.visible and scope.visible, "Reload preserves the open gate and uncollected Scope")
	_check(key.visible and not key.get("_drop_presenting"), "A previously dropped key is already on the ground after login")
	_unload_map()

	# Co-op reconstructs the map after victory, before presenting the NPC outro.
	story.apply_story(_story("confront_boss"))
	state.set_pending_coop_battle_result({"activityId": KEY_GUARD, "outcome": "win"})
	state.acquire_overworld_input_lock(&"fixture_coop_outro")
	_load_map()
	await _frames(5)
	_check(not key.visible, "Co-op reload does not expose the key before the grunt's outro")
	state.take_pending_coop_battle_result()
	state.release_overworld_input_lock(&"fixture_coop_outro")
	await _until(func(): return key.visible and key.blocks_movement)
	_check(not inventory.is_world_pickup_collected(key.pickup_id), "Co-op also leaves a real pickup")

	# Freeing a scene mid-drop must release only that drop's named input lock.
	key.set_claimed(false)
	key.present_drop_from(key.global_position + Vector2(32, 0))
	await _frames(2)
	_unload_map()
	await _frames(2)
	_check(not state.is_overworld_input_locked(), "Unloading mid-drop releases the animation input lock")
	progress.set_script(original_progress)
	inventory.set_script(original_inventory)
	print("ROCKET_HIDEOUT_DROPS_GATE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _present_giovanni() -> void:
	var lines: Array[String] = ["Tch. The Silph Scope. Keep it. I can replace a machine."]
	_dialogue_ok = await giovanni.show_dialogue(lines, "Giovanni")
	_dialogue_done = true

func _load_map() -> void:
	stage = Node2D.new()
	root.add_child(stage)
	current_scene = stage
	map = load(SCENE).instantiate()
	state.current_map = map
	_prime()
	viewport = null
	if "--render" in OS.get_cmdline_user_args():
		viewport = SubViewport.new()
		viewport.size = Vector2i(1056,1248)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		stage.add_child(viewport)
		viewport.add_child(map)
	else:
		stage.add_child(map)
	# The host's native sequence is exercised below; avoid a player body
	# auto-starting its proximity trigger while the fixture controls dialogue.
	map.get_node("Entities/NPCs/Giovanni/Conversation").monitoring = false
	var layer := Node.new()
	layer.name = "DialogueBox"
	stage.add_child(layer)
	box = DialogueProbe.new()
	box.name = "Box"
	layer.add_child(box)
	key = map.get_node("Entities/Interactables/LiftKey")
	scope = map.get_node("Entities/Interactables/SilphScope")
	gate = map.get_node("Entities/Interactables/GiovanniGate")
	giovanni = map.get_node("Entities/NPCs/Giovanni")
	player = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/spin_tile_player.gd"))
	player.position = Vector2(784,656)
	map.get_node("Entities/Players").add_child(player)
	for camera: Node in player.find_children("*", "Camera2D", true, false):
		camera.enabled = false

func _capture(label: String) -> void:
	if viewport == null:
		return
	var player_was_visible := player.visible
	player.visible = false
	viewport.canvas_transform = Transform2D.IDENTITY
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	viewport.get_texture().get_image().save_png("res://.tmp/rocket_gate_" + label + ".png")
	player.visible = player_was_visible

func _unload_map() -> void:
	current_scene = null
	state.current_map = null
	stage.queue_free()
	stage = null

func _prime() -> void:
	var service := root.get_node("NpcMetadataService")
	for actor: Node in map.get_node("Entities/NPCs").get_children():
		var cache_key: String = service.call("_get_cache_key", service.call("_get_http_locale"), actor.npc_id)
		service.npc_metadata_cache[cache_key] = {"success":true,"metadata":{"id":actor.npc_id,"dialogueId":actor.npc_id+"_intro","questMarkers":[]}}
	service = root.get_node("OverworldPokemonMetadataService")
	for actor: Node in map.get_node("Entities/Pokemon").get_children():
		service.overworld_pokemon_metadata_cache[actor.overworld_pokemon_id] = {"success":true,"metadata":{"speciesId":actor.species_id}}

func _blocked_gate_cells() -> bool:
	return map.is_position_blocked_by_character(Vector2(784,592)) and map.is_position_blocked_by_character(Vector2(816,592))


func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _until(condition: Callable) -> void:
	for frame in range(400):
		if condition.call():
			return
		await process_frame
	_check(false, "Timed out waiting for native presentation")

func _story(active: String) -> Dictionary:
	var steps: Array[Dictionary] = []
	var previous := true
	for id: String in ["confront_boss","learn_plan","collect_scope","return_to_tower"]:
		steps.append({"stepId":id,"status":"active" if id == active else "completed" if previous else "inactive"})
		if id == active:
			previous = false
	return {"revision":10,"quests":[{"questId":QUEST,"questType":"main","status":"active","steps":steps}]}

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
