extends SceneTree

const CENTER_PATH := "res://scripts/ui/chat_moderation_center.gd"
const SERVICE_PATH := "res://scripts/services/chat_moderation_service.gd"
const OVERLAY_PATH := "res://scripts/ui/ui_overlay.gd"

var failures := 0


func _init() -> void:
	var center := FileAccess.get_file_as_string(CENTER_PATH)
	var service := FileAccess.get_file_as_string(SERVICE_PATH)
	var overlay := FileAccess.get_file_as_string(OVERLAY_PATH)

	_check(service.contains('const OVERVIEW_ENDPOINT := "/game/chat/moderation/overview"'), "moderation center uses the protected overview endpoint")
	_check(center.contains('active_tab := "online"') and center.contains('overview.get("muted", [])') and center.contains('overview.get("recent", [])'), "center separates online, muted and recent workflows")
	_check(center.contains("remainingSeconds") and center.contains("_format_duration"), "active mutes show a live remaining duration")
	_check(center.contains("mutedByDisplayName") and center.contains("ui.staff.chat.mute_detail"), "active mutes show moderator and reason")
	_check(center.contains("moderation_requested.emit(action, player)"), "center delegates mute mutations to the existing required-reason flow")
	_check(overlay.contains('staff_chat_moderation_popup.call("refresh_overview")'), "successful mute actions refresh the center")
	_check(overlay.contains("_can_use_chat_moderation()") and overlay.contains("staff_chat_moderation_button.visible"), "the moderation center remains permission gated")

	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
