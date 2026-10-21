extends SceneTree
class DenialPresenter extends Node:
	var checked_transition := ""
	var received: Dictionary = {}
	func handles_world_transition(candidate: String) -> bool:
		return candidate == checked_transition
	func present_world_transition_denied(access: Dictionary, _player: Node2D) -> void:
		received = access

class OverlayProbe extends Node:
	var message := ""
	func add_system_message(text: String) -> void:
		message = text

var failed := false
func _init() -> void:
	run.call_deferred()
func run() -> void:
	var settings: Node = root.get_node("SettingsManager")
	var previous_mount: String = settings.get_selected_mount_id("land")
	settings.set_selected_mount_id("land","cyclizar")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate()
	player.set_script(load("res://tests/fixtures/cycling_road_player_probe.gd"))
	root.add_child(player)
	var state: Node = root.get_node("GameState")
	var previous: Node = state.current_map
	for number in [16,17]:
		var map := (load("res://scenes/overworld/kanto/routes/kanto_route_%s.tscn" % number) as PackedScene).instantiate()
		for container in ["Entities/NPCs","Entities/Pokemon"]:
			for actor in map.get_node(container).get_children(): actor.feet_marker = actor.get_node("FeetMarker")
		player.test_map = map
		state.current_map = map
		map.encounter_area_id = ""
		root.add_child(map)
		player.map_layers_initialized = true
		player.map_layers_owner = map
		player.collision_tilemap = map.get_node("Tiles/Collision")
		player.water_tilemap = map.get_node("Tiles/Water")
		check(player.restore_land_mount("cyclizar"), "owned licensed mount restores on route")
		check(not player.toggle_land_mount() and player.get_active_land_mount_id() == "cyclizar", "direct toggle cannot dismount")
		check(not player.request_land_mount_toggle() and player.get_active_land_mount_id() == "cyclizar", "hotkey/UI cannot dismount")
		check(not player.start_surf() and player.get_active_land_mount_id() == "cyclizar", "Surf cannot clear the required land mount")
		check(not player.can_fish_here(), "fishing cannot replace riding on these routes")
		player._on_mount_loadout_changed("land","unknown")
		check(player.get_active_land_mount_id() == "cyclizar", "invalid loadout cannot clear riding")
		var bridge_cell := Vector2i(17,24) if number == 16 else Vector2i(17,12)
		for direction in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]:
			player.is_moving = false
			player.position = point(bridge_cell)
			check(player.call("_try_start_move",direction) == (direction != Vector2.UP), "real movement permits only left, right and down on bridge")
		player.is_moving = false
		var plaza_cell := Vector2i(17,14) if number == 16 else Vector2i(17,60)
		player.position = point(plaza_cell)
		check(player.call("_try_start_move",Vector2.UP), "north movement still works off bridge")
		player.is_moving = false
		if number == 17:
			_check_platform_escape(player)
			player.is_moving = false
			player.position = point(Vector2i(15,31))
			check(not player.call("_try_start_move",Vector2.UP), "north movement stays blocked on the bridge beside the platform")
			check(map.get_node("Exits/ToRoute16").get_travel_block_reason(player) == "ui.cycling_road.north_blocked", "northward route transfer cannot bypass bridge rule")
		player._finish_land_mount_activity() # System resets/battle teardown remain possible.
		check(not player.is_land_mount_activity_active(), "system reset can clear transient riding")
		map.free()
	var east := (load("res://scenes/overworld/kanto/routes/kanto_route_16_east.tscn") as PackedScene).instantiate()
	var gate := (load("res://scenes/overworld/kanto/transition_buildings/route_16_gate.tscn") as PackedScene).instantiate()
	player.test_map = east
	check(player.restore_land_mount("cyclizar") and player.toggle_land_mount(), "Route 16 East retains normal mounting and dismounting")
	check(east.get_node("Exits/ToRoute16Gate").get_travel_block_reason(player).is_empty(), "gate can be entered on foot")
	check(not gate.land_mount_required_entry, "interior does not require riding")
	for exit_node in [gate.get_node("Exits/ToWest")]:
		check(exit_node.get_travel_block_reason(player) == "ui.cycling_road.mount_required", "gate/road entry rejects rider on foot")
		player.land_mount_activity_active = true
		player.active_mount_id = "cyclizar"
		check(exit_node.get_travel_block_reason(player).is_empty(), "gate/road entry accepts mounted rider")
		player.land_mount_activity_active = false
		player.active_mount_id = ""
	check(gate.get_node("Exits/ToEast").get_travel_block_reason(player).is_empty(), "unmounted visitor can return to Route 16 East")
	check(east.allows_land_mount_dismount() and east.northbound_blocked_regions.is_empty(), "East map has no road restrictions")
	# An unmounted approach invokes the bound guard instead of starting travel.
	player.land_mount_activity_active = false
	var presenter := DenialPresenter.new()
	root.add_child(presenter)
	presenter.add_to_group("world_transition_denial_presenters")
	var exit_node: Area2D = load("res://scripts/world/map_exit.gd").new()
	exit_node.requires_land_mount = true
	root.add_child(exit_node)
	for transition in ["kanto_route_16_gate__to_route16","kanto_route_17_18_gate__to_route17"]:
		presenter.checked_transition = transition
		exit_node.transition_id = transition
		await exit_node.call("_on_body_entered",player)
		check(presenter.received.get("reasonCode") == "LAND_MOUNT_REQUIRED", "road guard blocks unmounted approach")
		check(presenter.received.get("dialogueId") == "cycling_road_mount_required", "road guard explains riding requirement")
		check(not exit_node.is_transitioning, "guard dialogue leaves gate usable")
		presenter.received.clear()
	var overlay := OverlayProbe.new()
	root.add_child(overlay)
	overlay.add_to_group("ui_overlay")
	exit_node.movement_blocked = true
	await exit_node.call("_on_body_entered",player)
	check(overlay.message == root.get_node("LocalizationManager").text("ui.cycling_road.north_blocked"), "northbound gate denial shows the localized system message")
	check(not exit_node.is_transitioning, "local travel denial does not start a transfer")
	overlay.free()
	exit_node.free()
	presenter.free()
	var resumed := (load("res://scenes/overworld/kanto/routes/kanto_route_16.tscn") as PackedScene).instantiate()
	player.test_map = resumed
	state.current_map = resumed
	var world = load("res://tests/fixtures/cycling_road_world_probe.gd").new()
	world.player = player
	var arrival := {"spawnMarker":"FromRoute16Gate","mountId":"cyclizar","facingDirection":"left","teleportAcknowledgementRequired":true}
	var result: Dictionary = world.call("_position_player_at_authorized_teleport_state",resumed,arrival)
	check(result.success and player.get_active_land_mount_id() == "cyclizar", "trusted pending spawn restores riding after reconnect")
	player._finish_land_mount_activity()
	arrival.mountId = null
	world.call("_position_player_at_authorized_teleport_state",resumed,arrival)
	check(not player.is_land_mount_activity_active(), "forced teleport without trusted mount stays on foot")
	arrival.erase("spawnMarker")
	arrival.mountId = "cyclizar"
	arrival.position = {"x":1040,"y":464}
	world.call("_position_player_at_saved_state",resumed,arrival)
	check(player.get_active_land_mount_id() == "cyclizar", "trusted pending saved coordinates restore riding")
	player._finish_land_mount_activity()
	world.free()
	resumed.free()
	state.current_map = previous
	settings.set_selected_mount_id("land",previous_mount)
	east.free()
	gate.free()
	player.free()
	if not failed: print("PASS Cycling Road: bridge direction, mount toggle, gate entry and unchanged East map")
	quit(1 if failed else 0)
func point(cell: Vector2i) -> Vector2:
	return Vector2(cell)*32+Vector2(16,16)
func check(ok: bool,message: String) -> void:
	if not ok:
		failed = true
		push_error(message)


func _check_platform_escape(player: Node) -> void:
	# Build directed edges through the actual mounted player's movement rules,
	# then prove every walkable platform tile can reach a bridge landing.
	var cells := {}
	for y in range(24,34):
		for x in range(8,19):
			if x >= 15 and (y < 26 or y > 31): continue
			var cell := Vector2i(x,y)
			if player.can_move_to(point(cell)):
				cells[cell] = true
	var incoming := {}
	for cell: Vector2i in cells:
		incoming[cell] = []
	for cell: Vector2i in cells:
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i = cell+direction
			if not cells.has(next): continue
			player.is_moving = false
			player.position = point(cell)
			if player.call("_try_start_move",Vector2(direction)):
				incoming[next].append(cell)
	var queue: Array[Vector2i] = []
	var reached := {}
	for cell: Vector2i in cells:
		if cell.x >= 15:
			queue.append(cell)
			reached[cell] = true
	var index := 0
	while index < queue.size():
		var cell := queue[index]
		index += 1
		for previous: Vector2i in incoming[cell]:
			if not reached.has(previous):
				reached[previous] = true
				queue.append(previous)
	for cell: Vector2i in cells:
		check(reached.has(cell), "mounted rider can leave platform tile %s" % cell)
	for corner in [Vector2i(8,33),Vector2i(13,33)]:
		check(cells.has(corner) and reached.has(corner), "both lower platform corners have an escape")
	player.is_moving = false
	player.position = point(Vector2i(13,33))
	check(player.call("_try_start_move",Vector2.UP), "rider can climb out of reported lower-right corner")
	player.is_moving = false
