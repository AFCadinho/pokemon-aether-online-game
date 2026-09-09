extends SceneTree

const ErrorFeedback := preload("res://scripts/battle/battle_calcdex_error_feedback.gd")


func _init() -> void:
	_check(
		ErrorFeedback.message_key({
			"detail": {
				"code": "CALC_INVALID_SELECTION",
				"messageKey": "calcdex.error.calc_invalid_selection",
				"retryable": false,
			},
		}) == ErrorFeedback.INVALID_SNAPSHOT_DATA_KEY,
		"invalid snapshot selections explain that the battle data must be corrected"
	)
	_check(
		ErrorFeedback.message_key({"errorCode": " calc_invalid_selection "}) == ErrorFeedback.INVALID_SNAPSHOT_DATA_KEY,
		"snapshot error codes are normalized before selecting feedback"
	)
	_check(
		ErrorFeedback.message_key({"code": "CALC_STALE_PROJECTION"}) == ErrorFeedback.SAFE_SNAPSHOT_REQUIRED_KEY,
		"other snapshot failures keep the safe refresh guidance"
	)
	_check(
		ErrorFeedback.message_key({}) == ErrorFeedback.SAFE_SNAPSHOT_REQUIRED_KEY,
		"missing snapshot errors keep the safe refresh guidance"
	)
	print("PASS battle_calcdex_error_feedback_check")
	quit(0)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
