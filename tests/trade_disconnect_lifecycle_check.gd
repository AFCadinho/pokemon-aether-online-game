extends SceneTree

const Workspace := preload("res://scripts/ui/trade_workspace.gd")
const Realtime := preload("res://scripts/services/trade_realtime_service.gd")

var failed := false


func _init() -> void:
	_check(Workspace.reconnect_seconds_remaining("2026-07-11T12:00:30Z", Time.get_unix_time_from_datetime_string("2026-07-11T12:00:00Z")) == 30, "server deadline countdown")
	_check(Workspace.reconnect_seconds_remaining("2026-07-11T12:00:00Z", Time.get_unix_time_from_datetime_string("2026-07-11T12:00:30Z")) == 0, "expired countdown clamps")
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_workspace.gd")
	_check(source.contains("leave_trade"), "workspace has authoritative Leave Trade command")
	_check(source.contains("reconnectDeadlineAt"), "workspace uses server reconnect deadline")
	_check(source.contains("reconnect_timeout"), "workspace explains timeout cancellation")
	_check(source.contains('"ui.trade.confirm"'), "localized confirmation remains confined to locked workspace")
	var realtime_source := FileAccess.get_file_as_string("res://scripts/services/trade_realtime_service.gd")
	_check(realtime_source.contains("func leave_active_trade_for_exit()"), "trade service owns logout and shutdown cleanup")
	_check(realtime_source.contains("NOTIFICATION_WM_CLOSE_REQUEST"), "application close waits for trade cleanup")
	_check(realtime_source.contains("auto_accept_quit = false"), "automatic quit cannot bypass trade cleanup")
	_check(realtime_source.contains('await world.call("save_current_player_state_now")'), "application close persists the world position before quitting")
	var auth_source := FileAccess.get_file_as_string("res://scripts/services/auth_service.gd")
	_check(auth_source.find("leave_active_trade_for_exit") < auth_source.find("/auth/logout"), "trade cleanup runs before token logout")
	var service := Realtime.new()
	var locked := {"tradeId":"t","status":"locked","revision":4,"lastEventSeq":4,"participants":[{"userId":1,"connectionState":"connected"},{"userId":2,"connectionState":"disconnected","reconnectDeadlineAt":"2026-07-11T12:00:30Z"}],"lockedReview":{"snapshotHash":"stable"}}
	service.apply_snapshot(locked)
	service.apply_event({"tradeId":"t","eventSeq":5,"revision":5,"type":"trade.reconnect_grace_started","payload":{"userId":2,"connectionState":"disconnected"}})
	_check(service.active_trade_snapshot.get("lockedReview",{}).get("snapshotHash","") == "stable", "disconnect preserves immutable review")
	service.apply_snapshot({"tradeId":"t","status":"locked","revision":6,"lastEventSeq":6,"participants":[{"userId":1,"connectionState":"connected"},{"userId":2,"connectionState":"connected"}],"lockedReview":{"snapshotHash":"stable"}})
	_check(service.last_applied_event_seq == 6 and service.active_trade_snapshot.get("status","") == "locked", "reconnect restores exact locked state")
	service.apply_event({"tradeId":"t","eventSeq":7,"revision":7,"type":"trade.cancelled","payload":{"status":"cancelled","reason":"reconnect_timeout"}})
	_check(service.active_trade_snapshot.get("status","") == "cancelled", "terminal event is authoritative")
	_check(service.last_applied_event_seq == 0, "terminal transport cleanup follows authoritative cancellation")
	service.free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
