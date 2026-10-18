extends SceneTree

const DIR := "res://scenes/overworld/kanto/towns/celadon_city/"
const QUEST := "confront_team_rocket_boss"
const SPIN := preload("res://scripts/world/spin_tile_movement.gd")
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
var failed := false

class ProgressProbe extends Node:
	signal progress_invalidated
	var defeated := false
	func get_progress(_id: String) -> Dictionary:
		return {"success": true, "progress": {"state": "completed" if defeated else "first_encounter", "firstDefeated": defeated}}

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
	var turns := 0
	func start_dialogue(_lines: Array, _speaker := "", _portrait: Texture2D = null, _show := true) -> void:
		turns += 1
		is_open = true
		_finish.call_deferred()
	func _finish() -> void:
		await get_tree().process_frame
		is_open = false
		dialogue_finished.emit()

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := root.get_node("GameState")
	state.reset_gameplay_runtime_state()
	root.get_node("CoopService").set_process(false)
	var progress := root.get_node("TrainerProgressService")
	var progress_script: Script = progress.get_script()
	progress.set_script(ProgressProbe)
	var inventory := root.get_node("InventoryService")
	var inventory_script: Script = inventory.get_script()
	inventory.set_script(InventoryProbe)
	var story := root.get_node("StoryService")
	story.apply_story(_story("confront_boss"))
	for floor in range(1, 5):
		var map := load(DIR + "rocket_hideout_b%df.tscn" % floor).instantiate() as Node2D
		_geometry(map, floor)
		_prime(map)
		state.current_map = map
		var stage := Node2D.new()
		root.add_child(stage)
		current_scene = stage
		var viewport: SubViewport = null
		if "--render" in OS.get_cmdline_user_args():
			viewport = SubViewport.new()
			viewport.size = Vector2i([37,37,27,33][floor-1], [44,30,35,39][floor-1]) * 32
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			stage.add_child(viewport)
			viewport.add_child(map)
		else:
			stage.add_child(map)
		var dialog_layer := Node.new()
		dialog_layer.name = "DialogueBox"
		stage.add_child(dialog_layer)
		var box := DialogueProbe.new()
		box.name = "Box"
		dialog_layer.add_child(box)
		for frame in range(4):
			await physics_frame
		for category: String in ["NPCs", "Pokemon"]:
			for actor: Node2D in map.get_node("Entities/" + category).get_children():
				_check(map.is_position_blocked_by_character(actor.global_position), "%s has real actor collision" % actor.name)
				_check(actor.sprite.sprite_frames != null, "%s has native artwork" % actor.name)
				_check(actor.mugshot != null, "%s has a portrait" % actor.name)
		var pokemon: Node = map.get_node("Entities/Pokemon").get_child(0)
		await pokemon.interact_with_player(null)
		await process_frame
		_check(box.turns == 1, "Overworld Pokémon can be spoken to")
		if viewport != null:
			await process_frame
			await process_frame
			viewport.get_texture().get_image().save_png("res://.tmp/populated_hideout_b%d.png" % floor)
		if floor == 4:
			var key := map.get_node("Entities/Interactables/LiftKey")
			var scope := map.get_node("Entities/Interactables/SilphScope")
			var giovanni := map.get_node("Entities/NPCs/Giovanni")
			_check(giovanni.quest_marker != null and giovanni.quest_marker.visible, "Giovanni has the main quest icon")
			_check(not giovanni.rematch_marker.visible, "The battle icon does not overlap the main quest icon")
			_check(not key.visible and not key.blocks_movement, "Lift Key waits for trusted guard victory")
			progress.defeated = true
			story.apply_story(_story("confront_boss"))
			await process_frame
			_check(key.visible and key.blocks_movement, "Defeated grunt reveals the key on this visit")
			_check(not scope.visible, "Scope is hidden before the revelation")
			story.apply_story(_story("collect_scope"))
			await process_frame
			_check(scope.visible and scope.blocks_movement, "Scope appears after Giovanni's revelation")
			_check(not giovanni.visible and not giovanni.blocks_world_position(giovanni.global_position), "Giovanni leaves after his explanation")
			inventory.collected.append(scope.pickup_id)
			inventory.world_pickup_state_changed.emit()
			await process_frame
			_check(not scope.visible and not scope.blocks_movement, "Collected Scope no longer blocks movement")
		current_scene = null
		state.current_map = null
		stage.free()
	inventory.set_script(inventory_script)
	progress.set_script(progress_script)
	print("ROCKET_HIDEOUT_POPULATION ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _geometry(map: Node2D, floor: int) -> void:
	var blockers := {}
	var actors: Array[Node] = []
	for category: String in ["NPCs", "Pokemon", "Interactables"]:
		for actor: Node2D in map.get_node("Entities/" + category).get_children():
			var tile := Vector2i(actor.position / 32.0)
			_check(not blockers.has(tile), "Actors do not overlap: " + str(actor.name))
			_check(map.get_node("Tiles/Collision").get_cell_source_id(tile) < 0, "Actor is on walkable floor: " + str(actor.name))
			for dir: String in ["Up", "Down", "Left", "Right", "Stop"]:
				_check(map.get_node("Tiles/Spin" + dir).get_cell_source_id(tile) < 0, "Actor leaves puzzle markers free")
			blockers[tile] = true
			actors.append(actor)
	var reachable := {}
	var collision := map.get_node("Tiles/Collision") as TileMapLayer
	var spin := SPIN.new()
	spin.refresh_layers(map)
	var queue: Array[Vector2i] = []
	for spawn: Marker2D in map.get_node("Spawns").get_children():
		var tile := Vector2i(spawn.position / 32.0)
		_check(not blockers.has(tile), "Population leaves every arrival clear")
		reachable[tile] = true
		queue.append(tile)
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for offset: Vector2i in DIRECTIONS:
			var next := tile + offset
			if collision.get_cell_source_id(next) >= 0 or blockers.has(next):
				continue
			# Follow the production spinner through normal floor and redirects until
			# a yellow tile, actor, wall or repeated direction releases the player.
			var point := Vector2(next * 32) + Vector2(16,16)
			if spin.try_begin(point):
				for step in range(2000):
					var direction := Vector2i(spin.next_direction(point))
					var candidate := next + direction
					if direction == Vector2i.ZERO or collision.get_cell_source_id(candidate) >= 0 or blockers.has(candidate):
						break
					next = candidate
					point = Vector2(next * 32) + Vector2(16,16)
				spin.stop(point)
			spin.reset()
			if not reachable.has(next):
				reachable[next] = true
				queue.append(next)
			_check(queue.size() < 2000, "Map boundary contains all reachable paths")
			if queue.size() >= 2000:
				return
	for actor: Node2D in actors:
		var tile := Vector2i(actor.position / 32.0)
		var approachable := false
		for offset: Vector2i in DIRECTIONS:
			approachable = approachable or reachable.has(tile + offset)
		_check(approachable, "Can reach %s on B%dF without moving an NPC or crossing a spin tile on foot" % [actor.name,floor])
	for exit_node: Area2D in map.get_node("Exits").get_children():
		_check(reachable.has(Vector2i(exit_node.position / 32.0)), "Population preserves exit " + str(exit_node.name))

func _prime(map: Node) -> void:
	var npc_service := root.get_node("NpcMetadataService")
	var pokemon_service := root.get_node("OverworldPokemonMetadataService")
	var dialogue_service := root.get_node("DialogueMetadataService")
	for actor: Node in map.get_node("Entities/NPCs").get_children():
		var key: String = npc_service.call("_get_cache_key", npc_service.call("_get_http_locale"), actor.npc_id)
		var markers: Array = []
		if actor.name == "Giovanni":
			for step: String in ["confront_boss", "learn_plan"]:
				markers.append({"questId":QUEST,"stepId":step,"statuses":["active"]})
		npc_service.npc_metadata_cache[key] = {"success":true,"metadata":{"id":actor.npc_id,"dialogueId":actor.npc_id+"_intro","questMarkers":markers}}
	for actor: Node in map.get_node("Entities/Pokemon").get_children():
		var dialogue_id: String = "kanto_rocket_hideout_" + actor.species_id + "_cry"
		pokemon_service.overworld_pokemon_metadata_cache[actor.overworld_pokemon_id] = {"success":true,"metadata":{"speciesId":actor.species_id,"dialogueId":dialogue_id}}
		var key: String = dialogue_service.call("_get_cache_key", dialogue_service.call("_get_http_locale"), dialogue_id)
		dialogue_service.dialogue_metadata_cache[key] = {"success":true,"metadata":{"id":dialogue_id,"speakerName":actor.display_name,"lines":[actor.display_name+" cries out!"]}}

func _story(active: String) -> Dictionary:
	var steps: Array[Dictionary] = []
	var previous := true
	for step: String in ["confront_boss", "learn_plan", "collect_scope", "return_to_tower"]:
		steps.append({"stepId":step,"status":"active" if step == active else "completed" if previous else "inactive"})
		if step == active:
			previous = false
	return {"revision": 1 if active == "confront_boss" else 2, "quests":[{"questId":QUEST,"questType":"main","status":"active","steps":steps}]}

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)
