extends SceneTree

const CORNER := "res://scenes/overworld/kanto/towns/celadon_city/game_corner.tscn"
const PREFIX := "kanto_celadon_game_corner_"
var failed := false

class Customer extends CharacterBody2D:
	var last_direction := Vector2.UP
	func get_feet_position() -> Vector2:
		return global_position

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var map: Node2D = load(CORNER).instantiate()
	var collision: TileMapLayer = map.get_node("Tiles/Collision")
	var actors: Array[Node] = []
	for actor: Node in map.get_node("Entities/NPCs").get_children():
		if actor.npc_id != "kanto_game_corner_attendant":
			actors.append(actor)
	var people := actors.size()
	actors.append_array(map.get_node("Entities/Pokemon").get_children())
	_check(people == 5 and actors.size() == 8, "Five visitors and three companion Pokemon")
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
			lanes[tile] = true
	_check(speeds.size() >= 5 and waits.size() >= 5, "Varied movement speeds and pauses")
	var game_state := root.get_node("GameState")
	game_state.current_map = map
	_cache_actor_metadata(map)
	root.add_child(map)
	for vendor: Node in map.get_node("Entities/NPCs").get_children():
		if vendor.npc_id == "kanto_game_corner_attendant":
			vendor.set_process(false)
	var mask: Node2D = map.get_node("FloorVisibilityMask")
	_check(mask.get_active_floor_region() == Rect2(0, 0, 896, 672) and mask.z_index == 4096 and not mask.z_as_relative, "Mask covers the complete map canvas above actors")
	for point: Vector2 in [Vector2(-32, 336), Vector2(928, 336), Vector2(448, -32), Vector2(448, 704)]:
		var covered := false
		for polygon: Polygon2D in mask.get_children():
			_check(polygon.color == Color.BLACK, "Exterior mask is black")
			covered = covered or Geometry2D.is_point_in_polygon(point, polygon.polygon)
		_check(covered, "Mask hides exterior in every direction: " + str(point))
	for polygon: Polygon2D in mask.get_children():
		_check(not Geometry2D.is_point_in_polygon(Vector2(432, 272), polygon.polygon), "Mask leaves the playable room visible")
	var host: Node2D = map.get_node("Entities/NPCs/HostIris")
	var customer := Customer.new()
	customer.name = "Player"
	var body_shape := CollisionShape2D.new()
	body_shape.shape = RectangleShape2D.new()
	body_shape.shape.size = Vector2(32, 30)
	customer.add_child(body_shape)
	customer.position = host.position + Vector2(0, 96)
	map.add_child(customer)
	for frame in range(3):
		await physics_frame
	_check(host.player_nearby and host._is_player_facing_npc(customer), "Reception host can be spoken to across the desk")
	customer.queue_free()
	var moved := {}
	for frame in range(480):
		await physics_frame
		for actor: Node2D in actors:
			var tile := collision.local_to_map(actor.position)
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
	print("GAME_CORNER_POPULATION_MASK ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


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
