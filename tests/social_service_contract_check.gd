extends SceneTree

const SocialServiceScript := preload("res://scripts/services/social_service.gd")

var failed := false
var service: Node


func _init() -> void:
	service = SocialServiceScript.new()

	_check_overview_response_passthrough()
	_check_action_response_overview_unwrap()
	_check_error_detail_extraction()
	await _check_private_message_requires_auth()

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
		"Something went wrong. Please try again.",
		"legacy string detail is hidden behind the safe fallback"
	)
	_check_equal(
		service._extract_error({
			"detail": {
				"code": "guild_invite_target_not_found",
				"message": "internal user lookup detail",
			},
		}, 404),
		"That Trainer could not be found.",
		"structured detail code is localized"
	)


func _check_private_message_requires_auth() -> void:
	var result: Dictionary = await service.send_private_message("misty", "Hey")
	_check_equal(result.get("success", true), false, "pm auth success")
	_check_equal(result.get("error", ""), "Not authenticated.", "pm auth error")


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	if actual == expected:
		return

	failed = true
	push_error("%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
