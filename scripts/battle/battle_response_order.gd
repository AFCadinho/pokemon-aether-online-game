extends RefCounted

class_name BattleResponseOrder

const EVENT_PAYLOAD_KEYS: Array[String] = [
	"events",
	"eventBatches",
	"eventBatchId",
	"eventSeq",
	"batchSeq",
	"pvpRealtimeMessageType",
	"pvpBattleUpdateFallbackRender",
]
const RENDER_METADATA_KEY := "_paoRenderMetadata"

var latest_cursor: Dictionary = {}
var latest_response: Dictionary = {}


func reset(initial_response: Dictionary = {}) -> void:
	latest_cursor.clear()
	latest_response.clear()
	if not initial_response.is_empty():
		remember(initial_response)


func is_stale(response: Dictionary) -> bool:
	if response.is_empty() or latest_cursor.is_empty():
		return false
	return compare_cursors(cursor_for_response(response), latest_cursor) < 0


func remember(response: Dictionary) -> bool:
	if response.is_empty():
		return false

	var incoming_cursor := cursor_for_response(response)
	if not latest_cursor.is_empty() and compare_cursors(incoming_cursor, latest_cursor) < 0:
		return false

	latest_cursor = incoming_cursor
	latest_response = response.duplicate(true)
	return true


func latest_projection_for(response: Dictionary) -> Dictionary:
	if latest_response.is_empty():
		return response.duplicate(true)
	if response.is_empty():
		return latest_response.duplicate(true)

	var response_battle_id := str(response.get("battleId", "")).strip_edges()
	var latest_battle_id := str(latest_response.get("battleId", "")).strip_edges()
	if response_battle_id != "" and latest_battle_id != "" and response_battle_id != latest_battle_id:
		return response.duplicate(true)

	if compare_cursors(cursor_for_response(response), latest_cursor) < 0:
		return latest_response.duplicate(true)
	return response.duplicate(true)


func merge_latest_projection_with_events(event_response: Dictionary) -> Dictionary:
	var merged := latest_projection_for(event_response)
	for key in EVENT_PAYLOAD_KEYS:
		if event_response.has(key):
			merged[key] = _duplicate_variant(event_response[key])
	merged[RENDER_METADATA_KEY] = {
		"phase": str(event_response.get("phase", "")).strip_edges(),
		"nextPhase": str(event_response.get("nextPhase", event_response.get("next_phase", ""))).strip_edges(),
		"turn": _response_turn(event_response),
	}
	return merged


func render_batch_projection_for(response: Dictionary) -> Dictionary:
	var render_response := response.duplicate(true)
	var metadata_value: Variant = response.get(RENDER_METADATA_KEY, {})
	var metadata: Dictionary = metadata_value as Dictionary if metadata_value is Dictionary else {}
	var batch := _last_event_batch(response)

	for key in ["phase", "nextPhase", "turn"]:
		if batch.has(key):
			render_response[key] = _duplicate_variant(batch[key])
		elif metadata.has(key) and str(metadata[key]).strip_edges() != "":
			render_response[key] = _duplicate_variant(metadata[key])

	render_response.erase(RENDER_METADATA_KEY)
	return render_response


static func cursor_for_response(response: Dictionary) -> Dictionary:
	return {
		"battle_id": str(response.get("battleId", "")).strip_edges(),
		"event_seq": _response_event_seq(response),
		"batch_seq": _response_batch_seq(response),
		"turn": _response_turn(response),
		"timer_revision": _response_timer_revision(response),
		"decision_generation": _response_decision_generation(response),
		"server_seq": _response_server_seq(response),
	}


static func compare_cursors(incoming: Dictionary, current: Dictionary) -> int:
	var incoming_battle_id := str(incoming.get("battle_id", ""))
	var current_battle_id := str(current.get("battle_id", ""))
	if incoming_battle_id != "" and current_battle_id != "" and incoming_battle_id != current_battle_id:
		return -1

	# Mechanical progress is stronger than delivery order. A late transport
	# message can have a newer server sequence while carrying an older battle
	# projection, so event/batch/turn cursors are compared first.
	for key in ["event_seq", "batch_seq", "turn"]:
		var comparison := _compare_known_ints(incoming, current, key, -1)
		if comparison != 0:
			return comparison

	# These cursors distinguish request/phase changes that do not produce a new
	# rendered battle event.
	for key in ["timer_revision", "decision_generation", "server_seq"]:
		var comparison := _compare_known_ints(incoming, current, key, 0)
		if comparison != 0:
			return comparison

	# An unversioned response cannot displace a projection for which the client
	# already has monotone evidence.
	for key in ["event_seq", "batch_seq", "turn"]:
		if int(current.get(key, -1)) >= 0 and int(incoming.get(key, -1)) < 0:
			return -1
	for key in ["timer_revision", "decision_generation", "server_seq"]:
		if int(current.get(key, 0)) > 0 and int(incoming.get(key, 0)) <= 0:
			return -1

	return 0


static func _compare_known_ints(incoming: Dictionary, current: Dictionary, key: String, unknown: int) -> int:
	var incoming_value := int(incoming.get(key, unknown))
	var current_value := int(current.get(key, unknown))
	if incoming_value == unknown or current_value == unknown or incoming_value == current_value:
		return 0
	return 1 if incoming_value > current_value else -1


static func _response_event_seq(response: Dictionary) -> int:
	var direct := _safe_int(response.get("eventSeq", -1), -1)
	if direct >= 0:
		return direct
	return _last_batch_int(response, "eventSeqEnd")


static func _response_batch_seq(response: Dictionary) -> int:
	var direct := _safe_int(response.get("batchSeq", -1), -1)
	if direct >= 0:
		return direct
	return _last_batch_int(response, "batchSeq")


static func _last_batch_int(response: Dictionary, key: String) -> int:
	var batches_value: Variant = response.get("eventBatches", [])
	if not (batches_value is Array):
		return -1
	var batches: Array = batches_value as Array
	for index in range(batches.size() - 1, -1, -1):
		var batch_value: Variant = batches[index]
		if not (batch_value is Dictionary):
			continue
		var value := _safe_int((batch_value as Dictionary).get(key, -1), -1)
		if value >= 0:
			return value
	return -1


static func _last_event_batch(response: Dictionary) -> Dictionary:
	var batches_value: Variant = response.get("eventBatches", [])
	if not (batches_value is Array):
		return {}
	var batches: Array = batches_value as Array
	for index in range(batches.size() - 1, -1, -1):
		var batch_value: Variant = batches[index]
		if batch_value is Dictionary:
			return batch_value as Dictionary
	return {}


static func _response_turn(response: Dictionary) -> int:
	var state_value: Variant = response.get("state", {})
	if state_value is Dictionary:
		var state_turn := _safe_int((state_value as Dictionary).get("turn", -1), -1)
		if state_turn >= 0:
			return state_turn
	return _safe_int(response.get("turn", -1), -1)


static func _response_timer_revision(response: Dictionary) -> int:
	var timer_value: Variant = response.get("timerState", {})
	if timer_value is Dictionary:
		return _safe_int((timer_value as Dictionary).get("timerRevision", 0), 0)
	return 0


static func _response_decision_generation(response: Dictionary) -> int:
	var decisions_value: Variant = response.get("decisions", {})
	if not (decisions_value is Dictionary):
		return 0
	var latest_generation := 0
	for decision_value: Variant in (decisions_value as Dictionary).values():
		if decision_value is Dictionary:
			latest_generation = max(
				latest_generation,
				_safe_int((decision_value as Dictionary).get("decisionGeneration", 0), 0)
			)
	return latest_generation


static func _response_server_seq(response: Dictionary) -> int:
	var direct := _safe_int(response.get("pvpServerSeq", 0), 0)
	if direct > 0:
		return direct
	return _safe_int(response.get("serverSeq", 0), 0)


static func _safe_int(value: Variant, fallback: int) -> int:
	if value is int:
		return int(value)
	if value is float:
		return int(value)
	var text := str(value).strip_edges()
	return int(text) if text.is_valid_int() else fallback


static func _duplicate_variant(value: Variant) -> Variant:
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	if value is Array:
		return (value as Array).duplicate(true)
	return value
