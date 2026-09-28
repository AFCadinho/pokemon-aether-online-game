extends SceneTree

class TestActor extends Node2D:
	var surfing := false
	func is_surfing_activity_active() -> bool:
		return surfing

const SCENE := preload("res://scenes/overworld/kanto/caves/cerulean_cave/cerulean_cave.tscn")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var map := SCENE.instantiate()
	root.add_child(map)
	var actor := TestActor.new()
	map.add_child(actor)
	var bridge := map.get_node("Visual/Bridges - Upper Level") as TileMapLayer
	_expect(bridge.z_index == 2053 and not bridge.z_as_relative, "bridge renders above Surf")
	actor.surfing = true
	var water_cells := 0
	for y in range(96):
		for x in range(128):
			if map.is_water_tile_for_actor(_center(x, y), actor):
				water_cells += 1
	_expect(water_cells == 1964, "water follows all imported cave water and shore tiles")
	actor.surfing = false

	var underpass := _center(66, 28)
	var underpass_next := _center(66, 29)
	_expect(map.is_water_tile_for_actor(underpass, actor) == false, "walking on bridge uses the upper surface")
	_expect(map.get_actor_sort_z_floor_for_actor(underpass, actor) > bridge.z_index, "walker renders above the deck")
	actor.surfing = true
	_expect(map.is_water_tile_for_actor(underpass, actor), "Surf recognizes water beneath deck")
	_expect(not map.is_actor_bridge_step_blocked(underpass, underpass_next, actor), "Surf passes below bridge")
	_expect(map.get_actor_sort_z_floor_for_actor(underpass, actor) < bridge.z_index, "Surfer renders beneath deck")
	_expect(map.is_actor_bridge_step_blocked(underpass, _center(66, 12), actor), "Surf cannot climb onto dry deck")

	actor.surfing = false
	for landing: Vector2i in [Vector2i(67, 11), Vector2i(33, 23), Vector2i(84, 33), Vector2i(67, 56)]:
		_expect(map.get_actor_sort_z_floor_for_actor(_center(landing.x, landing.y), actor) > bridge.z_index,
			"walker remains visible on bridge landing %s" % landing)
	_expect(not map.is_actor_bridge_step_blocked(_center(33, 23), _center(34, 23), actor), "west landing leads onto deck")
	_expect(map.is_actor_bridge_step_blocked(_center(34, 24), _center(34, 23), actor), "side entry onto deck is blocked")
	_expect(map.is_actor_bridge_step_blocked(_center(34, 23), _center(34, 24), actor), "walking off bridge edge is blocked")
	_expect(not map.is_actor_bridge_step_blocked(_center(34, 23), _center(33, 23), actor), "landing permits leaving deck")
	_expect(not map.is_water_tile_for_actor(_center(33, 23), actor), "landing remains dry")
	var saved_position: Vector2 = map.get_safe_saved_position_for_actor(underpass, actor)
	_expect(saved_position == _center(67, 11) or saved_position == _center(33, 23)
		or saved_position == _center(84, 33) or saved_position == _center(67, 56),
		"walking on a bridge saves at a landing")
	actor.surfing = true
	var saved_surf_position: Vector2 = map.get_safe_saved_position_for_actor(underpass, actor)
	actor.surfing = false
	_expect(saved_surf_position != underpass and map.is_water_tile_for_actor(saved_surf_position, actor),
		"Surf beneath a bridge saves on exposed water so login restores Surf")
	var game_state := root.get_node("GameState")
	var original_map: Node = game_state.current_map
	var player = load("res://scenes/player.tscn").instantiate()
	player.set_script(load("res://tests/fixtures/cerulean_bridge_player.gd"))
	map.get_node("Entities/Players").add_child(player)
	game_state.current_map = map
	player.global_position = _center(33, 23)
	player.refresh_map_layers()
	_expect(not player._is_world_barrier_step_blocked(_center(33, 23), _center(34, 23)),
		"player movement accepts the landing")
	_expect(player._is_world_barrier_step_blocked(_center(34, 24), _center(34, 23)),
		"player movement rejects a bridge side entry")
	_expect(not player._is_water_tile_at(underpass), "player sees a walking bridge tile as dry")
	player.surf_activity_active = true
	_expect(player._is_water_tile_at(underpass), "player sees water under bridge while surfing")
	player._update_sort_z()
	_expect(player.z_index < bridge.z_index, "player Surf sprite is under bridge")
	player.surf_activity_active = false
	player.global_position = underpass
	player._update_sort_z()
	_expect(player.z_index > bridge.z_index, "player walking sprite is above bridge")
	var follower := PokemonFollower.new()
	map.get_node("Entities/Players").add_child(follower)
	follower.setup(player)
	follower.global_position = _center(33, 23)
	follower._update_sort_z()
	_expect(follower.z_index > bridge.z_index, "follower remains visible on a bridge landing")
	follower.global_position = underpass
	follower._update_sort_z()
	_expect(follower.z_index > bridge.z_index, "follower remains visible across a horizontal bridge")
	player.surf_activity_active = true
	player.global_position = underpass
	player._update_sort_z()
	follower._update_sort_z()
	_expect(follower.z_index < bridge.z_index, "follower remains below the deck during Surf")
	player.surf_activity_active = false
	var remote = load("res://scripts/world/remote_player_avatar.gd").new()
	remote.current_activity_style = "ride"
	remote.presence_state = {"movement": {"activityStyle": "surf"}}
	_expect(map.get_actor_sort_z_floor_for_actor(underpass, remote) < bridge.z_index,
		"remote Surf avatar stays under bridge")
	remote.presence_state = {"movement": {"activityStyle": "ride"}}
	_expect(map.get_actor_sort_z_floor_for_actor(underpass, remote) > bridge.z_index,
		"remote walker stays above bridge")
	remote.free()
	_check_ground_crossings(map, bridge)
	player.global_position = _center(65, 44)
	player._update_sort_z()
	_expect(not player._is_world_barrier_step_blocked(_center(65, 44), _center(66, 44)),
		"player movement accepts the lower dry crossing")
	player.global_position = _center(66, 44)
	player._update_sort_z()
	_expect(player.z_index < bridge.z_index, "player walking beneath bridge renders below deck")
	follower.global_position = _center(65, 44)
	follower._update_sort_z()
	follower.global_position = _center(66, 44)
	follower._update_sort_z()
	_expect(follower.z_index < bridge.z_index, "walking follower passes beneath the deck")
	follower.remove_meta(map.BRIDGE_POSITION_META)
	follower._update_sort_z()
	_expect(follower.z_index < bridge.z_index, "new follower inherits the lower crossing level")
	game_state.current_map = original_map

	map.queue_free()
	print("CERULEAN_BRIDGE_LEVELS ", "PASS" if not failed else "FAIL")
	quit(1 if failed else 0)


func _check_ground_crossings(map: Node, bridge: TileMapLayer) -> void:
	for y in range(42, 50):
		for direction in [-1, 1]:
			var walker := TestActor.new()
			map.add_child(walker)
			var x := 65 if direction == 1 else 68
			walker.global_position = _center(x, y)
			map.get_actor_sort_z_floor_for_actor(walker.global_position, walker)
			var crossed := true
			for step in range(3):
				var next_position := _center(x+direction, y)
				crossed = crossed and not map.is_actor_bridge_step_blocked(walker.global_position, next_position, walker)
				crossed = crossed and not map.is_water_tile_for_actor(next_position, walker)
				x += direction
				walker.global_position = next_position
				crossed = crossed and map.get_actor_sort_z_floor_for_actor(next_position, walker) < bridge.z_index
			_expect(crossed, "dry underpass row %d is walkable below deck in direction %d" % [y, direction])
			walker.free()

	var walker := TestActor.new()
	map.add_child(walker)
	walker.global_position = _center(67, 41)
	map.get_actor_sort_z_floor_for_actor(walker.global_position, walker)
	var above := true
	for y in range(42, 51):
		walker.global_position = _center(67, y)
		above = above and map.get_actor_sort_z_floor_for_actor(walker.global_position, walker) > bridge.z_index
	_expect(above, "upper bridge walk stays above the entire dry underpass")
	walker.global_position = _center(67, 44)
	map.get_actor_sort_z_floor_for_actor(walker.global_position, walker)
	_expect(map.is_actor_bridge_step_blocked(walker.global_position, _center(68, 44), walker),
		"upper bridge walker cannot step sideways onto the lower floor")
	_expect(map.is_actor_bridge_step_blocked(_center(65, 50), _center(66, 50), walker),
		"cliff face below a dry bridge remains blocked")
	walker.global_position = _center(65, 42)
	map.get_actor_sort_z_floor_for_actor(walker.global_position, walker)
	walker.global_position = _center(66, 42)
	map.get_actor_sort_z_floor_for_actor(walker.global_position, walker)
	_expect(map.is_water_tile_for_actor(_center(66, 41), walker),
		"lower walker sees water at the end of the dry underpass")
	var state_before: Dictionary = walker.get_meta(map.BRIDGE_POSITION_META).duplicate()
	map.is_actor_bridge_step_blocked(_center(67, 11), _center(67, 12), walker)
	_expect(walker.get_meta(map.BRIDGE_POSITION_META) == state_before,
		"movement probes do not change the actor's crossing level")
	var saved: Vector2 = map.get_safe_saved_position_for_actor(walker.global_position, walker)
	_expect(saved == _center(65, 42), "lower crossing saves beside the bridge, without moving onto its deck")
	walker.surfing = true
	walker.global_position = _center(66, 41)
	map.get_actor_sort_z_floor_for_actor(walker.global_position, walker)
	_expect(not map.is_actor_bridge_step_blocked(walker.global_position, _center(66, 42), walker),
		"Surf can land on the dry floor beneath the bridge")
	walker.global_position = _center(66, 42)
	map.get_actor_sort_z_floor_for_actor(walker.global_position, walker)
	walker.surfing = false
	_expect(map.get_actor_sort_z_floor_for_actor(walker.global_position, walker) < bridge.z_index,
		"dismounting Surf beneath a bridge preserves the lower level")
	walker.free()


func _center(x: int, y: int) -> Vector2:
	return Vector2(x * 32 + 16, y * 32 + 16)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failed = true
		push_error("FAIL: " + description)
