extends SceneTree

const RealtimeService := preload("res://scripts/services/trade_realtime_service.gd")

var failed := false


func _init() -> void:
	var first := RealtimeService.new()
	var second := RealtimeService.new()
	var first_updates := [0]
	var second_updates := [0]
	first.offer_update_received.connect(func(_event): first_updates[0] += 1)
	second.offer_update_received.connect(func(_event): second_updates[0] += 1)
	var snapshot := {"tradeId":"shared", "status":"active", "revision":0, "lastEventSeq":0, "offers":[]}
	first.apply_snapshot(snapshot)
	second.apply_snapshot(snapshot)
	var event := {"tradeId":"shared", "eventSeq":1, "revision":1, "type":"trade.offer_updated", "payload":{"actorUserId":1,"offers":[]}}
	first.apply_event(event)
	second.apply_event(event)
	first.apply_event(event)
	_check(first_updates[0] == 1 and second_updates[0] == 1, "both clients apply one opponent update")
	_check(first.last_applied_event_seq == 1 and second.last_applied_event_seq == 1, "both clients retain durable cursor")
	var readiness_event := {"tradeId":"shared", "eventSeq":2, "revision":2, "type":"trade.readiness_changed", "payload":{"status":"active","readiness":[{"userId":1,"ready":true}]}}
	first.apply_event(readiness_event)
	second.apply_event(readiness_event)
	var one_ready_snapshot := {"tradeId":"shared", "status":"active", "revision":2, "lastEventSeq":2, "participants":[{"userId":1,"ready":true},{"userId":2,"ready":false}], "offers":[]}
	first.apply_snapshot(one_ready_snapshot)
	_check(first.begin_reconnect(), "one-ready client reconnect starts")
	var ready_join := first.mark_socket_open(first.socket_generation)
	_check(ready_join.get("lastEventSeq", -1) == 2, "one-ready reconnect uses durable cursor")
	first.mark_socket_closed(first.socket_generation)
	var locked_snapshot := {"tradeId":"shared", "status":"locked", "revision":3, "lastEventSeq":3, "participants":[{"userId":1,"ready":true},{"userId":2,"ready":true}], "offers":[], "lockedReview":{"lockedRevision":3,"snapshotHash":"abc","snapshot":{"participants":[]}}}
	first.apply_snapshot(locked_snapshot)
	second.apply_snapshot(locked_snapshot)
	_check(first.active_trade_snapshot.get("status", "") == "locked" and second.active_trade_snapshot.get("status", "") == "locked", "both clients restore locked review snapshot")
	_check(first.begin_reconnect(), "first client reconnect starts")
	var join := first.mark_socket_open(first.socket_generation)
	_check(join.get("tradeId", "") == "shared" and join.get("lastEventSeq", -1) == 3, "reconnect joins from locked snapshot cursor")
	first.free()
	second.free()
	quit(1 if failed else 0)


func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
