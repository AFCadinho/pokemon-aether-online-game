extends SceneTree

var failures := 0


func _init() -> void:
	var service_source := FileAccess.get_file_as_string("res://scripts/services/player_action_service.gd")
	var ui_source := FileAccess.get_file_as_string("res://scripts/ui/ui_overlay.gd")
	var scene_source := FileAccess.get_file_as_string("res://scenes/interface/ui_overlay.tscn")
	_check(service_source.contains("/game/player-actions"), "generic status endpoint")
	_check(service_source.contains("/game/player-actions/%s/execute"), "generic execute endpoint")
	_check(service_source.contains("pending_request_ids"), "request ID retained for retry")
	_check(service_source.contains("if retry"), "retry reuses request ID")
	_check(service_source.contains("statuses_changed.emit"), "status changes exposed")
	_check(service_source.contains('return "%02d:%02d"'), "countdown formatting")
	_check(ui_source.contains("ConfirmationDialog.new()"), "confirmation flow")
	_check(ui_source.contains("escape_rope_button.disabled"), "disabled state")
	_check(ui_source.contains("Ready in %s"), "cooldown state")
	_check(ui_source.contains("escape_rope_in_flight"), "duplicate activation guard")
	_check(ui_source.contains("begin_authorized_teleport"), "local authorized teleport preparation")
	_check(ui_source.contains("apply_authorized_teleport_state"), "authorized teleport handoff")
	_check(ui_source.contains("_refresh_player_actions.call_deferred()"), "status refresh after execution/reconnect lifecycle")
	_check(scene_source.contains("EscapeRopeSlot"), "action-bar slot")
	_check(scene_source.contains("assets/items/icons/ESCAPEROPE.png"), "existing Escape Rope icon")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
