extends SceneTree
const Service := preload("res://scripts/services/trade_realtime_service.gd")
var failed := false
var service: Node
var applied: Array = []
var gaps := 0
var offer_updates := 0
class FakeTradeService extends Node:
	var failures := 0
	var active_trade: Dictionary = {"tradeId":"restored", "status":"invited", "revision":1, "lastEventSeq":2}
	var discovery_calls := 0
	func load_active_trade() -> Dictionary:
		discovery_calls += 1
		return {"success": true, "hasActiveTrade": true, "trade": active_trade}
	func load_trade(_id: String) -> Dictionary:
		if failures > 0:
			failures -= 1
			return {"success": false}
		return {"success": true, "trade": {"tradeId":"t", "revision":6, "lastEventSeq":5}}
	func load_trade_events(_id: String, _after: int, _limit: int) -> Dictionary:
		return {"success": true, "events": {"events": []}}
func _init() -> void:
	service = Service.new()
	service.event_received.connect(func(event): applied.append(event.get("eventSeq")))
	service.recovery_required.connect(func(_id, _seq): gaps += 1)
	service.offer_update_received.connect(func(_event): offer_updates += 1)
	service.apply_snapshot({"tradeId":"t", "revision":2, "lastEventSeq":2})
	service.apply_event({"tradeId":"t", "eventSeq":2})
	service.apply_event({"tradeId":"t", "eventSeq":4})
	_check(gaps == 1, "gap detected")
	service.apply_recovery({"tradeId":"t", "revision":4, "lastEventSeq":3}, [{"tradeId":"t", "eventSeq":4}])
	_check(service.last_applied_event_seq == 4, "recovery applies contiguous replay")
	service.apply_event({"tradeId":"t", "eventSeq":5, "revision":5, "type":"trade.offer_updated", "payload":{"offers":[]}})
	service.apply_event({"tradeId":"t", "eventSeq":5, "revision":5, "type":"trade.offer_updated", "payload":{"offers":[]}})
	_check(offer_updates == 1, "duplicate offer event suppressed")
	service.recovery_in_progress = true
	service.apply_event({"tradeId":"t", "eventSeq":6})
	service.apply_recovery({"tradeId":"t", "revision":6, "lastEventSeq":5}, [])
	_check(service.last_applied_event_seq == 6, "buffered live event drains after recovery")
	service.apply_snapshot({"tradeId":"t", "revision":1, "lastEventSeq":1})
	_check(service.last_applied_event_seq == 6, "stale snapshot ignored")
	service.clear_active_trade()
	service.apply_event({"tradeId":"t", "eventSeq":5})
	_check(service.last_applied_event_seq == 0, "cleared trade ignores old event")
	var fake := FakeTradeService.new()
	service.trade_service_override = fake
	service.apply_snapshot({"tradeId":"t", "revision":1, "lastEventSeq":1})
	service.recovery_in_progress = true
	fake.failures = 3
	await service.recover_from_rest()
	await service.recover_from_rest()
	await service.recover_from_rest()
	await service.recover_from_rest()
	_check(service.recovery_attempts == 3, "REST recovery attempts are bounded")
	service.clear_active_trade()
	service.apply_snapshot({"tradeId":"t", "revision":2, "lastEventSeq":6})
	_check(service.begin_reconnect(), "reconnect starts")
	_check(not service.begin_reconnect(), "parallel reconnect prevented")
	var generation: int = service.socket_generation
	var join: Dictionary = service.mark_socket_open(generation)
	_check(join.get("lastEventSeq", -1) == 6, "reconnect join preserves cursor")
	service.handle_transport_message({"v":1, "type":"trade.event", "event":{"tradeId":"t", "eventSeq":7}}, generation - 1)
	_check(service.last_applied_event_seq == 6, "stale socket generation ignored")
	service.mark_socket_closed(generation)
	_check(service.should_reconnect and service.last_applied_event_seq == 6, "disconnect preserves reconnect cursor")
	service.clear_active_trade()
	_check(not service.begin_reconnect(), "clear cancels reconnect")
	service.trade_service_override = fake
	var discovered: Dictionary = await service.discover_active_trade()
	_check(bool(discovered.get("hasActiveTrade", false)), "incoming invitation is discovered without a trade socket")
	_check(service.active_trade_id == "restored", "discovery applies authoritative invitation snapshot")
	fake.active_trade = {"tradeId":"restored", "status":"active", "revision":2, "lastEventSeq":3}
	var reconciled: Dictionary = await service.discover_active_trade()
	_check(str(reconciled.get("trade", {}).get("status", "")) == "active", "pending invitation reconciles accepted trade through REST")
	_check(str(service.active_trade_snapshot.get("status", "")) == "active", "accepted snapshot supersedes waiting invitation")
	_check(service._needs_active_trade_discovery(), "active trade continues authoritative reconciliation")
	service.clear_active_trade()
	fake.active_trade = {"tradeId":"restored", "status":"invited", "revision":1, "lastEventSeq":2}
	await service.restore_active_trade_and_connect()
	_check(service.active_trade_id == "restored", "active invitation restored authoritatively")
	_check(service.last_applied_event_seq == 2, "active restore preserves durable cursor")
	_check(fake.discovery_calls >= 2, "active trade discovery uses the authoritative endpoint")
	fake.free()
	quit(1 if failed else 0)
func _check(value: bool, label: String) -> void:
	if not value:
		failed = true
		push_error(label)
