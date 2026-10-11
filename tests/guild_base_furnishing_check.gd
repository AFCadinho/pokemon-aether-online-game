extends SceneTree

const Catalog := preload("res://scripts/world/guild_base_furniture_catalog.gd")
const Furniture := preload("res://scripts/world/guild_base_furniture.gd")
const Blocking := preload("res://scripts/world/map_character_blocking.gd")
var failed := false

class ServiceStub extends Node:
	var state: Dictionary
	var acquired := 0
	var released := 0
	var renew_fails := false
	var save_fails := false
	var saves := 0
	var updates: Array = []
	func base_furniture(_room: String) -> Dictionary:
		return {"success": true, "state": state.duplicate(true)}
	func base_furniture_lease(_room: String, action: String, _token := "") -> Dictionary:
		if action == "acquire":
			acquired += 1
		if action == "release":
			released += 1
		if action == "renew" and renew_fails:
			return {"success": false, "status": 409, "detail": {"code": "guild_base_furniture_lease_expired"}}
		return {"success": true, "state": state.merged({"leaseToken": "test-lease"})}
	func save_base_furniture(_room: String, token: String, revision: int, items: Array) -> Dictionary:
		saves += 1
		assert(token == "test-lease" and revision == state.revision)
		if save_fails:
			return {"success": false, "status": 409, "detail": {"code": "guild_base_furniture_revision_conflict"}}
		state.items = items.duplicate(true)
		state.revision += 1
		state.inventory = {}
		for spec: Dictionary in preload("res://scripts/world/guild_base_furniture_catalog.gd").load_data().items:
			state.inventory[spec.id] = spec.starterQuantity
		for value: Dictionary in state.items:
			state.inventory[value.furnitureId] -= 1
		return {"success": true, "state": state.duplicate(true)}
	func base_furniture_editors() -> Dictionary:
		return {"success": true, "state": {"members": [{"userId": 1, "name": "Leader", "isLeader": true, "allowed": true}, {"userId": 2, "name": "Member", "isLeader": false, "allowed": false}]}}
	func set_base_furniture_editor(user_id: int, allowed: bool) -> Dictionary:
		updates.append([user_id, allowed])
		return {"success": true}

class PlayerStub extends Node2D:
	var resets := 0
	func get_persistent_world_position() -> Vector2:
		return global_position
	func reset_movement_state() -> void:
		resets += 1

class WorldStub extends Node2D:
	var player: Node2D
	var synced := false
	var is_in_battle := false
	func is_map_transition_in_progress() -> bool:
		return false
	func sync_player_position_for_world_action() -> Dictionary:
		synced = get_node("/root/GameState").is_overworld_input_locked()
		return {"success": true}
	func save_current_player_state() -> void:
		pass

func _init() -> void:
	_run.call_deferred()

func _item(id: String, key: String, x: int, y: int, extra := {}) -> Dictionary:
	var spec := Catalog.item(key)
	return {"id": id, "furnitureId": key, "x": x, "y": y, "width": spec.footprint[0], "height": spec.footprint[1], "parentId": null, "slot": null}.merged(extra, true)

func _run() -> void:
	var game := root.get_node("GameState")
	var world := WorldStub.new()
	root.add_child(world)
	world.add_to_group("world")
	world.player = PlayerStub.new()
	world.player.name = "Player"
	world.add_child(world.player)
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	world.player.add_child(camera)
	root.size = Vector2i(1024, 576)
	var service := ServiceStub.new()
	root.add_child(service)
	var map: Node2D = load("res://scenes/overworld/kanto/guild_base/left_room.tscn").instantiate()
	map.configure_guild_base_instance("guild_base:kanto_vermilion_city:7:left_room")
	# Keep the real room and collision; substitute only the authenticated API.
	world.add_child(map)
	map.furnishing_editor.free()
	var editor: Node = load("res://tests/support/guild_base_furnishing_editor_probe.gd").new()
	editor.room = map
	editor.guild_service = service
	map.add_child(editor)
	game.current_map = map
	world.player.position = Vector2(592, 272)
	var table := _item("table", "table_small", 5, 10)
	var flowers := _item("flowers", "flowers", 0, 0, {"parentId": "table", "slot": 0})
	var wire: Node = load("res://tests/support/guild_base_furniture_wire_probe.gd").new()
	root.add_child(wire)
	var parsed_items: Array = JSON.parse_string(JSON.stringify([table, flowers]))
	await wire.save_base_furniture("left_room", "token", 3, parsed_items)
	_check(wire.wire_method == HTTPClient.METHOD_PUT and wire.wire_path == "/game/guild-bases/rooms/left_room/furniture", "saving uses the authenticated room endpoint")
	_check(not wire.wire_body.contains("5.0") and not wire.wire_body.contains("3.0") and not wire.wire_body.contains("0.0"), "server-loaded coordinates and decoration slots serialize as strict integers")
	await wire.set_base_furniture_editor(2, true)
	_check(wire.wire_path.ends_with("/editors/2") and wire.wire_body == '{"allowed":true}', "editor rights serialize as an explicit boolean")
	wire.free()
	service.state = {"guildId": 7, "roomKey": "left_room", "revision": 0, "items": [table, flowers], "inventory": {}, "canEdit": true, "canManageEditors": true}
	for spec: Dictionary in Catalog.load_data().items:
		service.state.inventory[spec.id] = spec.starterQuantity - (1 if spec.id in ["table_small", "flowers"] else 0)
	if "--screenshot" in OS.get_cmdline_user_args():
		# Visual QA starts directly in the editor, without opening native test
		# dialogs first. Embed the dropdown in the captured game viewport.
		root.gui_embed_subwindows = true
		root.mode = Window.MODE_WINDOWED
		root.size = Vector2i(1440, 960)
		root.grab_focus()
		service.state.items.append(_item("plant", "plant", 15, 7))
		service.state.items.append(_item("rug", "red_carpet", 9, 9, {"width": 5, "height": 4}))
		service.state.inventory.plant -= 1
		service.state.inventory.red_carpet -= 1
		await process_frame
		await editor.refresh()
		await editor.begin_editing()
		await _capture_preview("preview")
		_click(editor.category.get_global_rect().get_center())
		await _capture_preview("dropdown")
		editor.category.get_popup().hide()
		editor.category.select(5)
		editor._populate_catalog()
		editor._catalog_selected(0)
		await _capture_preview("rugs")
		await editor._show_rights()
		await _capture_preview("rights")
		editor.rights_window.close_requested.emit()
		await process_frame
		await editor.finish_editing()
		await _capture_preview("action")
		game.current_map = null
		world.free()
		service.free()
		print("guild_base_furnishing_preview: PASS")
		quit()
		return
	await process_frame
	await editor.refresh()
	_check(Catalog.validate(map, service.state.items) == "", "table and its decoration form a valid layout")
	var mirrored: Node2D = load("res://scenes/overworld/kanto/guild_base/right_room.tscn").instantiate()
	root.add_child(mirrored)
	_check(Catalog.validate(mirrored, [table, flowers]) == "", "the same reusable furniture works in the mirrored side room")
	_check(Catalog.validate(mirrored, [_item("door", "stool", 4, 8)]) == "overlap", "the mirrored room keeps its own entrance clear")
	mirrored.free()
	var container: Node = map.get_node("Entities/Furniture")
	var placed: Node2D = container.get_child(0)
	_check(placed.get_child_count() == 2, "tabletop decoration is parented to its table")
	_check(Blocking.is_position_blocked_by_character(map, Vector2(176, 336)), "furniture participates in the player's existing movement blockers")
	_check(not Blocking.is_position_blocked_by_character(map, Vector2(176, 304)), "the raised artwork does not block the tile above the footprint")
	for spec: Dictionary in Catalog.load_data().items:
		var scene: Node2D = load(str(spec.scenePath)).instantiate()
		_check(scene.furniture_id == str(spec.id) and scene.get_node("Visual").get_used_cells().size() > 0, "catalog scene loads: " + str(spec.id))
		scene.free()
	var rug := _item("rug", "red_carpet", 9, 9, {"width": 5, "height": 4})
	var resized := Furniture.instantiate_placement(map, rug, [])
	_check(resized.get_node("Visual").get_used_cells().size() == 20 and not resized.blocks_world_position(Vector2(304, 304)), "resized carpets remain walkable and use nine-slice artwork")
	resized.free()
	_check(Catalog.validate(map, [_item("door", "stool", 18, 8)]) == "overlap", "the room doorway stays clear")
	_check(Catalog.validate(map, [_item("wall", "fireplace", 5, 4), _item("picture", "painting", 5, 4)]) == "overlap", "wall decorations cannot overlap the fireplace")
	editor.authenticated = false
	await editor.begin_editing()
	_check(not editor.building and service.acquired == 0, "unauthenticated clients cannot start editing")
	editor.authenticated = true
	await editor.begin_editing()
	_check(editor.building and service.acquired == 1 and world.synced, "entering first locks movement and saves the player's position before acquiring a lease")
	_check(editor.panel.visible and camera.zoom.x != 1, "editing opens the catalog and fits the room camera")
	var hud: CanvasLayer = await _check_pointer_input(editor, map, service)
	root.size_changed.emit()
	camera.zoom = Vector2(9, 9)  # A later Player viewport listener reapplies its baseline.
	await process_frame
	_check(camera.zoom.x != 9, "viewport resizing reapplies the editor camera after player listeners")
	editor._catalog_selected(0)
	var ghost_value: Dictionary = editor._placement_at(Vector2(304, 336))
	var ghost := Furniture.instantiate_placement(map, ghost_value, service.state.items, true)
	_check(editor._candidate_error(ghost_value) == "" and not ghost.blocks_world_position(Vector2(304, 336)), "valid green placement previews do not block movement")
	ghost.free()
	_check(editor._candidate_error(editor._placement_at(world.player.position)) != "", "placement preview rejects a player or the reserved entrance")
	editor._clear_selection()
	editor._select_at(Vector2(168, 300))
	_check(editor.selected_instance == "table", "selecting the tabletop selects its table")
	var moved := table.duplicate(true)
	moved.x = 9
	await editor._commit(editor._candidate_items(moved))
	placed = container.get_child(0)
	_check(placed.position.x == 288 and placed.get_child(1).placement.parentId == "table", "moving a table keeps its decoration attached")
	_check(service.state.inventory.table_small == 5, "moving does not consume another copy")
	var old_count: int = service.state.items.size()
	service.save_fails = true
	await editor._commit([])
	_check(service.state.items.size() == old_count and container.get_child_count() == 1 and editor.errors == 1, "a rejected save restores the server layout")
	service.save_fails = false
	editor._select_at(Vector2(296, 300))
	await editor._take_back()
	_check(service.state.items.is_empty() and service.state.inventory.table_small == 6 and service.state.inventory.flowers == 12, "taking a table back also returns its decorations to shared storage")
	await editor._show_rights()
	var checkboxes: Node = editor.rights_window.get_child(0).get_child(0)
	_check(checkboxes.get_child_count() == 2 and checkboxes.get_child(0).disabled, "rights window lists guild members and locks the leader's right")
	await editor._change_right({"userId": 2}, true, checkboxes.get_child(1))
	_check(service.updates == [[2, true]], "only the selected member's explicit decorating right changes")
	editor.rights_window.close_requested.emit()
	await process_frame
	var done_button: Button = editor.done_button
	_click(done_button.get_global_rect().get_center())
	await process_frame
	_check(not editor.building and service.released == 1 and not game.is_overworld_input_locked() and camera.zoom == Vector2.ONE, "leaving releases the lease, input lock and camera override")
	var hud_clicks: Array = []
	hud.get_child(0).gui_input.connect(func(_event: InputEvent): hud_clicks.append(true))
	_click(Vector2(40, 180))
	_check(not hud_clicks.is_empty(), "Done returns normal mouse input to the underlying HUD")
	await editor.begin_editing()
	service.renew_fails = true
	await editor._renew_lease()
	_check(not editor.building and not game.is_overworld_input_locked(), "lease expiry closes the editor and releases movement")
	var foreign: Dictionary = service.state.merged({"guildId": 8, "revision": 99}, true)
	editor.apply_state(foreign)
	_check(editor.state.guildId == 7 and editor.state.revision < 99, "another guild's state never renders")
	service.renew_fails = false
	await editor.begin_editing()
	editor.apply_state(service.state.merged({"canEdit": false}, true))
	_check(not editor.building and not editor.enter_button.visible, "revoked permissions close editing immediately")
	game.current_map = null
	world.free()
	hud.free()
	service.free()
	await process_frame
	print("guild_base_furnishing_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _capture_preview(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/guild-base-furnishing-%s.png" % name)

func _click(position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = position
	event.pressed = true
	root.push_input(event, true)
	event.pressed = false
	root.push_input(event, true)

func _check_pointer_input(editor: Node, map: Node2D, service: ServiceStub) -> CanvasLayer:
	# Use the actual HUD's full-screen Control, which consumes world clicks.
	# Its other children and bootstrap script are irrelevant to mouse routing.
	var overlay: CanvasLayer = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	var hud_control: Control = overlay.get_node("Control")
	overlay.remove_child(hud_control)
	for child: Node in hud_control.get_children():
		child.free()
	var hud := CanvasLayer.new()
	hud.layer = overlay.layer
	overlay.free()
	root.add_child(hud)
	hud.add_child(hud_control)
	await process_frame
	_check(hud_control.mouse_filter == Control.MOUSE_FILTER_STOP, "regression fixture retains the real HUD's click-catching surface")
	editor._catalog_selected(0)
	var new_id: String = editor.pending_id
	var before := service.saves
	var point: Vector2 = root.canvas_transform * map.to_global(Vector2(304, 336))
	_click(root.canvas_transform * map.to_global(Vector2(592, 272)))
	_check(service.saves == before, "a real viewport click cannot place furniture in the reserved entrance")
	_click(point)
	await process_frame
	_check(service.saves == before + 1 and not editor._placement_by_id(new_id).is_empty(), "a real viewport click places exactly one piece despite the HUD")
	if editor._placement_by_id(new_id).is_empty():
		editor._clear_selection()
		return hud
	editor._start_selecting()
	_click(root.canvas_transform * map.to_global(Vector2(304, 300)))
	_check(editor.selected_instance == new_id, "a real viewport click selects an existing piece")
	_click(root.canvas_transform * map.to_global(Vector2(400, 336)))
	await process_frame
	_check(int(editor._placement_by_id(new_id).x) == 12 and service.saves == before + 2, "a real viewport click moves the selected piece")
	editor._start_selecting()
	_click(root.canvas_transform * map.to_global(Vector2(400, 300)))
	await editor._take_back()
	editor._catalog_selected(0)
	before = service.saves
	_click(editor.panel.get_global_rect().position + Vector2(15, 200))
	_check(service.saves == before, "clicking the catalog panel never places furniture behind it")
	var modal_layer := CanvasLayer.new()
	modal_layer.layer = editor.layer + 1
	var blocker := Control.new()
	blocker.position = point - Vector2(40, 40)
	blocker.size = Vector2(80, 80)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(modal_layer)
	modal_layer.add_child(blocker)
	await process_frame
	_click(point)
	_check(service.saves == before, "another modal window blocks placement through it")
	modal_layer.free()
	await process_frame
	var touch := InputEventScreenTouch.new()
	touch.position = point
	touch.pressed = true
	new_id = editor.pending_id
	root.push_input(touch, true)
	touch.pressed = false
	root.push_input(touch, true)
	await process_frame
	_check(service.saves == before + 1 and not editor._placement_by_id(new_id).is_empty(), "a real viewport touch places exactly one piece")
	if not editor._placement_by_id(new_id).is_empty():
		editor._start_selecting()
		_click(root.canvas_transform * map.to_global(Vector2(304, 300)))
		await editor._take_back()
	editor._clear_selection()
	return hud
