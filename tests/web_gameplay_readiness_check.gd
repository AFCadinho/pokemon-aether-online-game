extends SceneTree

const Runtime := preload("res://scripts/services/web_runtime.gd")
var failed := false


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for path: String in ["boxes/0", "pokemon/storage/move", "party/heal", "party/battle-state", "wallet/rewards/trainer-battle", "markets/standard", "trainers/zoe/progress"]:
		_check(Runtime.browser_gameplay_url("http://localhost/api/game/" + path) == "http://localhost/api/auth/web/" + path, "browser route: " + path)
	for path: String in ["trades", "loans", "guilds/me/bank", "aether-clash/challenges", "dev/pokemon", "party-escape"]:
		_check(Runtime.browser_gameplay_url("/game/" + path) == "/game/" + path, "restricted route is not remapped: " + path)
	var source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	var ready := _function(source, "_ready")
	_check(ready.find("_connect_world_presence_signals()") < ready.find('if OS.has_feature("web")'), "both platforms connect the visible roster before branching")
	var setup := _function(source, "_setup_web_demo_world")
	_check(setup.contains('_return_web_demo_to_login(str(saved_state_response.get("error"'), "browser position failures preserve their player-facing reason")
	var return_to_login := _function(source, "_return_web_demo_to_login")
	_check(return_to_login.find("AuthService.set_pending_login_notice(message)") < return_to_login.find("change_scene_to_file(LOGIN_SCENE_PATH)"), "browser world failures retain their notice before returning to login")
	_check(setup.contains("await _resume_saved_wild_battle(saved_state)"), "browser restores wild AND trainer activity on entry")
	_check(setup.contains("WorldPresenceService.connect_presence.call_deferred()"), "browser connects presence after loading")
	_check(setup.contains('saved_state.get("teleportAcknowledgementRequired", false)') and setup.contains("await _ack_authorized_teleport_state(saved_state)"), "browser acknowledges a pending staff teleport during startup")
	_check(_function(source, "_process").split("\t_track_playtime")[0].contains("_publish_world_presence()"), "browser publishes movement periodically")
	_check(_function(source, "_apply_web_demo_transition_state").find("_publish_world_presence.call_deferred(true)") < _function(source, "_apply_web_demo_transition_state").rfind('return {"success": true}'), "map arrival publication is reachable")
	_check(_function(source, "_apply_web_demo_transition_state").contains("await _ack_authorized_teleport_state(state)"), "live staff teleports are acknowledged after browser arrival")
	var player_state_source := FileAccess.get_file_as_string("res://scripts/services/player_game_state_service.gd")
	_check(_function(player_state_source, "_player_teleport_ack_endpoint").contains("WEB_PLAYER_TELEPORT_ACK_ENDPOINT if OS.has_feature(\"web\")"), "browser teleport acknowledgements stay on the scoped web boundary")
	_check(_function(source, "_load_map_scene_threaded").contains('if OS.has_feature("web"):\n\t\treturn ResourceLoader.load'), "browser map changes use the synchronous PCK loader")
	_check(_function(source, "_apply_web_demo_profile").contains('player.call("refresh_appearance")'), "browser profile refreshes the live player appearance")
	_check(_function(source, "_publish_world_presence").contains("_enrich_web_world_presence_state(presence_state)"), "browser enriches presence before publishing it")
	_check(_function(source, "_enrich_web_world_presence_state").contains('state["appearance"] = _get_current_appearance_presence_state()'), "browser presence publishes the equipped appearance")
	_check(_function(source, "start_trainer_battle").contains("await _recover_conflicting_pve_battle()"), "trainer start recovers both existing battle kinds")
	_check(_function(source, "start_triggered_wild_battle_for_area").contains('== "active_trainer_battle_exists"'), "wild start recovers trainer conflicts too")
	var world_script := load("res://scripts/world/world.gd") as Script
	var world: Node = world_script.new()
	var map := Node2D.new()
	map.name = "kanto_route_1"
	root.add_child(map)
	var game_state := root.get_node("GameState")
	game_state.current_map = map
	var presence := root.get_node("WorldPresenceService")
	var settings := root.get_node("SettingsManager")
	settings.hide_other_players = false
	world._connect_world_presence_signals()
	# Exercise the real roster -> avatar pipeline, not only a source substring.
	presence._apply_snapshot_message({"type": "snapshot", "rosterRevision": 1, "players": [
		{"userId": 20, "username": "native-player", "mapId": "kanto_route_1", "position": {"x": 64, "y": 96}, "gender": "male", "appearance": {"body": "Gen4_Base_v1", "hair": "Adinho_Hair", "facial_hair": "Adinho_Beard", "facegear": "Adinho_Glasses", "top": "Adinho_Shirt", "bottom": "Adinho_Trousers", "shoes": "Adinho_Shoes"}},
		{"userId": 30, "username": "browser-player", "mapId": "kanto_route_1", "position": {"x": 128, "y": 96}, "gender": "female"},
	]})
	_check(world.remote_player_avatars.size() == 2, "native and browser roster entries become physical avatars")
	var native_avatar: Node = world.remote_player_avatars.get("20")
	_check(native_avatar != null and native_avatar.current_appearance_state.get("top") == "Adinho_Shirt", "native custom outfit survives the browser presence renderer")
	_check(world.remote_players_container.visible, "avatars are visible with normal settings")
	presence._apply_player_left_message({"type": "player_left", "rosterRevision": 2, "userId": 20})
	_check(not world.remote_player_avatars.has("20") and world.remote_player_avatars.has("30"), "disconnect removes only the departed player")
	world.free()
	game_state.current_map = null
	map.queue_free()
	await process_frame
	print("web_gameplay_readiness_check: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)


func _function(source: String, name: String) -> String:
	var start := source.find("func " + name + "(")
	var end := source.find("\nfunc ", start + 1)
	return source.substr(start, end - start if end >= 0 else -1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
