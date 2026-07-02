extends SceneTree

const Validation := preload("res://scripts/services/pvp_ranked_team_validation.gd")

var failed := false


func _init() -> void:
	_check_valid_response()
	_check_multiple_validation_errors()
	_check_server_failure()
	_check_party_change_signature()
	_check_invalid_join_gate()
	_check_valid_join_gate()
	quit(1 if failed else 0)


func _check_valid_response() -> void:
	var result: Dictionary = Validation.normalize_response({
		"success": true,
		"valid": true,
		"team": {"teamHash": "abc"},
		"errors": [],
		"warnings": [],
	})
	_check_equal(result.get("state", ""), Validation.STATE_VALID, "valid response state")
	_check_equal(result.get("valid", false), true, "valid response flag")
	_check_equal(result.get("message", ""), "Ranked Ready", "valid response message")
	_check_equal(result.get("teamHash", ""), "abc", "valid response team hash")


func _check_multiple_validation_errors() -> void:
	var result: Dictionary = Validation.normalize_response({
		"success": true,
		"valid": false,
		"errors": [
			{"code": "species_clause_duplicate", "message": "Duplicate Species"},
			{"code": "banned_pokemon", "message": "Darkrai is banned"},
			{"code": "team_too_large", "message": "Team contains too many Pokemon"},
		],
	})
	var errors := Validation.display_errors(result)
	var issues := Validation.display_issues(result)
	_check_equal(result.get("state", ""), Validation.STATE_INVALID, "invalid response state")
	_check_equal(errors.size(), 3, "multiple errors are preserved")
	_check_equal(errors[0], "Duplicate Species", "first error preserved")
	_check_equal(errors[1], "Darkrai is banned", "second error preserved")
	_check_equal(errors[2], "Team contains too many Pokemon", "third error preserved")
	_check_equal(issues.size(), 3, "structured issues are preserved")
	_check_equal(issues[1].get("code", ""), "banned_pokemon", "structured issue code preserved")


func _check_server_failure() -> void:
	var result: Dictionary = Validation.normalize_response({
		"success": false,
		"error": "API gateway request timed out.",
	})
	_check_equal(result.get("state", ""), Validation.STATE_ERROR, "failure response state")
	_check_equal(Validation.display_errors(result)[0], "API gateway request timed out.", "failure message preserved")
	_check_equal(Validation.allows_ranked_join(result), false, "failure blocks ranked join")


func _check_party_change_signature() -> void:
	var first := Validation.party_signature([
		{"instanceId": "one", "species": "Pikachu", "level": 12},
	])
	var second := Validation.party_signature([
		{"instanceId": "one", "species": "Raichu", "level": 12},
	])
	_check_equal(first != second, true, "party change updates validation signature")


func _check_invalid_join_gate() -> void:
	var result: Dictionary = Validation.normalize_response({
		"success": true,
		"valid": false,
		"errors": [{"message": "Duplicate Species"}],
	})
	_check_equal(Validation.allows_ranked_join(result), false, "invalid team blocks ranked join")


func _check_valid_join_gate() -> void:
	var result: Dictionary = Validation.normalize_response({
		"success": true,
		"valid": true,
		"errors": [],
	})
	_check_equal(Validation.allows_ranked_join(result), true, "valid team allows ranked join")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return
	failed = true
	push_error("%s: expected %s, got %s" % [label, str(expected), str(actual)])
