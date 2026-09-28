extends "res://scripts/world/map_metadata.gd"

const TILE_SIZE := 32.0
# These thirteen compact sources are the animated water and shore variants
# imported from the Cave Tileset's GroundDetail cells.
const WATER_SOURCE_MIN := 19002
const WATER_SOURCE_MAX := 19014
const BRIDGE_Z := 2053
const ACTOR_ON_BRIDGE_Z := 2054
const LANDINGS := [Vector2i(67, 11), Vector2i(33, 23), Vector2i(84, 33), Vector2i(67, 56)]
# The imported lower floor is exposed at both sides of these bridge cells.
# The remaining dry bridge cells cover cliff faces, not walkable underpasses.
const GROUND_UNDERPASS := Rect2i(66, 42, 2, 8)
const BRIDGE_POSITION_META := &"cerulean_cave_bridge_position"

@onready var bridge_layer: TileMapLayer = get_node_or_null("Visual/Bridges - Upper Level") as TileMapLayer
@onready var water_layer: TileMapLayer = get_node_or_null("Visual/GroundDetail") as TileMapLayer


func _ready() -> void:
	if bridge_layer != null:
		bridge_layer.z_as_relative = false
		bridge_layer.z_index = BRIDGE_Z
	super._ready()


func is_water_tile_for_actor(world_position: Vector2, actor: Node) -> bool:
	if not _has_water(_tile_at(world_position)):
		return false
	return not (_has_bridge(world_position) and not _is_surfing(actor)
		and not _uses_ground_underpass(_actor_position(actor, world_position), actor))


func is_actor_bridge_step_blocked(from_position: Vector2, to_position: Vector2, actor: Node) -> bool:
	var from_bridge := _has_bridge(from_position)
	var to_bridge := _has_bridge(to_position)
	var from_tile := _tile_at(from_position)
	var to_tile := _tile_at(to_position)
	if _is_surfing(actor):
		# Surf may land on the lower floor, but not on a cliff or the upper deck.
		return to_bridge and not _has_water(to_tile) and not GROUND_UNDERPASS.has_point(to_tile)
	if _uses_ground_underpass(from_position, actor):
		return to_bridge and not GROUND_UNDERPASS.has_point(to_tile) and not _has_water(to_tile)
	if to_bridge and not from_bridge:
		return not (LANDINGS.has(from_tile)
			or (GROUND_UNDERPASS.has_point(to_tile) and _is_ground_approach(from_tile)))
	if from_bridge and not to_bridge:
		return not LANDINGS.has(to_tile)
	return false


func get_actor_sort_z_floor_for_actor(world_position: Vector2, actor: Node) -> int:
	var below_deck := _is_surfing(actor) or _uses_ground_underpass(world_position, actor)
	if actor != null:
		# Observe actual rendered positions; movement probes must not change levels.
		actor.set_meta(BRIDGE_POSITION_META, {
			"map": get_instance_id(), "tile": _tile_at(world_position), "below": below_deck,
		})
	# A sprite reaches over the deck while its feet are still on the landing.
	if not below_deck and (_has_bridge(world_position) or LANDINGS.has(_tile_at(world_position))):
		return ACTOR_ON_BRIDGE_Z
	return super.get_actor_sort_z_floor(world_position)


func get_safe_saved_position_for_actor(world_position: Vector2, actor: Node) -> Vector2:
	# The account position record has no bridge level. Save a walker at a bridge
	# landing and a surfer on exposed water, so login can infer the right level.
	if not _has_bridge(world_position):
		return world_position
	if _is_surfing(actor):
		return _nearest_exposed_water(world_position)
	if _uses_ground_underpass(world_position, actor):
		# Account positions have no level: save next to the lower crossing so a
		# login cannot reinterpret the position as standing on the upper deck.
		var tile := _tile_at(world_position)
		tile.x = GROUND_UNDERPASS.position.x - 1 if tile.x == GROUND_UNDERPASS.position.x else GROUND_UNDERPASS.end.x
		return to_global(Vector2(tile) * TILE_SIZE + Vector2.ONE * TILE_SIZE * 0.5)
	var best_tile: Vector2i = LANDINGS[0]
	var shortest_distance := INF
	for landing: Vector2i in LANDINGS:
		var landing_position := to_global(Vector2(landing) * TILE_SIZE + Vector2.ONE * TILE_SIZE * 0.5)
		var distance := world_position.distance_squared_to(landing_position)
		if distance < shortest_distance:
			shortest_distance = distance
			best_tile = landing
	return to_global(Vector2(best_tile) * TILE_SIZE + Vector2.ONE * TILE_SIZE * 0.5)


func _actor_position(actor: Node, fallback: Vector2) -> Vector2:
	if actor != null and actor.has_method("get_feet_position"):
		return actor.call("get_feet_position")
	if actor is Node2D:
		return (actor as Node2D).global_position
	return fallback


func _is_ground_approach(tile: Vector2i) -> bool:
	return tile.y >= GROUND_UNDERPASS.position.y and tile.y < GROUND_UNDERPASS.end.y \
		and (tile.x == GROUND_UNDERPASS.position.x - 1 or tile.x == GROUND_UNDERPASS.end.x)


func _uses_ground_underpass(world_position: Vector2, actor: Node) -> bool:
	if actor == null or not GROUND_UNDERPASS.has_point(_tile_at(world_position)):
		return false
	var state: Dictionary = actor.get_meta(BRIDGE_POSITION_META, {})
	if int(state.get("map", 0)) == get_instance_id():
		var previous_tile: Vector2i = state["tile"]
		if GROUND_UNDERPASS.has_point(previous_tile):
			return bool(state["below"])
		# A surfer arriving from the water stays on the lower floor when landing.
		return _is_ground_approach(previous_tile) \
			or (bool(state["below"]) and _has_water(previous_tile)
				and previous_tile.distance_to(_tile_at(world_position)) <= 1.0)
	# A follower can be created midway through a crossing (e.g. party changes).
	if actor.has_method("get_traversal_leader"):
		var leader: Node = actor.call("get_traversal_leader")
		if leader != null and is_instance_valid(leader):
			var leader_state: Dictionary = leader.get_meta(BRIDGE_POSITION_META, {})
			return int(leader_state.get("map", 0)) == get_instance_id() and bool(leader_state.get("below", false))
	return false


func _nearest_exposed_water(world_position: Vector2) -> Vector2:
	var queue: Array[Vector2i] = [_tile_at(world_position)]
	var visited := {queue[0]: true}
	var next_index := 0
	while next_index < queue.size():
		var tile: Vector2i = queue[next_index]
		next_index += 1
		var center := to_global(Vector2(tile) * TILE_SIZE + Vector2.ONE * TILE_SIZE * 0.5)
		if not _has_bridge(center):
			return center
		for direction in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
			var neighbor: Vector2i = tile + direction
			if not visited.has(neighbor) and _has_water(neighbor):
				visited[neighbor] = true
				queue.append(neighbor)
	return world_position


func _tile_at(world_position: Vector2) -> Vector2i:
	var local_position := to_local(world_position)
	return Vector2i(floori(local_position.x / TILE_SIZE), floori(local_position.y / TILE_SIZE))


func _has_water(tile: Vector2i) -> bool:
	if water_layer == null:
		return false
	var source_id := water_layer.get_cell_source_id(tile)
	return source_id >= WATER_SOURCE_MIN and source_id <= WATER_SOURCE_MAX


func _has_bridge(world_position: Vector2) -> bool:
	if bridge_layer == null:
		return false
	var tile := bridge_layer.local_to_map(bridge_layer.to_local(world_position))
	return bridge_layer.get_cell_source_id(tile) != -1


func _is_surfing(actor: Node) -> bool:
	return actor != null and actor.has_method("is_surfing_activity_active") \
		and bool(actor.call("is_surfing_activity_active"))
