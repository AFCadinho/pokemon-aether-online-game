extends SceneTree

const STORE := "res://scenes/overworld/kanto/towns/celadon_city/celadon_department_store.tscn"
const PREFIX := "kanto_celadon_department_store_"
var failed := false

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map: Node2D = load(STORE).instantiate()
	var collision: TileMapLayer = map.get_node("Tiles/Collision")
	var actors: Array[Node] = []
	for actor: Node in map.get_node("Entities/NPCs").get_children():
		if actor.get("market_id") == null:
			actors.append(actor)
	var people := actors.size()
	actors.append_array(map.get_node("Entities/Pokemon").get_children())
	_check(people == 5 and actors.size() == 9, "Five shoppers and four companion Pokemon")
	var lanes := {}
	var speeds := {}
	var waits := {}
	var ids := {}
	var origin_cells := {}
	for actor: Node2D in actors:
		var pokemon := actor.get("species_id") != null
		var id: String = actor.overworld_pokemon_id if pokemon else actor.npc_id
		_check(id.begins_with(PREFIX) and not ids.has(id) and not actor.dialogue_id.is_empty(), "Unique content and dialogue: " + actor.name)
		ids[id] = true
		_check(actor.natural_ambient_movement and not actor.ambient_movement_ignores_map_collision, "Natural movement respects collision: " + actor.name)
		if pokemon:
			_check(FollowerSpriteService.get_sprite_frames(actor.species_id, false) != null, "Follower artwork loads: " + actor.name)
			actor.auto_resolve_home_icon = false
		else:
			_check(actor.npc_sprite_frames != null, "NPC artwork loads: " + actor.name)
		var cell := collision.local_to_map(actor.position)
		_check(collision.map_to_local(cell) == actor.position, "Tile-centered placement: " + actor.name)
		origin_cells[actor] = cell
		var radius: int = 0 if actor.movement_behavior == "idle" else actor.movement_tiles
		var axis := Vector2i.RIGHT if actor.movement_behavior == "pace_horizontal" else Vector2i.DOWN
		if radius > 0:
			speeds[actor.movement_speed_pixels] = true
			waits[actor.movement_wait_seconds] = true
			_check(actor.movement_wait_jitter_seconds > 0, "Independent pause variation: " + actor.name)
		for step in range(-radius, radius + 1):
			var tile := cell + axis * step
			_check(collision.get_cell_source_id(tile) == -1, "Patrol respects gameplay collision: " + actor.name + str(tile))
			for layer: String in ["Objects", "ObjectsTop"]:
				_check(map.get_node("Visual/" + layer).get_cell_source_id(tile) == -1, "Patrol avoids revised visual furniture: " + actor.name + str(tile))
			_check(not lanes.has(tile), "Patrol lanes do not overlap: " + actor.name)
			for exit_node: Node in map.get_node("Exits").get_children():
				_check(not exit_node.contains_world_position(collision.map_to_local(tile)), "Patrol stays away from exits: " + actor.name)
			lanes[tile] = true
	_check(speeds.size() >= 6 and waits.size() >= 6, "Varied movement speeds and pauses")
	var reached := _reachable(collision, collision.local_to_map(map.get_node("Spawns/FromOutside").position), lanes)
	for vendor_name: String in ["BattlePointVendor", "EvolutionItemVendor", "ZCrystalVendor", "MegaStoneVendor"]:
		var vendor: Node2D = map.get_node("Entities/NPCs/" + vendor_name)
		_check(reached.has(collision.local_to_map(vendor.position + Vector2(0, 96))), "Vendor remains reachable even if every patrol lane is occupied: " + vendor_name)
	for actor: Node2D in actors:
		var approachable := false
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			approachable = approachable or reached.has(origin_cells[actor] + direction)
		_check(approachable, "Visitor can be approached from public floor: " + actor.name)
	var game_state := root.get_node("GameState")
	game_state.current_map = map
	_cache_actor_metadata(map)
	root.add_child(map)
	for vendor: Node in map.get_node("Entities/NPCs").get_children():
		if vendor.get("market_id") != null:
			vendor.set_process(false)
	var moved := {}
	for frame in range(480):
		await physics_frame
		for actor: Node2D in actors:
			var tile := collision.local_to_map(actor.position)
			_check(lanes.has(tile) and collision.get_cell_source_id(tile) == -1, "Runtime movement stays on safe patrol floor: " + actor.name)
			if tile != origin_cells[actor]:
				moved[actor] = true
	for actor: Node in actors:
		if actor.movement_behavior != "idle":
			_check(moved.has(actor), "Visitor actually walks after its independent initial pause: " + actor.name)
	for actor: Node in actors:
		actor.set_process(false)
	while actors.any(func(actor): return actor.is_npc_moving):
		await physics_frame
	game_state.current_map = null
	map.queue_free()
	await process_frame
	await process_frame
	print("CELADON_STORE_POPULATION ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _reachable(collision: TileMapLayer, start: Vector2i, occupied: Dictionary) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var index := 0
	while index < queue.size():
		var tile := queue[index]
		index += 1
		for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var next := tile + direction
			if not Rect2i(0, 0, 42, 36).has_point(next) or seen.has(next) or occupied.has(next) or collision.get_cell_source_id(next) != -1:
				continue
			seen[next] = true
			queue.append(next)
	return seen

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _cache_actor_metadata(map: Node) -> void:
	# Exercise local physics and movement without contacting a running backend.
	var npc_service := root.get_node("NpcMetadataService")
	for actor: Node in map.get_node("Entities/NPCs").get_children():
		var id: String = actor._get_npc_metadata_id()
		if not id.is_empty():
			var key: String = npc_service._get_cache_key(npc_service._get_http_locale(), id)
			npc_service.npc_metadata_cache[key] = {"success": true, "metadata": {"id": id, "name": actor.display_name, "dialogueId": actor.dialogue_id}}
	var pokemon_service := root.get_node("OverworldPokemonMetadataService")
	for actor: Node in map.get_node("Entities/Pokemon").get_children():
		pokemon_service.overworld_pokemon_metadata_cache[actor.overworld_pokemon_id] = {"success": true, "metadata": {"id": actor.overworld_pokemon_id, "name": actor.display_name, "speciesId": actor.species_id, "level": actor.level, "dialogueId": actor.dialogue_id, "interactionType": "cry"}}

