extends SceneTree

const SocialServiceScript := preload("res://scripts/services/social_service.gd")

var failed := false
var service: Node


func _init() -> void:
	service = SocialServiceScript.new()

	_check_overview_response_passthrough()
	_check_action_response_overview_unwrap()
	_check_error_detail_extraction()

	service.free()
	quit(1 if failed else 0)


func _check_overview_response_passthrough() -> void:
	var result: Dictionary = service._socials_result_from_response({
		"success": true,
		"body": {
			"friends": [{"friendshipId": 1}],
			"incomingFriendRequests": [],
			"outgoingFriendRequests": [],
			"blockedUsers": [],
			"profile": {"statusMessage": "Training"},
		},
	})

	_check_equal(result.get("success", false), true, "overview success")
	_check_equal(result.get("overview", {}).get("friends", []).size(), 1, "overview friends")
	_check_equal(result.get("profile", {}).get("statusMessage", ""), "Training", "overview profile")


func _check_action_response_overview_unwrap() -> void:
	var result: Dictionary = service._socials_result_from_response({
		"success": true,
		"body": {
			"overview": {
				"friends": [],
				"profile": {"statusMessage": "Ready"},
			},
			"request": {"id": 7},
		},
	})

	_check_equal(result.get("overview", {}).get("profile", {}).get("statusMessage", ""), "Ready", "action overview")
	_check_equal(result.get("request", {}).get("id", 0), 7, "action request")


func _check_error_detail_extraction() -> void:
	_check_equal(
		service._extract_error({"detail": "friend request already pending"}, 409),
		"friend request already pending",
		"string detail"
	)
	_check_equal(
		service._extract_error({"detail": {"message": "user not found"}}, 404),
		"user not found",
		"dictionary detail message"
	)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
