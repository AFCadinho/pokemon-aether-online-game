extends SceneTree

const WorldPresenceServiceScript := preload("res://scripts/services/world_presence_service.gd")

var failed := false
var service: Node
var legacy_update: Dictionary = {}


func _init() -> void:
	service = WorldPresenceServiceScript.new()
	service.player_update_received.connect(_on_legacy_player_update_received)
	_check_snapshot_and_update_roster_state()
	_check_stale_and_duplicate_revisions_are_ignored()
	_check_roster_resets_for_reconnect_or_map_change()
	_check_presence_payload_includes_activity_state()

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


func _check_presence_payload_includes_activity_state() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/services/world_presence_service.gd")
	_check_equal(source.contains("\"activityState\": str(state.get(\"activityState\", \"idle\"))"), true, "activity state payload")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])


func _on_legacy_player_update_received(message: Dictionary) -> void:
	legacy_update = message.duplicate(true)
