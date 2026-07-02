extends SceneTree

const Banlists := preload("res://scripts/services/pvp_ranked_banlists.gd")

var failed := false


func _init() -> void:
	_check_empty_response()
	_check_all_categories_response()
	_check_server_failure()
	_check_refresh_replaces_result()
	_check_malformed_response()
	quit(1 if failed else 0)


func _check_empty_response() -> void:
	var result := Banlists.normalize_response({
		"success": true,
		"rulesetId": "ranked_v1",
		"formatId": "gen9nationaldex",
		"version": 0,
		"banlistHash": "hash-1",
		"updatedAt": null,
		"banlists": {
			"pokemon": [],
			"items": [],
			"moves": [],
			"abilities": [],
		},
	})
	_check_equal(result.get("state", ""), Banlists.STATE_READY, "empty response state")
	_check_equal(Banlists.category_bans(result, "pokemon").size(), 0, "empty pokemon bans")
	_check_equal(Banlists.empty_message("pokemon"), "No banned Pokemon.", "empty pokemon message")
	var metadata: Dictionary = result.get("metadata", {})
	_check_equal(metadata.get("formatId", ""), "gen9nationaldex", "format metadata")
	_check_equal(metadata.get("rulesetId", ""), "ranked_v1", "ruleset metadata")
	_check_equal(metadata.get("version", ""), "0", "version metadata")
	_check_equal(metadata.get("banlistHash", ""), "hash-1", "hash metadata")


func _check_all_categories_response() -> void:
	var result := Banlists.normalize_response({
		"success": true,
		"rulesetId": "ranked_v1",
		"formatId": "gen9nationaldex",
		"version": 2,
		"hash": "legacy-hash",
		"updatedAt": "2026-07-02T20:00:00Z",
		"banlists": {
			"pokemon": [{"id": "darkrai", "label": "Darkrai"}],
			"items": [{"id": "king-s-rock", "label": "King's Rock"}],
			"moves": [{"id": "baton-pass", "label": "Baton Pass"}],
			"abilities": [{"id": "shadow-tag", "label": "Shadow Tag"}],
		},
	})
	_check_equal(Banlists.is_ready(result), true, "all categories ready")
	_check_equal(Banlists.category_bans(result, "pokemon")[0].get("label", ""), "Darkrai", "pokemon label")
	_check_equal(Banlists.category_bans(result, "items")[0].get("id", ""), "king-s-rock", "item id")
	_check_equal(Banlists.category_bans(result, "moves")[0].get("label", ""), "Baton Pass", "move label")
	_check_equal(Banlists.category_bans(result, "abilities")[0].get("label", ""), "Shadow Tag", "ability label")
	var metadata: Dictionary = result.get("metadata", {})
	_check_equal(metadata.get("banlistHash", ""), "legacy-hash", "legacy hash fallback")


func _check_server_failure() -> void:
	var result := Banlists.normalize_response({
		"success": false,
		"error": "API gateway request timed out.",
	})
	_check_equal(result.get("state", ""), Banlists.STATE_ERROR, "failure state")
	_check_equal(Banlists.display_message(result), "Server unavailable.", "server unavailable message")


func _check_refresh_replaces_result() -> void:
	var first := Banlists.normalize_response({
		"success": true,
		"banlists": {
			"pokemon": [{"id": "darkrai"}],
			"items": [],
			"moves": [],
			"abilities": [],
		},
	})
	var second := Banlists.normalize_response({
		"success": true,
		"banlists": {
			"pokemon": [],
			"items": [{"id": "leftovers"}],
			"moves": [],
			"abilities": [],
		},
	})
	_check_equal(Banlists.category_bans(first, "pokemon").size(), 1, "first refresh pokemon")
	_check_equal(Banlists.category_bans(second, "pokemon").size(), 0, "second refresh clears pokemon")
	_check_equal(Banlists.category_bans(second, "items")[0].get("label", ""), "Leftovers", "second refresh item label")


func _check_malformed_response() -> void:
	var result := Banlists.normalize_response({
		"success": true,
		"banlists": "not-a-dictionary",
	})
	_check_equal(result.get("state", ""), Banlists.STATE_ERROR, "malformed state")
	_check_equal(Banlists.display_message(result), "Failed to load banlists: malformed response.", "malformed message")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
