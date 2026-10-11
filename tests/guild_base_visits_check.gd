extends SceneTree

const Menu := preload("res://scripts/ui/guild_base_visit_menu.gd")
var failed := false

class VisitService extends Node:
	var directory: Dictionary = {"registrar": {"townId": "kanto_vermilion_city", "baseTownId": null, "guildId": null}, "guilds": [{"id": 7, "name": "Closed Guild", "policy": "request", "isOwn": false}, {"id": 8, "name": "Open Guild", "policy": "open", "isOwn": false}], "visit": {}}
	var hosts: Dictionary = {"policy": "request", "canManage": true, "requests": [{"userId": 9, "name": "Guest"}]}
	var requested := 0
	var answers: Array = []
	var policies: Array = []
	var requested_host := 0
	func base_visit_directory(_id: String, _query := "") -> Dictionary:
		return {"success": true, "state": directory.duplicate(true)}
	func base_visit_request(_id: String, guild_id: int) -> Dictionary:
		requested += 1
		directory.visit = {"guildId": guild_id, "status": "pending"}
		return {"success": true, "state": directory.visit.duplicate(true)}
	func base_visit_requests(_guild_id: int) -> Dictionary:
		requested_host = _guild_id
		return {"success": true, "state": hosts.duplicate(true)}
	func base_visit_answer(guild_id: int, user_id: int, accepted: bool) -> Dictionary:
		answers.append([guild_id, user_id, accepted])
		hosts.requests = []
		return {"success": true, "state": {"status": "approved" if accepted else "declined"}}
	func base_visit_policy(guild_id: int, value: String) -> Dictionary:
		policies.append([guild_id, value])
		hosts.policy = value
		return {"success": true, "state": {"policy": value}}
	func base_identity(guild_id: int) -> Dictionary:
		return {"success": true, "state": {"guildId": guild_id, "guildName": "Test Guild", "roomNames": {"left_room": "", "right_room": ""}}}

class WorldStub extends Node2D:
	var synced := false
	func sync_player_position_for_world_action() -> Dictionary:
		synced = true
		return {"success": true}

class PlayerStub extends Node2D:
	var last_direction := Vector2.UP
	func get_interaction_positions() -> Array[Vector2]:
		return [global_position]

func _init() -> void:
	_run.call_deferred()

func _select(menu: Node, index: int) -> void:
	menu.list.select(index)
	menu._selected(index)

func _run() -> void:
	root.size = Vector2i(1024, 768)
	await process_frame
	await process_frame
	var service := VisitService.new()
	root.add_child(service)
	var game := root.get_node("GameState")
	var menu := Menu.new()
	root.add_child(menu)
	menu.open(service, service.directory.duplicate(true), "guard")
	_check(game.is_overworld_input_locked(), "guard menu locks movement")
	_check(menu.list.item_count == 2 and menu.action.disabled, "guard starts with an unselected searchable directory")
	_select(menu, 0)
	if "--screenshot" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/guild-visits-guard-menu.png")
	await menu._act()
	_check(service.requested == 1 and menu.action.disabled, "request waits for inside-member approval and cannot be resent")
	await menu.refresh()
	_check(menu.selected_id == 7 and menu.action.disabled, "polling preserves selection and the waiting state")
	service.directory.visit.status = "approved"
	await menu.refresh()
	_check(not menu.action.disabled, "approval enables entry")
	var chosen: Array = []
	menu.resolved.connect(func(value: Dictionary): chosen.append(value))
	await menu._act()
	_check(chosen == [{"kind": "enter", "guildId": 7}], "approved request enters the selected host Guild")
	await process_frame
	_check(not game.is_overworld_input_locked(), "closing the guard menu releases its own input lock")
	menu = Menu.new()
	root.add_child(menu)
	menu.open(service, service.directory.duplicate(true), "guard")
	_select(menu, 1)
	chosen.clear()
	menu.resolved.connect(func(value: Dictionary): chosen.append(value))
	await menu._act()
	_check(chosen == [{"kind": "enter", "guildId": 8}] and service.requested == 1, "open bases enter without a request")
	await process_frame
	menu = Menu.new()
	root.add_child(menu)
	menu.open(service, service.hosts.duplicate(true), "", 7)
	_select(menu, 0)
	await menu._answer(true)
	_check(service.answers == [[7, 9, true]] and menu.list.item_count == 0, "inside member approves the specific visitor once")
	await menu._set_policy(1)
	_check(service.policies == [[7, "open"]], "leader can change visit policy")
	if "--screenshot" in OS.get_cmdline_user_args():
		service.hosts.requests = [{"userId": 9, "name": "Adinho"}, {"userId": 10, "name": "Misty"}]
		await menu.refresh()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/guild-visits-host-menu.png")
	menu._finish({})
	await process_frame
	service.hosts.canManage = false
	menu = Menu.new()
	root.add_child(menu)
	menu.open(service, service.hosts.duplicate(true), "", 7)
	_check(menu.policy.disabled, "regular members can answer requests without controlling policy")
	menu._finish({})
	await process_frame
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var texts: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))
		for key: String in ["guard_title", "host_title", "own_base", "policy_open", "policy_request", "status_pending", "status_approved", "badge", "notification", "error_no_host"]:
			_check(texts.has("ui.guild_base.visits." + key), "localized visit interface: " + locale + ":" + key)
		_check(texts.has("npc.guild_base.management"), "localized manager name: " + locale)
	# Exercise the physical counter and actual NPC interaction, including the
	# handoff between the legacy NPC lock and the visitor window's own lock.
	var world := WorldStub.new()
	root.add_child(world)
	world.add_to_group("world")
	var hall: Node2D = load("res://scenes/overworld/kanto/guild_base/main_hall.tscn").instantiate()
	hall.configure_guild_base_instance("guild_base:kanto_vermilion_city:17:main_hall")
	var manager: Node2D = hall.get_node("Entities/NPCs/Manager")
	manager.guild_service = service
	world.add_child(hall)
	var player := PlayerStub.new()
	hall.add_child(player)
	player.position = manager.position + Vector2(0, 64)
	_check(manager.service_kind == "management" and manager._is_player_facing_npc(player), "manager can be addressed at the authored lobby position")
	var collision: TileMapLayer = hall.find_map_tilemap_layer("Collision")
	var approach := Vector2i(player.position / 32)
	_check(hall.is_walkable_tile(approach) and collision.get_cell_source_id(approach) == -1, "manager interaction approach is clear of terrain")
	_check(preload("res://scripts/world/map_character_blocking.gd").is_position_blocked_by_character(hall, manager.global_position), "manager participates in NPC movement blocking")
	service.requested_host = 0
	service.hosts.canManage = true
	manager._start_manual_interaction(player)
	await process_frame
	await process_frame
	var management: Node
	for child: Node in world.get_children():
		if child.get_script() == Menu:
			management = child
	_check(world.synced and service.requested_host == 17 and management != null, "manager saves position and opens management for this base's owner")
	if management != null:
		_check(management.host and management.guild_id == 17 and not management.policy.disabled, "leader receives this base's visitor controls")
		if "--screenshot" in OS.get_cmdline_user_args():
			var camera := Camera2D.new()
			camera.position = Vector2(496, 304)
			hall.add_child(camera)
			management.hide()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/guild-management-npc.png")
		management._finish({})
		await process_frame
		await process_frame
		_check(not game.is_overworld_input_locked() and not manager.is_interacting, "closing manager controls releases both interaction locks")
	world.free()
	service.free()
	await process_frame
	print("guild_base_visits_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
