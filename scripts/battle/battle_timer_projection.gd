extends RefCounted

class_name BattleTimerProjection

const CONTRACT_VERSION := 1
const LARGE_DRIFT_MS := 750

var authority := "LEGACY_PHASE_V1"
var timer_revision := 0
var aggregate_revision := 0
var battle_event_seq := 0
var participants: Dictionary = {}
var server_anchor_ms := 0
var monotonic_anchor_ms := 0
var contract_enabled := false
var mechanically_suspended := false


func reset() -> void:
	authority = "LEGACY_PHASE_V1"
	timer_revision = 0
	aggregate_revision = 0
	battle_event_seq = 0
	participants = {}
	server_anchor_ms = 0
	monotonic_anchor_ms = 0
	contract_enabled = false
	mechanically_suspended = false


func should_present(is_pvp_battle: bool, debug_visibility_override: bool = true) -> bool:
	return is_pvp_battle and contract_enabled and debug_visibility_override


func apply_snapshot(snapshot: Dictionary, local_monotonic_ms: int = Time.get_ticks_msec()) -> bool:
	if int(snapshot.get("timerContractVersion", 0)) != CONTRACT_VERSION:
		return false
	var incoming_revision := int(snapshot.get("timerRevision", 0))
	if incoming_revision < timer_revision:
		return false
	authority = str(snapshot.get("authority", "LEGACY_PHASE_V1"))
	timer_revision = incoming_revision
	aggregate_revision = int(snapshot.get("aggregateRevision", aggregate_revision))
	battle_event_seq = int(snapshot.get("battleEventSeq", battle_event_seq))
	participants = (snapshot.get("participants", {}) as Dictionary).duplicate(true)
	_sample_server_time(_server_ms(snapshot), local_monotonic_ms, true)
	contract_enabled = authority in ["BATTLE_BANK_V1_SHADOW", "BATTLE_BANK_V1"]
	return true


func apply_event(event: Dictionary, local_monotonic_ms: int = Time.get_ticks_msec()) -> bool:
	var seq := int(event.get("battleEventSeq", 0))
	if seq > 0 and seq <= battle_event_seq:
		return false
	var payload_value: Variant = event.get("payload", {})
	var payload: Dictionary = payload_value as Dictionary if payload_value is Dictionary else {}
	var incoming_revision := int(payload.get("timerRevision", timer_revision))
	if incoming_revision < timer_revision:
		battle_event_seq = max(battle_event_seq, seq)
		return false
	var player_id := str(payload.get("playerId", ""))
	if player_id in ["p1", "p2"]:
		var current: Dictionary = (participants.get(player_id, {}) as Dictionary).duplicate(true)
		var incoming_generation := int(payload.get("decisionGeneration", current.get("decisionGeneration", 0)))
		if incoming_generation < int(current.get("decisionGeneration", 0)):
			battle_event_seq = max(battle_event_seq, seq)
			return false
		for key: Variant in payload.keys():
			if key not in ["privatePayload", "selectedAction", "legalActions", "rngState", "rngReference", "requestFingerprint"]:
				current[key] = payload[key]
		participants[player_id] = current
	if payload.has("participants") and payload.get("participants") is Dictionary:
		participants = (payload.get("participants") as Dictionary).duplicate(true)
	timer_revision = incoming_revision
	battle_event_seq = max(battle_event_seq, seq)
	if payload.has("serverNow") or payload.has("serverNowMs"):
		_sample_server_time(_server_ms(payload), local_monotonic_ms, false)
	return true


func mark_event_applied(seq: int) -> void:
	battle_event_seq = max(battle_event_seq, seq)


func resync(server_now_ms: int, local_monotonic_ms: int = Time.get_ticks_msec()) -> void:
	_sample_server_time(server_now_ms, local_monotonic_ms, true)


func estimated_server_now_ms(local_monotonic_ms: int = Time.get_ticks_msec()) -> int:
	return server_anchor_ms + max(local_monotonic_ms - monotonic_anchor_ms, 0)


func participant_display(player_id: String, local_monotonic_ms: int = Time.get_ticks_msec()) -> Dictionary:
	var timer_value: Variant = participants.get(player_id, {})
	if not (timer_value is Dictionary):
		return {}
	var timer: Dictionary = timer_value as Dictionary
	var now := estimated_server_now_ms(local_monotonic_ms)
	var actionable := _timestamp_ms(timer, "actionableAtMs", "actionableAt")
	var charge_start := _timestamp_ms(timer, "bankChargeStartsAtMs", "bankChargeStartsAt")
	var cap_at := _timestamp_ms(timer, "decisionCapAtMs", "decisionCapAt")
	var exhaustion_at := _timestamp_ms(timer, "bankExhaustionAtMs", "bankExhaustionAt")
	var deadline := _timestamp_ms(timer, "hypotheticalDeadlineAtMs", "deadlineAt")
	var bank_anchor := int(timer.get("mainBankRemainingMs", timer.get("bankAtAnchorMs", 0)))
	var bank := bank_anchor
	if not mechanically_suspended and charge_start > 0 and now > charge_start and str(timer.get("status", "")) in ["RUNNING", "ACTIVE", "DECIDING"]:
		bank = max(bank_anchor - (now - charge_start), 0)
	var scheduled_remaining: int = max(actionable - now, 0) if actionable > 0 else 0
	var cap_remaining: int = max(cap_at - now, 0) if cap_at > 0 else 0
	var effective_remaining: int = max(deadline - now, 0) if deadline > 0 else 0
	var state: String = "PAUSED" if mechanically_suspended else _display_state(timer, now, actionable, deadline)
	return {
		"playerId": player_id,
		"state": state,
		"bankRemainingMs": bank,
		"bankMaximumMs": int(timer.get("mainBankMaximumMs", 0)),
		"decisionCapRemainingMs": cap_remaining,
		"effectiveDecisionRemainingMs": effective_remaining,
		"scheduledRemainingMs": scheduled_remaining,
		"bankExhaustionRemainingMs": max(exhaustion_at - now, 0) if exhaustion_at > 0 else 0,
		"decisionId": str(timer.get("decisionId", "")),
		"decisionGeneration": int(timer.get("decisionGeneration", 0)),
		"decisionKind": str(timer.get("decisionKind", "")),
	}


func apply_operational_state(value: Dictionary) -> void:
	mechanically_suspended = not bool(value.get("timerConsequencesEnabled", true))


func _display_state(timer: Dictionary, now: int, actionable: int, deadline: int) -> String:
	var raw := str(timer.get("status", "IDLE")).to_upper()
	if raw in ["ENDED", "BATTLE_ENDED"]:
		return "ENDED"
	if raw in ["PAUSED", "FROZEN"]:
		return "PAUSED"
	if raw in ["LOCKED", "WAITING", "CHOICE_ACCEPTED", "IDLE"]:
		return "WAITING"
	if raw in ["EXPIRED", "WOULD_EXPIRE"] or (deadline > 0 and now >= deadline):
		return "EXPIRED"
	if actionable > now:
		return "SCHEDULED"
	return "DECIDING"


func _sample_server_time(server_ms: int, local_ms: int, force_snap: bool) -> void:
	if server_ms <= 0:
		return
	var predicted := estimated_server_now_ms(local_ms) if server_anchor_ms > 0 else server_ms
	if force_snap or abs(server_ms - predicted) >= LARGE_DRIFT_MS or server_anchor_ms == 0:
		server_anchor_ms = server_ms
	else:
		# Conservative smoothing never adds the full positive correction in one frame.
		server_anchor_ms = predicted + int(min(server_ms - predicted, 0) if server_ms > predicted else (server_ms - predicted) / 2.0)
	monotonic_anchor_ms = local_ms


func _server_ms(value: Dictionary) -> int:
	if value.has("serverNowMs"):
		return int(value.get("serverNowMs"))
	return _iso_ms(str(value.get("serverNow", "")))


func _timestamp_ms(value: Dictionary, numeric_key: String, iso_key: String) -> int:
	if value.has(numeric_key) and value.get(numeric_key) != null:
		return int(value.get(numeric_key))
	return _iso_ms(str(value.get(iso_key, "")))


func _iso_ms(value: String) -> int:
	if value.strip_edges() == "":
		return 0
	return int(Time.get_unix_time_from_datetime_string(value) * 1000.0)
