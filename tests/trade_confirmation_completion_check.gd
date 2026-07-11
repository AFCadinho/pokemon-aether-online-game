extends SceneTree

const Realtime := preload("res://scripts/services/trade_realtime_service.gd")

var failed := false

class FakeTradeService extends Node:
	var loaded := 0
	func load_trade(trade_id: String) -> Dictionary:
		loaded += 1
		return {"success":true,"trade":{"tradeId":trade_id,"status":"completed","revision":8,"lastEventSeq":8,"completedAt":"2026-07-11T12:00:00Z","completionResult":{"refresh":{"party":true,"storage":true}}}}


func _init() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/trade_workspace.gd")
	_check(source.contains("func _confirm_trade"), "workspace owns explicit confirmation action")
	_check(source.contains("lockedRevision") and source.contains("snapshotHash"), "workspace submits exact locked review")
	_check(source.contains("refresh_after_completion"), "completion refreshes party and storage")
	_check(not source.contains("owner_user_id"), "client never predicts ownership mutation")
	var service := Realtime.new()
	var fake := FakeTradeService.new()
	service.trade_service_override = fake
	service.apply_snapshot({"tradeId":"t","status":"locked","revision":6,"lastEventSeq":6,"participants":[{"userId":1,"confirmed":true},{"userId":2,"confirmed":false}],"lockedReview":{"lockedRevision":4,"snapshotHash":"hash"}})
	_check(service.active_trade_snapshot.get("participants",[])[0].get("confirmed",false), "first-confirmed state restores")
	service.apply_event({"tradeId":"t","eventSeq":7,"revision":7,"type":"trade.participant_confirmed","payload":{"userId":1}})
	service.apply_event({"tradeId":"t","eventSeq":8,"revision":8,"type":"trade.completed","payload":{"status":"completed"}})
	await service.refresh_completed_trade("t")
	_check(fake.loaded == 1, "completed event reloads authoritative trade result")
	_check(service.active_trade_snapshot.get("status","") == "completed", "completed snapshot is retained for recovery")
	_check(service.active_trade_id == "", "completion stops active reconnect transport")
	service.free();fake.free()
	quit(1 if failed else 0)


func _check(value: bool,label: String) -> void:
	if not value:
		failed=true
		push_error(label)
