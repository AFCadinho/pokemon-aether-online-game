extends SceneTree

const CITY_SCENE := "res://scenes/overworld/kanto/towns/vermilion_city/vermilion_city.tscn"
const NPC_ID := "kanto_vermilion_city_guild_registrar"
const TOWN_ID := "kanto_vermilion_city"

var failed := false


class FakeGuildService extends Node:
	signal membership_changed(membership: Dictionary)
	var state: Dictionary = {}
	var loads := 0
	var purchases := 0
	var unavailable := false
	var purchase_fails := false
	var after_load: Callable

	func load_base_registrar(_registrar_id: String) -> Dictionary:
		loads += 1
		if after_load.is_valid():
			after_load.call()
		return {"success": false, "error": "test outage"} if unavailable else {"success": true, "registrar": state.duplicate(true)}

	func purchase_base(_registrar_id: String) -> Dictionary:
		purchases += 1
		if purchase_fails:
			return {"success": false, "error": "test funds race"}
		state["baseTownId"] = TOWN_ID
		state["canEnterGarden"] = true
		state["canPurchase"] = false
		return {"success": true, "purchased": true, "registrar": state.duplicate(true)}


class FakePlayer extends Node2D:
	var teleports := 0
	var facing := Vector2.ZERO

	func teleport_within_current_map(destination: Vector2, direction: Vector2) -> void:
		teleports += 1
		global_position = destination
		facing = direction

	func face_world_position(_destination: Vector2) -> void:
		pass


class FakeErrors extends Node:
	var errors := 0

	func show_response(_response: Dictionary) -> void:
		errors += 1


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var city := (load(CITY_SCENE) as PackedScene).instantiate()
	var registrar: Variant = city.get_node("Entities/NPCs/GuildRegistrarNPC")
	var properties := {}
	for key: String in ["npc_id", "gate_id", "guard_role", "guard_blocking_anchor_path", "guard_blocking_size", "passage_closed", "blocked_dialogue_id", "garden_bounds"]:
		properties[key] = registrar.get(key)
	registrar.set_script(load("res://tests/support/guild_registrar_probe.gd"))
	for key: String in properties:
		registrar.set(key, properties[key])
	var service := FakeGuildService.new()
	root.add_child(service)
	service.state = _eligible_state()
	registrar.guild_service = service
	var metadata_service := root.get_node("NpcMetadataService")
	var locale := str(metadata_service.call("_get_http_locale"))
	var cache_key := str(metadata_service.call("_get_cache_key", locale, NPC_ID))
	metadata_service.npc_metadata_cache[cache_key] = {"success": true, "metadata": {
		"id": NPC_ID, "name": "Guild Registrar", "requiresPartyPokemon": false,
		"blockedDialogueId": "kanto_vermilion_city_guild_registrar_closed",
	}}
	root.add_child(city)
	var game_state := root.get_node("GameState")
	game_state.current_map = city
	var errors := FakeErrors.new()
	root.add_child(errors)
	registrar.GameErrorDialogService = errors
	var player := FakePlayer.new()
	root.add_child(player)
	player.add_to_group("player")
	player.position = Vector2(1168, 624)

	await registrar.interact_with_player(player)
	_check(service.purchases == 0, "canceling registration does not purchase a base")
	_check(registrar.confirmation_state.requiredLevel == 10 and registrar.confirmation_state.price == 1000000, "confirmation uses server-provided level and bank price")
	registrar.accept_purchase = true
	await registrar.interact_with_player(player)
	_check(service.purchases == 1 and service.state.canEnterGarden, "confirmed registration buys the base")
	var confirmation_count: int = registrar.confirmation_count
	await registrar.interact_with_player(player)
	_check(service.purchases == 1 and registrar.confirmation_count == confirmation_count, "an established guild sees its access instead of another purchase")

	var loads := service.loads
	await registrar.on_route_gate_blocked(player)
	_check(service.loads == loads + 1, "entering checks fresh server membership")
	_check(player.position == Vector2(1232, 624) and player.facing == Vector2.RIGHT, "authorized member crosses into the garden")
	_check(registrar.visible and registrar.position == Vector2(1136, 560), "registrar remains visible at the user's position beside the gate")
	_check(not game_state.is_overworld_input_locked(), "crossing releases its input lock")

	service.state.canEnterGarden = false
	service.state.baseTownId = null
	service.state.guildId = null
	loads = service.loads
	await registrar.on_route_gate_blocked(player)
	_check(player.position == Vector2(1168, 624) and service.loads == loads, "leaving remains possible after membership loss")
	var teleports := player.teleports
	await registrar.on_route_gate_blocked(player)
	_check(player.teleports == teleports, "former membership cannot authorize another entry")
	service.state.guildId = 7
	service.state.baseTownId = "kanto_celadon_city"
	service.state.baseTownName = "Celadon City"
	await registrar.on_route_gate_blocked(player)
	_check(player.teleports == teleports, "a guild based in another town cannot enter")
	service.unavailable = true
	await registrar.on_route_gate_blocked(player)
	_check(player.teleports == teleports and errors.errors == 1, "network failure keeps the gate closed")
	_check(not game_state.is_overworld_input_locked(), "failed access check releases its input lock")
	service.unavailable = false

	player.position = Vector2(1408, 624)
	await registrar._check_garden_membership()
	_check(player.position == Vector2(1168, 624), "a player who loses access is returned outside the garden")
	loads = service.loads
	await registrar._check_garden_membership()
	_check(service.loads == loads, "public-street players require no periodic garden request")
	player.position = Vector2(1408, 624)
	teleports = player.teleports
	service.after_load = func(): game_state.current_map = null
	await registrar._check_garden_membership()
	_check(player.teleports == teleports, "a response from the previous map cannot teleport the player")
	loads = service.loads
	await registrar._check_garden_membership()
	_check(service.loads == loads, "inactive maps do not poll garden membership")
	game_state.current_map = city
	service.after_load = func(): game_state.acquire_overworld_input_lock(&"test-battle")
	await registrar._check_garden_membership()
	_check(player.teleports == teleports, "a battle started during the access request delays ejection")
	game_state.release_overworld_input_lock(&"test-battle")
	service.after_load = Callable()
	player.position = Vector2(1168, 624)

	service.state = _eligible_state()
	service.purchase_fails = true
	await registrar.interact_with_player(player)
	_check(errors.errors == 2 and not service.state.canEnterGarden, "changed bank funds at purchase do not grant client access")
	service.purchase_fails = false
	service.state.canPurchase = false
	service.state.isLeader = false
	confirmation_count = registrar.confirmation_count
	await registrar.interact_with_player(player)
	_check(registrar.confirmation_count == confirmation_count, "members cannot open the leader's purchase confirmation")
	for language: String in ["en", "nl", "pt_BR", "zh_CN"]:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://localization/%s.json" % language))
		for key: String in ["title", "buy", "confirm", "purchased", "welcome", "no_guild", "other_town", "garden_requires_base", "leader_required", "level_required", "funds_required", "access_lost"]:
			_check(catalog.has("ui.guild_base." + key), "%s has registrar text %s" % [language, key])
	game_state.current_map = null
	city.free()
	player.free()
	service.free()
	errors.free()
	metadata_service.clear_cache()
	print("GUILD_BASE_REGISTRAR ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)


func _eligible_state() -> Dictionary:
	return {
		"registrarId": NPC_ID, "townId": TOWN_ID, "townName": "Vermilion City",
		"guildId": 7, "guildLevel": 10, "requiredLevel": 10,
		"price": 1000000, "bankBalance": 1000000, "isLeader": true,
		"baseTownId": null, "canPurchase": true, "canEnterGarden": false,
	}


func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error("FAIL " + label)
