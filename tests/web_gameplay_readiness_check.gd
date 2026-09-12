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
	_check(setup.contains("await _resume_saved_wild_battle(saved_state)"), "browser restores wild AND trainer activity on entry")
	_check(setup.contains("WorldPresenceService.connect_presence.call_deferred()"), "browser connects presence after loading")
	_check(_function(source, "_process").split("\t_track_playtime")[0].contains("_publish_world_presence()"), "browser publishes movement periodically")
	_check(_function(source, "_apply_web_demo_transition_state").find("_publish_world_presence.call_deferred(true)") < _function(source, "_apply_web_demo_transition_state").rfind('return {"success": true}'), "map arrival publication is reachable")
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
		{"userId": 20, "username": "native-player", "mapId": "kanto_route_1", "position": {"x": 64, "y": 96}, "gender": "male"},
		{"userId": 30, "username": "browser-player", "mapId": "kanto_route_1", "position": {"x": 128, "y": 96}, "gender": "female"},
	]})
	_check(world.remote_player_avatars.size() == 2, "native and browser roster entries become physical avatars")
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
