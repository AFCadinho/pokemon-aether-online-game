extends SceneTree

const SCENE := "res://scenes/overworld/kanto/towns/celadon_city/rocket_hideout_b1f.tscn"
const GUARD := "kanto_rocket_hideout_b1f_grunt_3"
const Spin := preload("res://scripts/world/spin_tile_movement.gd")
const DIRS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var failed := false
var state: Node
var progress: Node
var stage: Node2D
var map: Node2D
var gate: Node
var player: Node2D
var viewport: SubViewport

class ProgressProbe extends Node:
	signal progress_invalidated
	var wins := {}
	var available := true
	func get_progress(id: String) -> Dictionary:
		var won := bool(wins.get(id, false))
		return {"success": available, "progress": {"state": "completed" if won else "first_encounter", "firstDefeated": won}}

class InventoryProbe extends Node:
	signal world_pickup_state_changed
	func load_collected_world_pickups() -> Dictionary:
		return {"success": true}
	func is_world_pickup_collected(_id: String) -> bool:
		return false

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	Engine.max_fps = 120
	state = root.get_node("GameState")
	state.reset_gameplay_runtime_state()
	root.get_node("CoopService").set_process(false)
	progress = root.get_node("TrainerProgressService")
	var inventory := root.get_node("InventoryService")
	var progress_script: Script = progress.get_script()
	var inventory_script: Script = inventory.get_script()
	progress.set_script(ProgressProbe)
	inventory.set_script(InventoryProbe)
	_load_map()
	await _frames(5)
	_check(gate.required_trainer_ids == [GUARD] and gate.completed_quest_id.is_empty(), "B1F shortcut requires its own lift-side guard")
	_check(not gate.is_gate_open(), "B1F shortcut starts closed")
	var reachable := _reachable(map, map.get_node("Spawns/FromUpToGameCorner").position)
	_check(not reachable.has(Vector2i(30,34)), "Entrance cannot reach the B1F lift before the guard victory")
	_check(reachable.has(Vector2i(23,5)), "Entrance still reaches the north stairs to B2F")
	_check(not _can_approach_guard(reachable), "The lift-side guard cannot be challenged from the entrance wing")
	var lift_side := _reachable(map, map.get_node("Spawns/FromLift").position)
	_check(_can_approach_guard(lift_side), "Arriving by lift can approach the required grunt")
	_check(lift_side.has(Vector2i(30,33)), "A closed shortcut never traps a player outside the lift")
	var workroom := _reachable(map, map.get_node("Spawns/FromDownToB2F").position)
	_check(not workroom.has(Vector2i(30,34)), "The southern B1F stairs do not bypass the gate")
	_check(not player.can_move_to(Vector2(848,784)) and not player.can_move_to(Vector2(880,784)), "Both closed panels block native Player movement")
	await _capture("closed")

	progress.wins["kanto_rocket_hideout_b1f_grunt_5"] = true
	progress.progress_invalidated.emit()
	await _frames(5)
	_check(not gate.is_gate_open(), "A different B1F grunt cannot open the shortcut")
	# Completing Giovanni is not a substitute for defeating this gate's guard.
	root.get_node("StoryService").apply_story({"revision": 5, "quests": [{"questId":"confront_team_rocket_boss", "status":"completed", "steps":[{"stepId":"confront_boss", "status":"completed"}]}]})
	await _frames(5)
	_check(not gate.is_gate_open(), "Boss progression cannot unlock the B1F shortcut")
	progress.wins[GUARD] = true
	progress.available = false
	progress.progress_invalidated.emit()
	await _frames(5)
	_check(not gate.is_gate_open(), "Unavailable progress cannot unlock the shortcut")
	progress.available = true
	state.acquire_overworld_input_lock(&"gate_guard_outro")
	progress.progress_invalidated.emit()
	await _frames(5)
	_check(not gate.is_gate_open(), "The gate waits for the guard's defeat dialogue")
	state.release_overworld_input_lock(&"gate_guard_outro")
	await _until_open()
	_check(player.can_move_to(Vector2(848,784)) and player.can_move_to(Vector2(880,784)), "Both panels admit native Player movement after opening")
	reachable = _reachable(map, map.get_node("Spawns/FromUpToGameCorner").position)
	_check(reachable.has(Vector2i(30,34)), "The opened shortcut connects the entrance and lift")
	lift_side = _reachable(map, map.get_node("Spawns/FromLift").position)
	_check(lift_side.has(Vector2i(15,5)), "The open gate gives lift arrivals a route back to the Game Corner")
	await _capture("open")
	_unload_map()
	await _frames(2)
	_load_map()
	await _frames(5)
	_check(gate.is_gate_open(), "A reconnect restores the permanently earned shortcut")
	_unload_map()
	await _frames(2)
	state.set_pending_coop_battle_result({"activityId":GUARD, "outcome":"win"})
	state.acquire_overworld_input_lock(&"coop_guard_outro")
	_load_map()
	await _frames(5)
	_check(not gate.is_gate_open(), "Adventure Party reload waits for its guard outro")
	state.take_pending_coop_battle_result()
	state.release_overworld_input_lock(&"coop_guard_outro")
	await _until_open()
	_unload_map()
	await _frames(2)
	# The required first route is still the production spinner route on B2F.
	var b2: Node2D = load(SCENE.replace("b1f", "b2f")).instantiate()
	state.current_map = b2
	_prime(b2)
	root.add_child(b2)
	await _frames(5)
	var b2_reachable := _reachable(b2, b2.get_node("Spawns/FromNorthUpToB1F").position, true)
	# Ground pickups can be collected from an adjacent reachable stop, then
	# their cells cease blocking later spins. Do not assume all items vanished.
	for pass_index in range(8):
		var collected := false
		for item: Node2D in b2.get_node("Entities/Interactables").get_children():
			if item.claimed:
				continue
			var tile := Vector2i(item.position / 32)
			for dir: Vector2i in DIRS:
				if b2_reachable.has(tile + dir):
					item.set_claimed(true)
					collected = true
					break
		if not collected:
			break
		b2_reachable = _reachable(b2, b2.get_node("Spawns/FromNorthUpToB1F").position, true)
	_check(b2_reachable.has(Vector2i(31,22)), "The B2F spinner route still reaches the elevator")
	if "--render" in OS.get_cmdline_user_args():
		var b2_view := SubViewport.new()
		b2_view.size = Vector2i(1184,960)
		b2_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(b2_view)
		b2.reparent(b2_view)
		await _frames(3)
		b2_view.get_texture().get_image().save_png("res://.tmp/rocket_b2_gate_route.png")
		b2.reparent(root)
		b2_view.free()
	b2.free()
	state.current_map = null
	progress.set_script(progress_script)
	inventory.set_script(inventory_script)
	_check(not state.is_overworld_input_locked(), "Gate handling leaves no input lock")
	print("ROCKET_HIDEOUT_B1F_GATE ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _load_map() -> void:
	stage = Node2D.new()
	root.add_child(stage)
	current_scene = stage
	map = load(SCENE).instantiate()
	state.current_map = map
	_prime(map)
	viewport = null
	if "--render" in OS.get_cmdline_user_args():
		viewport = SubViewport.new()
		viewport.size = Vector2i(1184,1408)
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		stage.add_child(viewport)
		viewport.add_child(map)
	else:
		stage.add_child(map)
	gate = map.get_node("Entities/Interactables/LiftShortcutGate")
	player = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/spin_tile_player.gd"))
	player.position = Vector2(848,752)
	map.get_node("Entities/Players").add_child(player)
	for camera: Node in player.find_children("*", "Camera2D", true, false):
		camera.enabled = false

func _prime(target: Node) -> void:
	var service := root.get_node("NpcMetadataService")
	for actor: Node in target.get_node("Entities/NPCs").get_children():
		var cache_key: String = service.call("_get_cache_key", service.call("_get_http_locale"), actor.npc_id)
		service.npc_metadata_cache[cache_key] = {"success":true,"metadata":{"id":actor.npc_id,"questMarkers":[]}}
	service = root.get_node("OverworldPokemonMetadataService")
	for actor: Node in target.get_node("Entities/Pokemon").get_children():
		service.overworld_pokemon_metadata_cache[actor.overworld_pokemon_id] = {"success":true,"metadata":{"speciesId":actor.species_id}}

func _reachable(target: Node2D, origin: Vector2, use_spinners := false) -> Dictionary:
	var collision := target.get_node("Tiles/Collision") as TileMapLayer
	var spin := Spin.new()
	spin.refresh_layers(target)
	var queue: Array[Vector2i] = [Vector2i(origin / 32)]
	var seen := {queue[0]:true}
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for dir: Vector2i in DIRS:
			var next := tile + dir
			if not _free_tile(target, collision, next):
				continue
			var point := Vector2(next * 32) + Vector2(16,16)
			if use_spinners and spin.try_begin(point):
				for step in range(2000):
					var direction := Vector2i(spin.next_direction(point))
					if direction == Vector2i.ZERO or not _free_tile(target, collision, next + direction):
						break
					next += direction
					point = Vector2(next * 32) + Vector2(16,16)
				spin.stop(point)
			spin.reset()
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

func _free_tile(target: Node2D, collision: TileMapLayer, tile: Vector2i) -> bool:
	return Rect2i(0,0,37,44).has_point(tile) and collision.get_cell_source_id(tile) < 0 and not target.is_position_blocked_by_character(Vector2(tile * 32) + Vector2(16,16))

func _can_approach_guard(reachable: Dictionary) -> bool:
	var tile := Vector2i(map.get_node("Entities/NPCs/RocketGrunt3").get_feet_position() / 32)
	for dir: Vector2i in DIRS:
		if reachable.has(tile + dir):
			return true
	return false

func _until_open() -> void:
	for frame in range(300):
		if gate.is_gate_open():
			return
		await process_frame
	_check(false, "Timed out opening the shortcut gate")

func _capture(label: String) -> void:
	if viewport == null:
		return
	await process_frame
	await process_frame
	viewport.get_texture().get_image().save_png("res://.tmp/rocket_b1f_gate_" + label + ".png")

func _unload_map() -> void:
	state.current_map = null
	current_scene = null
	stage.free()

func _frames(count: int) -> void:
	for frame in range(count):
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
