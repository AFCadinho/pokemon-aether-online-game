extends SceneTree

class TestActor extends Node:
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
	var remote = load("res://scripts/world/remote_player_avatar.gd").new()
	remote.current_activity_style = "ride"
	remote.presence_state = {"movement": {"activityStyle": "surf"}}
	_expect(map.get_actor_sort_z_floor_for_actor(underpass, remote) < bridge.z_index,
		"remote Surf avatar stays under bridge")
	remote.presence_state = {"movement": {"activityStyle": "ride"}}
	_expect(map.get_actor_sort_z_floor_for_actor(underpass, remote) > bridge.z_index,
		"remote walker stays above bridge")
	remote.free()
	game_state.current_map = original_map

	map.queue_free()
	print("CERULEAN_BRIDGE_LEVELS ", "PASS" if not failed else "FAIL")
	quit(1 if failed else 0)


func _center(x: int, y: int) -> Vector2:
	return Vector2(x * 32 + 16, y * 32 + 16)


func _expect(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		failed = true
		push_error("FAIL: " + description)
