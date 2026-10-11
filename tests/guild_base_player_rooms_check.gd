extends SceneTree

const Menu := preload("res://scripts/ui/guild_base_room_directory.gd")
var failed := false

class PlayerStub extends Node2D:
	var last_direction := Vector2.UP
	func get_interaction_positions() -> Array[Vector2]:
		return [global_position]


class GuildStub extends Node:
	var directory: Dictionary
	var travel_floor := -1
	func base_room_directory(_for_lift := false) -> Dictionary:
		return {"success": true, "state": directory}
	func base_lift_travel(floor: int) -> Dictionary:
		travel_floor = floor
		return {"success": true, "state": {"mapId": "guild_base:kanto_vermilion_city:7:player_floor_2"}}

class WorldStub extends Node2D:
	var synced := false
	var applied := false
	var unlocked_after_apply := false
	var map: Node
	func sync_player_position_for_world_action() -> Dictionary:
		synced = true
		return {"success": true}
	func begin_authorized_teleport(_save_position: bool, _lock_input: bool) -> Dictionary:
		get_node("/root/GameState").acquire_overworld_input_lock(&"test_teleport")
		return {"success": true}
	func apply_authorized_teleport_state(state: Dictionary) -> Dictionary:
		applied = state.get("mapId", "").ends_with("player_floor_2")
		map.free()
		var game := get_node("/root/GameState")
		game.release_overworld_input_lock(&"test_teleport")
		unlocked_after_apply = not game.is_overworld_input_locked()
		return {"success": true}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var game := root.get_node("GameState")
	var room: Node2D = load("res://scenes/overworld/kanto/guild_base/player_room.tscn").instantiate()
	root.add_child(room)
	room.configure_guild_base_instance("guild_base:kanto_vermilion_city:7:player_room_7")
	_check(room.floor_number == 2 and room.room_number == 3 and room.guild_id == 7, "room index 7 resolves to floor 2, local room 3")
	_check(room.get_node("Visual").get_child_count() == 4 and room.get_node("Visual/Objects").get_used_cells().is_empty(), "the personal room preserves the empty four-layer TMX visual")
	_check(room.room_size == Vector2i(19,16) and room.is_walkable_tile(Vector2i(13,11)), "the enlarged template exposes the additional authored floor space")
	var arrival: Marker2D = room.get_node("Spawns/FromFloor")
	var exit: Area2D = room.get_node("Exits/ToFloor")
	_check(arrival.position == Vector2(304,400) and exit.position == Vector2(304,432), "arrival and return door align with the relocated threshold")
	_check(not exit.contains_world_position(arrival.position), "arriving does not immediately trigger the return door")
	_check(room.get_node("FloorVisibilityMask").get_active_floor_region() == Rect2(128,32,352,416), "the camera mask covers the enlarged room")
	var collision: TileMapLayer = room.find_map_tilemap_layer("Collision")
	_check(collision.get_cell_source_id(Vector2i(9,12)) == -1 and collision.get_cell_source_id(Vector2i(9,13)) == -1, "the arrival and lower exit have clear physical floor")
	for point: Vector2i in [Vector2i(4,4),Vector2i(14,4),Vector2i(4,12),Vector2i(14,12),Vector2i(3,7),Vector2i(9,14)]:
		_check(collision.get_cell_source_id(point) != -1, "corners and room boundaries block walking " + str(point))
	_check(room.get_node("FloorVisibilityMask").constrain_camera_to_active_floor and room.furnishing_editor == null, "personal room has a camera mask and awaits its own furnishing system")
	for key: String in ["elevator", "elevator_cabin"]:
		var map: Node2D = load("res://scenes/overworld/kanto/guild_base/" + key + ".tscn").instantiate()
		root.add_child(map)
		var npc: Node2D = map.get_node("Entities/NPCs/Attendant")
		_check(npc.position == (Vector2(336,592) if key == "elevator" else Vector2(176,240)), "attendant stands beside the passage: " + key)
		_check(not npc._loads_pickpocket_profile_from_npc_metadata() and not npc._prefetches_dialogue_metadata_on_approach(), "functional attendant uses local UI and skips dialogue metadata")
		_check(preload("res://scripts/world/map_character_blocking.gd").is_position_blocked_by_character(map, npc.global_position), "the attendant participates in ordinary NPC movement blocking")
		var approach := PlayerStub.new()
		map.add_child(approach)
		approach.position = Vector2(336,656) if key == "elevator" else Vector2(240,240)
		approach.last_direction = Vector2.UP if key == "elevator" else Vector2.LEFT
		_check(npc._is_player_facing_npc(approach), "the attendant can be addressed across the counter or beside the cabin entrance")
		_check(not preload("res://scripts/world/map_character_blocking.gd").is_position_blocked_by_character(map, approach.global_position), "the interaction approach stays clear of NPC movement blocking")
		approach.free()
		var bounds: Rect2 = map.get_node("FloorVisibilityMask").get_active_floor_region()
		_check(npc.position.x + npc.nameplate.position.x + npc.nameplate_background.offset_left >= bounds.position.x, "the service name stays visible inside the room mask")
		_check(npc.npc_sprite_frames.has_animation("idle_down") and not npc.pickpocket_enabled, "attendant uses an adult sprite and cannot be pickpocketed")
		if key == "elevator_cabin":
			map.configure_guild_base_instance("guild_base:kanto_vermilion_city:7:elevator_cabin_2")
			_check(map.floor_number == 2, "returning to the cabin retains the floor context")
		map.free()
	var mine := {"userId": 7, "name": "Adinho", "floor": 2, "room": 3}
	var data := {"floors": [1,2], "currentFloor": 0, "myRoom": mine, "rooms": [mine, {"userId": 8, "name": "Misty", "floor": 1, "room": 2}, {"userId": 9, "name": "Adinho Junior", "floor": 2, "room": 4}]}
	var directory := Menu.new()
	root.add_child(directory)
	directory.open(data)
	_check(game.is_overworld_input_locked(), "the directory owns a movement input lock")
	_check(directory._list.get_child_count() == 3, "the directory lists Guild member room addresses")
	directory._search.text = "  mIsTy "
	directory._search_changed(directory._search.text)
	_check(directory._list.get_child_count() == 1 and "Misty" in directory._list.get_child(0).get_child(0).text, "player search ignores case and surrounding whitespace")
	directory._show_my_room()
	_check(directory._list.get_child_count() == 1 and "Adinho Junior" not in directory._list.get_child(0).get_child(0).text, "find my room selects the authenticated member rather than partial name matches")
	directory._search.text = "Nobody"
	directory._search_changed("Nobody")
	_check(directory._list.get_child(0) is Label, "empty searches show an explicit message")
	game.acquire_overworld_input_lock(&"other_window")
	directory._finish(-1)
	await process_frame
	_check(game.is_overworld_input_locked(), "closing the directory preserves another window’s input lock")
	game.release_overworld_input_lock(&"other_window")
	_check(not game.is_overworld_input_locked(), "closing the last window restores movement")
	var lift := Menu.new()
	root.add_child(lift)
	lift.open(data, true)
	_check(lift._floor_buttons.size() == 3 and lift._travel.disabled, "the lift offers ground and allocated floors and requires a selection")
	lift._show_my_room()
	_check(lift._selected_floor == 2 and not lift._travel.disabled, "find my room selects the correct lift destination")
	var selections: Array = []
	lift.resolved.connect(func(floor: int): selections.append(floor))
	lift._finish_selected()
	await process_frame
	_check(selections == [2] and not game.is_overworld_input_locked(), "lift selection resolves once and releases its window lock")
	var many_data := data.duplicate(true)
	many_data.floors = range(1, 101)
	many_data.myRoom = {"userId": 7, "name": "Adinho", "floor": 87, "room": 3}
	many_data.rooms = [many_data.myRoom, {"userId": 8, "name": "Misty", "floor": 63, "room": 2}]
	var many := Menu.new()
	root.add_child(many)
	many.open(many_data, true)
	await process_frame
	await process_frame
	_check(many._floor_grid.get_child_count() == 100 and many._floor_grid.columns > 1, "one hundred floors form a compact multi-column grid")
	_check(many._floor_scroll.get_v_scroll_bar().max_value > many._floor_scroll.size.y, "large Guilds scroll inside a bounded floor picker")
	many._search.text = " 87 "
	many._filter_floors(many._search.text)
	_check(many._floor_grid.get_child_count() == 1 and many._floor_buttons.has(87), "exact floor search avoids matching unrelated floor numbers")
	many._submit_floor_search("87")
	_check(many._selected_floor == 87 and many._travel.has_focus(), "enter selects an available floor and focuses the travel action")
	many._search.text = "mIsTy"
	many._filter_floors("mIsTy")
	_check(many._floor_grid.get_child_count() == 1 and many._floor_buttons.has(63), "player-name search finds the assigned floor")
	_check(many._destination.text == many._floor_label(87), "the footer retains the selected destination while filtering other floors")
	many._search.text = "no such player"
	many._filter_floors(many._search.text)
	_check(many._empty_floors.visible, "unmatched searches show a clear empty state")
	many._search.grab_focus()
	many._submit_floor_search("9999")
	_check(many._search.has_focus() and many._selected_floor == 87, "enter on an unavailable floor does not focus travel to a previous destination")
	many._show_my_room()
	await process_frame
	await process_frame
	await process_frame
	_check(many._search.text.is_empty() and many._selected_floor == 87 and many._floor_scroll.scroll_vertical > 0, "find my room clears filters and reveals a distant assigned floor")
	many._reveal_floor(0)
	_check(many._selected_floor == 0 and many._destination.text == many._floor_label(0), "ground-floor shortcut remains available for large Guilds")
	many._select_floor(101)
	_check(many._selected_floor == 0, "the picker rejects unavailable destinations")
	many._finish(-1)
	await process_frame
	_check(not game.is_overworld_input_locked(), "closing the scalable picker releases its input lock")
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var text: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/" + locale + ".json"))
		for key: String in ["directory_title", "lift_title", "my_room", "address", "room_title", "floor_search", "no_floors", "travel"]:
			_check(text.has("ui.guild_base.rooms." + key), "room UI copy exists in " + locale + ": " + key)
	# Exercise the real NPC handoff. Applying the transition destroys the source
	# NPC, which must not leave its legacy movement lock behind.
	var world := WorldStub.new()
	root.add_child(world)
	world.add_to_group("world")
	var service := GuildStub.new()
	service.directory = data
	root.add_child(service)
	var cabin: Node2D = load("res://scenes/overworld/kanto/guild_base/elevator_cabin.tscn").instantiate()
	world.map = cabin
	var attendant: Node = cabin.get_node("Entities/NPCs/Attendant")
	attendant.guild_service = service
	world.add_child(cabin)
	var player := PlayerStub.new()
	world.add_child(player)
	attendant._start_manual_interaction(player)
	await process_frame
	await process_frame
	var active_menu: Node
	for child: Node in world.get_children():
		if child.get_script() == Menu:
			active_menu = child
	_check(world.synced and active_menu != null, "real NPC saves the position before opening the lift menu")
	if active_menu != null:
		active_menu._select_floor(2)
		active_menu._finish_selected()
		await process_frame
		await process_frame
		_check(service.travel_floor == 2 and world.applied, "real NPC submits the selected floor and applies the authorized destination")
		_check(world.unlocked_after_apply, "destroying the source NPC during travel leaves no movement lock")
	world.free()
	service.free()
	room.free()
	await process_frame
	print("guild_base_player_rooms_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS ", message)
	else:
		failed = true
		push_error("FAIL " + message)
