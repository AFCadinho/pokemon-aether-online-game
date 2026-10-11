extends SceneTree

var failed := false

class WorldStub extends Node2D:
	var begun := 0
	var departed := 0
	var applied: Array = []
	var available := true
	func begin_authorized_teleport() -> Dictionary:
		begun += 1
		if not available:
			return {"success": false, "error": "busy"}
		get_node("/root/GameState").acquire_overworld_input_lock(&"test_guild_travel")
		return {"success": true}
	func play_authorized_teleport_departure_effect() -> void:
		departed += 1
	func apply_authorized_teleport_state(state: Dictionary) -> Dictionary:
		applied.append(state)
		get_node("/root/GameState").release_overworld_input_lock(&"test_guild_travel")
		return {"success": true}

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	await process_frame
	var service: Node = root.get_node("GuildService")
	var original: Script = service.get_script()
	service.set_script(load("res://tests/support/guild_base_teleport_service_probe.gd"))
	var destination := {"mapId": "guild_base:kanto_vermilion_city:7:main_hall", "mapScenePath": "res://scenes/overworld/kanto/guild_base/main_hall.tscn", "position": {"x": 496, "y": 1168}}
	service.response = {"success": true, "body": {"state": destination}}
	var result: Dictionary = await service.teleport_to_base()
	_check(result.state == destination and service.requests == [["/game/guild-bases/teleport", HTTPClient.METHOD_POST, {}]], "service uses a member-only request without a client destination and unwraps the position state")
	service.response = {"success": false, "errorCode": "guild_base_not_owned"}
	_check((await service.teleport_to_base()) == service.response, "service preserves an authoritative access denial")
	service.response = {"success": true, "body": {}}
	_check(not bool((await service.teleport_to_base()).success), "empty travel responses cannot be applied as a destination")
	service.response = {"success": true, "body": {"state": destination}}
	service.requests.clear()
	service.wait_for_frame = true
	var overlay: Node = load("res://scenes/interface/ui_overlay.tscn").instantiate()
	_free_unattached_sprite_loaders(overlay)
	overlay.set_script(load("res://tests/support/guild_travel_overlay_probe.gd"))
	root.add_child(overlay)
	var world := WorldStub.new()
	root.add_child(world)
	world.add_to_group("world")
	overlay._on_guild_base_teleport_requested()
	await overlay._on_guild_base_teleport_requested()
	await process_frame
	await process_frame
	await process_frame
	_check(service.requests.size() == 1 and world.departed == 1 and world.applied == [destination], "real overlay ignores double clicks and applies the server-selected base with a departure effect")
	_check(not overlay.guild_teleport_in_flight and not root.get_node("GameState").is_overworld_input_locked(), "successful base travel releases its movement and request locks")
	world.available = false
	await overlay._on_guild_base_teleport_requested()
	_check(service.requests.size() == 1 and not overlay.guild_teleport_in_flight, "blocked world travel does not send a base request or leave a busy flag")
	world.available = true
	var lobby := {"mapId": "aether_clash_lobby"}
	service.response = {"success": true, "body": {"state": lobby, "accepted": true, "cost": 0}}
	await overlay._on_guild_lobby_teleport_requested()
	_check(service.requests.back()[0] == "/game/guilds/me/lobby/teleport" and world.applied.back() == lobby, "the shared handler preserves the separate Guild Lobby destination")
	_free_unattached_sprite_loaders(overlay)
	overlay.free()
	world.free()
	service.set_script(original)
	await process_frame
	print("guild_base_teleport_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _check(condition: bool, description: String) -> void:
	if not condition:
		failed = true
		push_error(description)

func _free_unattached_sprite_loaders(overlay: Node) -> void:
	# The probe skips HUD setup, which normally parents these owned loaders.
	for property: String in ["pokemon_summary_sprite_loader", "pokedex_sprite_loader"]:
		var loader: Node = overlay.get(property)
		if is_instance_valid(loader) and loader.get_parent() == null:
			loader.free()
