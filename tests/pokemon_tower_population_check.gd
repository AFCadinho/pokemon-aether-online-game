extends SceneTree

const TOWER := "res://scenes/overworld/kanto/towns/lavender_town/pokemon_tower.tscn"
const POPULATION := "res://docs/tiled/pokemon_tower_population.json"
class UnexpectedNpcMetadataService extends Node:
	var calls := 0
	func get_npc_metadata(_id: String) -> Dictionary:
		calls += 1
		return {"success": true, "metadata": {}}

var failures := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	# Inspect population offline: placement checks must not require live metadata or login.
	var map := (load(TOWER) as PackedScene).instantiate()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(POPULATION))
	var npcs := map.get_node("Entities/NPCs").get_children()
	var pokemon := map.get_node("Entities/Pokemon").get_children()
	var entities: Array = npcs + pokemon
	var npc_service := UnexpectedNpcMetadataService.new()
	root.add_child(npc_service)
	var pokemon_service := root.get_node("OverworldPokemonMetadataService")
	for entity in pokemon:
		entity.NpcMetadataService = npc_service
		await entity.call("_initialize_quest_markers")
		_check(npc_service.calls == 0, "Pokémon startup does not request human NPC metadata: " + entity.name)
		_check(not entity.npc_metadata_load_failed, "Pokémon startup has no false metadata failure: " + entity.name)
		var id: String = entity.overworld_pokemon_id
		var previous: Variant = pokemon_service.overworld_pokemon_metadata_cache.get(id)
		pokemon_service.overworld_pokemon_metadata_cache[id] = {"success": true, "metadata": {
			"speciesId": entity.species_id, "name": entity.display_name,
			"dialogueId": id.trim_suffix("_1") + "_cry",
		}}
		var loaded: Dictionary = await entity.call("_load_overworld_pokemon_metadata_if_needed")
		_check(loaded.get("success", false) and not entity.dialogue_id.is_empty(), "Pokémon still loads its dedicated dialogue metadata: " + entity.name)
		if previous == null:
			pokemon_service.overworld_pokemon_metadata_cache.erase(id)
		else:
			pokemon_service.overworld_pokemon_metadata_cache[id] = previous
		entity.NpcMetadataService = root.get_node("NpcMetadataService")
	# Explicit NPC bindings remain available to deliberately configured actors.
	var explicit_pokemon := (load("res://scenes/npcs/overworld_pokemon.tscn") as PackedScene).instantiate()
	explicit_pokemon.npc_metadata_id = " explicit_pokemon_npc_features "
	_check(explicit_pokemon.call("_get_npc_metadata_id") == "explicit_pokemon_npc_features", "Explicit NPC metadata binding remains supported")
	explicit_pokemon.NpcMetadataService = npc_service
	await explicit_pokemon.call("_initialize_quest_markers")
	_check(npc_service.calls == 1 and explicit_pokemon.npc_metadata_loaded, "Explicit binding loads NPC features normally")
	explicit_pokemon.free()
	npc_service.queue_free()
	var by_id := {}
	var occupied := {}
	var trainer_count := 0
	var dialogue_count := 0
	var story_rival_count := 0
	var healer_count := 0
	var catalog := root.get_node("TrainerPortraitCatalog")
	for entity in entities:
		_check(not by_id.has(entity.npc_id), "Unique NPC/Pokémon ID: " + entity.npc_id)
		by_id[entity.npc_id] = entity
		var cell := Vector2i(entity.position / 32)
		_check(entity.position == Vector2(cell * 32) + Vector2(16, 16), "Tile-center placement: " + entity.name)
		_check(_walkable(map, cell), "Clear mapped floor: " + entity.name)
		_check(not occupied.has(cell), "No overlapping entities: " + entity.name)
		occupied[cell] = entity.name
		_check(_floor_for(map, entity.position) != &"", "Entity is inside a floor mask: " + entity.name)
		_check(entity.movement_behavior == "idle", "Population cannot wander onto stair triggers: " + entity.name)
		for spawn in map.get_node("Spawns").get_children():
			var minimum := 32.0 if spawn.name == &"FromHealingSeal" else 64.0
			_check(entity.position.distance_to(spawn.position) >= minimum, "Arrival remains clear: " + entity.name)
		for container in ["Exits", "FloorTransitions"]:
			for transition in map.get_node(container).get_children():
				var trigger := transition.get_node("CollisionShape2D") as CollisionShape2D
				var rectangle := trigger.shape as RectangleShape2D
				_check(not Rect2(transition.position + trigger.position - rectangle.size / 2, rectangle.size).has_point(entity.position), "Transition remains clear: " + entity.name)
		for other in entities:
			if other != entity:
				_check(entity.position.distance_to(other.position) >= 64, "Interaction space: " + entity.name)
		if entity in pokemon:
			_check(entity.npc_id == entity.overworld_pokemon_id, "Pokémon metadata ID matches")
			var frames := FollowerSpriteService.get_sprite_frames(entity.species_id, entity.shiny)
			_check(frames != null and frames.has_animation("idle_down"), "Follower artwork available: " + entity.species_id)
		else:
			_check(entity.npc_sprite_frames != null, "NPC has overworld artwork: " + entity.name)
			var resolved: String = catalog.resolve_portrait_id(entity.portrait_id, entity.npc_id, entity.npc_definition_id)
			_check(not resolved.is_empty() and catalog.get_texture(resolved) != null, "NPC has matching portrait: " + entity.name)
			var frames: SpriteFrames = entity.call("_get_directional_sprite_frames", entity.npc_sprite_frames)
			for direction in ["down", "left", "right", "up"]:
				_check(frames.has_animation("idle_" + direction), "NPC has directional artwork: " + entity.name)
			if entity.get_script().resource_path.ends_with("trainer_npc.gd"):
				trainer_count += 1
				_check(entity.trainer_id == entity.npc_id, "Trainer ID matches battle metadata")
				_check(entity.sight_range_tiles == 3, "Hex Maniac has a short challenge range")
				_check(resolved == "showdown_hexmaniac_gen6", "Hex Maniac portrait matches class")
				var direction: Vector2 = entity.call("_get_cardinal_direction", entity.facing_direction)
				for step in range(1, entity.sight_range_tiles + 1):
					_check(_walkable(map, cell + Vector2i(direction) * step), "Trainer challenge approach stays clear: " + entity.name)
			elif entity.get_script().resource_path.ends_with("heal_npc.gd"):
				healer_count += 1
			elif entity.npc_id == "kanto_pokemon_tower_gary":
				story_rival_count += 1
			else:
				dialogue_count += 1
	for entity in entities:
		var cell := Vector2i(entity.position / 32)
		var reachable := false
		for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			reachable = reachable or (_walkable(map, cell + offset) and not occupied.has(cell + offset))
		_check(reachable, "Player can stand beside entity: " + entity.name)
	# Follow the actual arrival routes with NPC tiles blocked, as in overworld movement.
	for floor_id in map.get_node("FloorVisibilityMask").floor_regions:
		var bounds: Rect2 = map.get_node("FloorVisibilityMask").floor_regions[floor_id]
		var reachable_cells := {}
		var queue: Array[Vector2i] = []
		for spawn in map.get_node("Spawns").get_children():
			if bounds.has_point(spawn.position) and spawn.name != &"FromHealingSeal":
				var arrival := Vector2i(spawn.position / 32)
				if _route_cell_clear(map, arrival):
					queue.append(arrival)
					reachable_cells[arrival] = true
					break
		_check(not queue.is_empty(), "Floor has a clear stair arrival: " + str(floor_id))
		var next := 0
		while next < queue.size():
			var cell := queue[next]
			next += 1
			for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
				var neighbor: Vector2i = cell + offset
				var down_blocked: bool = offset == Vector2i.DOWN and map.get_node("Tiles/BlockDirection/BlockDown").get_cell_source_id(cell) != -1
				if not down_blocked and not reachable_cells.has(neighbor) and not occupied.has(neighbor) and bounds.has_point(Vector2(neighbor * 32) + Vector2(16, 16)) and _route_cell_clear(map, neighbor):
					reachable_cells[neighbor] = true
					queue.append(neighbor)
		for entity in entities:
			if bounds.has_point(entity.position):
				var accessible := false
				var cell := Vector2i(entity.position / 32)
				for offset in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
					accessible = accessible or reachable_cells.has(cell + offset)
				_check(accessible, "Entity reachable from floor arrival: " + entity.name)
	for trainer: Dictionary in manifest.trainers:
		var entity: Node2D = by_id.get(trainer.id)
		_check(entity != null, "Manifest trainer exists: " + trainer.id)
		if entity != null:
			_check(entity.position == Vector2(trainer.position[0], trainer.position[1]), "Trainer position matches manifest")
			_check(_floor_for(map, entity.position) == StringName("floor_%d" % int(trainer.floor)), "Trainer is on assigned floor")
	for visitor: Dictionary in manifest.dialogueNPCs:
		_check(by_id.has(visitor.id) and _floor_for(map, by_id[visitor.id].position) == StringName("floor_%d" % int(visitor.floor)), "Visitor is on assigned floor")
	for rival: Dictionary in manifest.storyNPCs:
		var entity: Node2D = by_id.get(rival.id)
		_check(entity != null, "Story rival exists: " + rival.id)
		if entity != null:
			_check(entity.position == Vector2(rival.position[0], rival.position[1]), "Story rival position matches manifest")
			_check(_floor_for(map, entity.position) == StringName("floor_%d" % int(rival.floor)), "Story rival is on assigned floor")
			_check(entity.get_node("StoryHook").interaction_id == rival.interactionId, "Story rival uses its main quest battle")
	var generations := {}
	for entry: Dictionary in manifest.pokemon:
		var entity: Node2D = by_id.get(entry.id)
		_check(entity != null, "Manifest Pokémon exists: " + entry.id)
		if entity != null:
			_check(entity.species_id == entry.speciesId and entity.level == int(entry.level), "Pokémon species and level match metadata contract")
			_check(_floor_for(map, entity.position) == StringName("floor_%d" % int(entry.floor)), "Pokémon is on assigned floor")
		generations[int(entry.generation)] = true
	var healer: Node2D = by_id.get(manifest.healerId)
	_check(healer != null and _floor_for(map, healer.position) == &"floor_5", "Healing NPC is on cyan 5F")
	if healer != null:
		var spawn := map.get_node("Spawns/FromHealingSeal") as Marker2D
		_check(healer.position + healer.get_node("RespawnMarker").position == spawn.position, "Healer respawn agrees with catalog marker")
		_check(_walkable(map, Vector2i(spawn.position / 32)) and not occupied.has(Vector2i(spawn.position / 32)), "Healing respawn is free")
		_check(map.get_node("Visual/GroundDetail").get_cell_source_id(Vector2i(spawn.position / 32)) != -1, "Healing arrival is on the cyan seal")
		healer.call("_bind_services")
		var state := root.get_node("GameState")
		var previous: Node = state.current_map
		state.current_map = map
		var payload: Dictionary = healer.call("_build_respawn_point_payload")
		state.current_map = previous
		_check(payload.get("mapId") == "kanto_lavender_town_pokemon_tower" and payload.get("mapScenePath") == TOWER, "Healing respawn targets Tower")
		_check(payload.get("spawnMarker") == "FromHealingSeal" and payload.get("position") == {"x": spawn.position.x, "y": spawn.position.y}, "Healing respawn payload is correct")
	_check(trainer_count == 8 and dialogue_count == 4 and story_rival_count == 1 and healer_count == 1 and pokemon.size() == 7, "Population counts match requested design")
	_check(generations.size() == 7, "Ghost Pokémon span seven generations")
	map.free()
	if failures == 0:
		print("POKEMON_TOWER_POPULATION PASS: 8 Hex Maniacs, 4 visitors, 2F Gary, 5F healer, 7 Ghost Pokémon; clear placement, artwork and respawn")
	quit(1 if failures else 0)

func _walkable(map: Node, cell: Vector2i) -> bool:
	if map.get_node("Visual/Ground").get_cell_source_id(cell) == -1:
		return false
	for path in ["Visual/Walls", "Visual/Objects", "Visual/ObjectsTop", "Tiles/Collision", "Tiles/BlockDirection/BlockDown"]:
		var layer := map.get_node_or_null(path) as TileMapLayer
		if layer != null and layer.get_cell_source_id(cell) != -1:
			return false
	return true

func _route_cell_clear(map: Node, cell: Vector2i) -> bool:
	# Stairs have visual object tiles. Player movement uses the authored collision,
	# and BlockDown prevents leaving its source tile downward only.
	return map.get_node("Visual/Ground").get_cell_source_id(cell) != -1 and map.get_node("Tiles/Collision").get_cell_source_id(cell) == -1

func _floor_for(map: Node, position: Vector2) -> StringName:
	for key in map.get_node("FloorVisibilityMask").floor_regions:
		if map.get_node("FloorVisibilityMask").floor_regions[key].has_point(position):
			return key
	return &""

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
