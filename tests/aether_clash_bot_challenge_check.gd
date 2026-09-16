extends Node

const MENU := preload("res://scripts/ui/aether_clash_bot_challenge_menu.gd")
const CAPTAIN := preload("res://scenes/npcs/aether_clash_bot_captain_npc.tscn")
var failed := false

class FakeGuildService extends GuildServiceNode:
	var requests: Array[Dictionary] = []
	var succeed := false
	func _authenticated_request(path: String, method: HTTPClient.Method, body: String) -> Dictionary:
		requests.append({"path": path, "method": method, "body": JSON.parse_string(body)})
		return {"success": succeed, "body": {"id": "fixture", "opponentKind": "bot_guild", "botCount": 20}}


func _ready() -> void:
	var menu := MENU.new()
	add_child(menu)
	menu.build({"available": false, "canChallenge": true, "maxBotCount": 20})
	_check(menu.dialog.confirm_button.disabled, "Unavailable runtime cannot be started")
	_check(menu.bot_count.max_value == 20, "Menu uses the server bot limit")
	menu.bot_count.get_line_edit().text = "20"
	menu.tier.select(1)
	menu.spectators.select(1)
	var settings: Dictionary = menu.selected_settings()
	_check(settings == {"botCount": 20, "tierId": "aether-uu", "spectatorAccess": "guilds_only"}, "Count, tier and spectator choice survive without a human-count field")
	menu.bot_count.get_line_edit().text = "999"
	_check(int(menu.selected_settings()["botCount"]) == 20, "Count is bounded")
	menu.bot_count.get_line_edit().text = "0"
	_check(int(menu.selected_settings()["botCount"]) == 1, "At least one bot is required")
	menu.queue_free()
	var unauthorized := MENU.new()
	add_child(unauthorized)
	unauthorized.build({"available": true, "canChallenge": false, "maxBotCount": 10})
	_check(unauthorized.dialog.confirm_button.disabled, "Non-manager cannot submit")
	unauthorized.queue_free()
	var enabled := MENU.new()
	add_child(enabled)
	enabled.build({"available": true, "canChallenge": true, "maxBotCount": 10})
	_check(not enabled.dialog.confirm_button.disabled, "Ready manager can submit")
	enabled.queue_free()

	var service := FakeGuildService.new()
	await service.create_aether_clash_bot_challenge(20, "aether-ou", "public")
	await service.create_aether_clash_bot_challenge(20, "aether-ou", "public")
	var first: Dictionary = service.requests[0]["body"]
	var second: Dictionary = service.requests[1]["body"]
	_check(first["requestId"] == second["requestId"], "Timeout retry keeps its idempotency key")
	var uuid_pattern := RegEx.new()
	uuid_pattern.compile("^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$")
	_check(uuid_pattern.search(str(first["requestId"])) != null, "Request key is a valid UUIDv4")
	_check(first.size() == 4 and not first.has("stakeAmount"), "No stakes, human count or client bot identity")
	service.succeed = true
	await service.create_aether_clash_bot_challenge(20, "aether-ou", "public")
	_check(service.pending_bot_request.is_empty(), "Success clears the retry key")
	service.bot_request_in_flight = true
	await service.create_aether_clash_bot_challenge(20, "aether-ou", "public")
	_check(service.requests.size() == 3, "Double click does not dispatch a second request")
	service.free()

	var captain := CAPTAIN.instantiate()
	add_child(captain)
	_check(not captain.call("_prefetches_dialogue_metadata_on_approach"), "Captain skips unrelated metadata")
	_check(not captain.call("_loads_pickpocket_profile_from_npc_metadata"), "Captain cannot be pickpocketed")
	_check(captain.get("mugshot") != null, "Captain resolves an existing portrait")
	captain.queue_free()
	var lobby := load("res://scenes/overworld/aether_clash/aether_clash_lobby.tscn").instantiate() as Node2D
	var placed := lobby.get_node("Entities/NPCs/ClashTrainingCaptain") as Node2D
	_check(placed.position == Vector2(1168, 1360), "NPC agrees with server interaction position")
	var collision := lobby.get_node("Tiles/Collision") as TileMapLayer
	var tile := Vector2i(36, 42)
	_check(collision.get_cell_source_id(tile) == -1, "Captain stands on a walkable tile")
	var reachable := false
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		reachable = reachable or collision.get_cell_source_id(tile + direction) == -1
	_check(reachable, "Captain has an accessible adjacent tile")
	lobby.free()
	for locale: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % locale))
		for key: String in ["title", "intro", "permission", "unavailable", "start", "close", "count", "format", "spectators", "public", "guilds_only", "accepted", "pending", "npc_required", "count_limit", "request_conflict"]:
			_check(not str(catalog.get("ui.clash_bot." + key, "")).is_empty(), "%s translates %s" % [locale, key])
	await get_tree().process_frame
	get_tree().quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
	else:
		print("PASS ", label)
