extends SceneTree

const Menu := preload("res://scripts/ui/guild_base_visit_menu.gd")
var failed := false

class NamingService extends Node:
	var identity := {"guildId": 7, "guildName": "AFC Squad", "roomNames": {"left_room": "Lounge", "right_room": "Training Hall"}, "canManage": true}
	var changes: Array = []
	func set_base_room_name(guild_id: int, room_key: String, value: String) -> Dictionary:
		changes.append([guild_id, room_key, value])
		identity.roomNames[room_key] = value.strip_edges()
		get_node("/root/GuildService")._cache_base_identity(identity)
		return {"success": true, "state": identity.duplicate(true)}
	func base_visit_requests(_guild_id: int) -> Dictionary:
		return {"success": true, "state": {"policy": "request", "canManage": true, "requests": []}}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	await process_frame
	var locale := root.get_node("LocalizationManager")
	var original_locale: String = locale.current_locale
	locale.set_locale("en")
	var game := root.get_node("GameState")
	var service := NamingService.new()
	root.add_child(service)
	var guild_service := root.get_node("GuildService")
	guild_service.current_guild = {"id": 99, "name": "Visitor's own Guild"}
	guild_service._cache_base_identity(service.identity)
	var rooms: Array[Node] = []
	for key: String in ["main_hall", "left_room", "right_room", "player_floor", "player_room"]:
		var room: Node = load("res://scenes/overworld/kanto/guild_base/%s.tscn" % key).instantiate()
		var token := "player_floor_2" if key == "player_floor" else "player_room_7" if key == "player_room" else key
		room.configure_guild_base_instance("guild_base:kanto_vermilion_city:7:" + token)
		root.add_child(room)
		rooms.append(room)
	_check(rooms[0].get_map_display_name() == "AFC Squad – Main Hall", "the main hall overrides the mask's generic label with the host Guild name")
	_check(rooms[1].get_map_display_name() == "AFC Squad – Lounge" and rooms[2].get_map_display_name() == "AFC Squad – Training Hall", "both side rooms display their own saved names")
	_check(rooms[3].get_map_display_name() == "AFC Squad – Floor 2" and rooms[4].get_map_display_name() == "AFC Squad – Floor 2 · Room 3", "personal floors and rooms retain their addresses with the Guild prefix")
	var menu := Menu.new()
	root.add_child(menu)
	menu.open(service, {"policy": "request", "canManage": true, "requests": []}, "", 7, service.identity)
	_check(menu.visitor_page.visible and not menu.names_page.visible, "manager starts with visitor management and a separate room-names page")
	menu._show_page("room_names")
	_check(menu.names_page.visible and not menu.visitor_page.visible and menu.name_fields.left_room.max_length == 40, "styled room-names page has bounded single-line fields")
	menu.name_fields.left_room.text = "  Café Lounge  "
	await menu._save_room_name("left_room")
	_check(service.changes == [[7, "left_room", "  Café Lounge  "]] and menu.name_fields.left_room.text == "Café Lounge", "saving a name targets the host's selected room and shows the server-normalized result")
	_check(rooms[1].get_map_display_name() == "AFC Squad – Café Lounge", "saved metadata updates the live room label without a map reload")
	menu.name_fields.left_room.text = ""
	await menu._save_room_name("left_room")
	_check(rooms[1].get_map_display_name() == "AFC Squad – Left Room", "clearing a name restores the localized default")
	if "--screenshot" in OS.get_cmdline_user_args():
		menu.name_fields.left_room.text = "Guild Lounge"
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/guild-base-room-names-menu.png")
	menu._finish({})
	await process_frame
	_check(not game.is_overworld_input_locked(), "closing management releases the modal lock")
	menu = Menu.new()
	root.add_child(menu)
	menu.open(service, {"policy": "request", "canManage": false, "requests": []}, "", 7, service.identity)
	menu._show_page("room_names")
	_check(not menu.name_fields.left_room.editable and menu.name_buttons[0].disabled, "regular members see names without edit rights")
	var count: int = service.changes.size()
	await menu._save_room_name("right_room")
	_check(service.changes.size() == count, "a nonleader cannot send a rename request")
	menu._finish({})
	await process_frame
	rooms[1].configure_guild_base_instance("guild_base:kanto_vermilion_city:8:left_room")
	_check(not "AFC Squad" in rooms[1].get_map_display_name(), "reusing a room template clears the previous Guild's identity")
	guild_service._cache_base_identity({"guildId": 8, "guildName": "Other Guild", "roomNames": {"left_room": "Library"}})
	_check(rooms[1].get_map_display_name() == "Other Guild – Library" and rooms[2].get_map_display_name() == "AFC Squad – Training Hall", "metadata and room names remain isolated between Guilds")
	locale.set_locale("nl")
	_check(rooms[0].get_map_display_name() == "AFC Squad – Hoofdhal", "default room labels respond to language changes")
	for language: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var text: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % language))
		for key: String in ["main_hall", "left_room", "right_room", "player_floor", "player_room"]:
			_check(text.has("ui.guild_base.location." + key), "localized room label: " + language + ":" + key)
	locale.set_locale(original_locale)
	for room: Node in rooms:
		room.free()
	service.free()
	await process_frame
	print("guild_base_room_names_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
