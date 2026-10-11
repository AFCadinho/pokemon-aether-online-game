extends SceneTree

const Menu := preload("res://scripts/ui/guild_base_visit_menu.gd")
var failed := false

class VisitService extends Node:
	var directory: Dictionary = {"registrar": {"townId": "kanto_vermilion_city", "baseTownId": null, "guildId": null}, "guilds": [{"id": 7, "name": "Closed Guild", "policy": "request", "isOwn": false}, {"id": 8, "name": "Open Guild", "policy": "open", "isOwn": false}], "visit": {}}
	var hosts: Dictionary = {"policy": "request", "canManage": true, "requests": [{"userId": 9, "name": "Guest"}]}
	var requested := 0
	var answers: Array = []
	var policies: Array = []
	func base_visit_directory(_id: String, _query := "") -> Dictionary:
		return {"success": true, "state": directory.duplicate(true)}
	func base_visit_request(_id: String, guild_id: int) -> Dictionary:
		requested += 1
		directory.visit = {"guildId": guild_id, "status": "pending"}
		return {"success": true, "state": directory.visit.duplicate(true)}
	func base_visit_requests(_guild_id: int) -> Dictionary:
		return {"success": true, "state": hosts.duplicate(true)}
	func base_visit_answer(guild_id: int, user_id: int, accepted: bool) -> Dictionary:
		answers.append([guild_id, user_id, accepted])
		hosts.requests = []
		return {"success": true, "state": {"status": "approved" if accepted else "declined"}}
	func base_visit_policy(guild_id: int, value: String) -> Dictionary:
		policies.append([guild_id, value])
		hosts.policy = value
		return {"success": true, "state": {"policy": value}}

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
	service.free()
	await process_frame
	print("guild_base_visits_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)
