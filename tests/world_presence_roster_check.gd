extends SceneTree

const WorldPresenceServiceScript := preload("res://scripts/services/world_presence_service.gd")

var failed := false
var service: Node
var legacy_update: Dictionary = {}
var latest_weather: Dictionary = {}


func _init() -> void:
	service = WorldPresenceServiceScript.new()
	service.player_update_received.connect(_on_legacy_player_update_received)
	service.weather_changed.connect(_on_weather_changed)
	_check_snapshot_and_update_roster_state()
	_check_stale_and_duplicate_revisions_are_ignored()
	_check_roster_resets_for_reconnect_or_map_change()
	_check_same_map_teleport_can_restore_cached_roster()
	_check_presence_payload_includes_activity_state()
	_check_connection_attempt_guard()
	_check_authoritative_weather_messages()

	service.free()
	quit(1 if failed else 0)


func _check_snapshot_and_update_roster_state() -> void:
	service._apply_snapshot_message({
		"rosterRevision": 5,
		"players": [{"userId": 2, "username": "misty", "mapId": "kanto_pallet_town"}],
	})
	_check_equal(service.get_current_map_players().size(), 1, "snapshot roster count")
	_check_equal(service.roster_revision, 5, "snapshot revision")

	service._apply_player_update_message({
		"type": "player_update",
		"rosterRevision": 6,
		"userId": 2,
		"username": "misty",
		"mapId": "kanto_pallet_town",
		"activityState": "trade",
	})
	var player: Dictionary = service.get_current_map_players()[0]
	_check_equal(player.get("activityState", ""), "trade", "updated player state")
	_check_equal(service.roster_revision, 6, "updated revision")
	_check_equal(legacy_update.get("type", ""), "player_update", "legacy update type")
	_check_equal(legacy_update.get("rosterRevision", 0), 6, "legacy update revision")


func _check_stale_and_duplicate_revisions_are_ignored() -> void:
	service._apply_player_update_message({
		"type": "player_update",
		"rosterRevision": 5,
		"userId": 3,
		"username": "brock",
	})
	_check_equal(service.get_current_map_players().size(), 1, "stale update ignored")

	service._apply_player_left_message({
		"type": "player_left",
		"rosterRevision": 7,
		"userId": 2,
	})
	_check_equal(service.get_current_map_players().size(), 0, "newer removal applied")

	service._apply_snapshot_message({
		"rosterRevision": 7,
		"players": [{"userId": 2, "username": "misty"}],
	})
	_check_equal(service.get_current_map_players().size(), 0, "duplicate revision ignored")


func _check_roster_resets_for_reconnect_or_map_change() -> void:
	service._apply_snapshot_message({
		"rosterRevision": 8,
		"players": [{"userId": 4, "username": "erika"}],
	})
	service._reset_roster()
	_check_equal(service.get_current_map_players().size(), 0, "reset clears roster")
	_check_equal(service.roster_revision, 0, "reset clears revision")
	_check_equal(service.has_authoritative_roster_revision, false, "reset clears authority state")


func _check_same_map_teleport_can_restore_cached_roster() -> void:
	var same_map_service := WorldPresenceServiceScript.new()
	var duel_map_id := "aether_clash_duel:test-session"
	same_map_service.last_sent_map_id = duel_map_id
	same_map_service._apply_snapshot_message({
		"rosterRevision": 1,
		"players": [{
			"userId": 22,
			"username": "stationary-player",
			"mapId": duel_map_id,
		}],
	})
	same_map_service.update_position({"mapId": duel_map_id})
	_check_equal(
		same_map_service.get_current_map_players().size(),
		1,
		"same-map position publish preserves cached roster"
	)
	same_map_service.free()

	var world_source := FileAccess.get_file_as_string("res://scripts/world/world.gd")
	_check_equal(
		world_source.contains(
			'var reuses_presence_roster := current_map_id != "" and current_map_id == target_map_id'
		),
		true,
		"authorized teleport distinguishes the same presence map"
	)
	_check_equal(
		world_source.contains(
			"_publish_world_presence(true)\n"
			+ "\tif reuses_presence_roster:\n"
			+ "\t\t_restore_remote_players_from_cached_presence()"
		),
		true,
		"same-map teleport restores avatars after publishing the jail position"
	)
	_check_equal(
		world_source.contains(
			"func _restore_remote_players_from_cached_presence() -> void:\n"
			+ "\tvar cached_players := WorldPresenceService.get_current_map_players()\n"
			+ "\t_apply_remote_player_states(cached_players, true)"
		),
		true,
		"cached presence players are reapplied without waiting for movement"
	)


func _check_presence_payload_includes_activity_state() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/services/world_presence_service.gd")
	_check_equal(source.contains("\"activityState\": str(state.get(\"activityState\", \"idle\"))"), true, "activity state payload")


func _check_connection_attempt_guard() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/services/world_presence_service.gd")
	_check_equal(source.contains("var connection_attempt_id := 0"), true, "presence tracks connection attempts")
	_check_equal(source.contains("func _connect_presence_async(attempt_id: int)"), true, "presence validates asynchronous connection attempts")
	_check_equal(source.contains("if connecting:\n\t\treturn"), true, "presence does not reconnect while a connection is pending")


func _check_authoritative_weather_messages() -> void:
	service.last_sent_map_id = "kanto_route_2"
	service._apply_snapshot_message({
		"rosterRevision": 9,
		"players": [],
		"weather": {
			"mapId": "kanto_route_2",
			"weather": "rain",
			"source": "natural",
			"periodId": 42,
		},
	})
	_check_equal(latest_weather.get("weather", ""), "rain", "snapshot applies authoritative weather")
	_check_equal(service.current_weather_state.get("periodId", 0), 42, "weather metadata is retained")
	service._apply_weather_state({"mapId": "kanto_route_1", "weather": "snow", "periodId": 43})
	_check_equal(latest_weather.get("weather", ""), "rain", "weather for a stale map is ignored")
	service._apply_weather_state({"mapId": "kanto_route_2", "weather": "snow", "periodId": 44})
	_check_equal(latest_weather.get("weather", ""), "snow", "realtime weather updates the current map")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _on_legacy_player_update_received(message: Dictionary) -> void:
	legacy_update = message.duplicate(true)


func _on_weather_changed(weather_state: Dictionary) -> void:
	latest_weather = weather_state.duplicate(true)
