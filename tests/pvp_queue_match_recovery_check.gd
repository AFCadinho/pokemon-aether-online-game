extends SceneTree

const UI_OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failed := false


func _init() -> void:
	var source := FileAccess.get_file_as_string(UI_OVERLAY_PATH)
	_check_true(source.contains("var pvp_queue_join_in_flight := false"), "queue joins keep an in-flight guard")
	_check_true(
		source.contains("pvp_battle_starting or pvp_queue_join_in_flight or pvp_ranked_queue_join_preparing"),
		"duplicate queue presses are ignored while validation or joining is pending"
	)
	_check_true(source.contains("func _pvp_active_queue_match_from_response"), "queue responses recognize an authoritative active match")
	_check_true(source.contains("func _resume_pvp_queue_active_match"), "queue polling can resume the authoritative match")
	_check_true(
		source.find("var active_match := _pvp_active_queue_match_from_response(response)", source.find("func _poll_pvp_queue_status"))
		< source.find("var entry: Dictionary = _latest_relevant_pvp_queue_entry(response)", source.find("func _poll_pvp_queue_status")),
		"an active match takes priority over historical queue entries"
	)
	quit(1 if failed else 0)


func _check_true(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)
