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
	_check(service_source.contains("WorldTimeService.sync_server_time(server_time)"), "player-action response synchronizes shared world time")
	_check(service_source.contains('body.get("serverTime", "")'), "backend serverTime remains the synchronization source")
	_check(service_source.contains('return "%02d:%02d"'), "countdown formatting")
	_check(ui_source.contains("_show_ui_confirm_popup("), "styled confirmation flow")
	_check(ui_source.contains("escape_rope_button.disabled"), "disabled state")
	_check(ui_source.contains('LocalizationManager.text("ui.hotbar.escape_rope.tooltip.ready"'), "localized cooldown state")
	_check(ui_source.contains('LocalizationManager.text("ui.hotbar.escape_rope.message.cooldown"'), "localized cooldown click feedback")
	var localized_refresh_start := ui_source.find("func _refresh_bag_localized_ui()")
	var localized_refresh_end := ui_source.find("func ", localized_refresh_start + 5)
	var localized_refresh_source := ui_source.substr(
		localized_refresh_start,
		localized_refresh_end - localized_refresh_start
	)
	_check(
		localized_refresh_source.contains("_update_escape_rope_action_ui()"),
		"Escape Rope tooltip refreshes after a live locale change"
	)
	_check(ui_source.contains("escape_rope_in_flight"), "duplicate activation guard")
	_check(ui_source.contains("begin_authorized_teleport"), "local authorized teleport preparation")
	_check(ui_source.contains("apply_authorized_teleport_state"), "authorized teleport handoff")
	_check(ui_source.contains("_refresh_player_actions.call_deferred()"), "status refresh after execution/reconnect lifecycle")
	_check(scene_source.contains("EscapeRopeSlot"), "hidden legacy status presenter")
	_check(ui_source.contains("escape_rope_slot.visible = false"), "legacy action-bar slot stays hidden")
	_check(scene_source.contains("assets/items/icons/ESCAPEROPE.png"), "existing Escape Rope icon")
	quit(1 if failures > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS %s" % label)
	else:
		failures += 1
		push_error("FAIL %s" % label)
