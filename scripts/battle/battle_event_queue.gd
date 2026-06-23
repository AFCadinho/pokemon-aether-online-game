extends RefCounted
class_name BattleEventQueue

var is_rendering := false
var pending_updates: Array[Dictionary] = []
var seen_event_batch_ids: Dictionary = {}
var seen_batch_seqs: Dictionary = {}
var last_event_seq := -1
var debug_enabled := false
var _next_id := 1

func clear() -> void:
	pending_updates.clear()
	is_rendering = false
	seen_event_batch_ids.clear()
	seen_batch_seqs.clear()
	last_event_seq = -1

func has_pending() -> bool:
	return not pending_updates.is_empty()

func enqueue_response(response: Dictionary, source: String, apply_event_conditions := true, metadata: Dictionary = {}) -> Dictionary:
	var normalized_response: Dictionary = response.duplicate(true)
	var dedupe: Dictionary = _dedupe_metadata_for_response(normalized_response)
	var entry_metadata: Dictionary = metadata.duplicate(true)
	var queue_id: int = _next_id
	_next_id += 1

	if dedupe.should_drop:
		var duplicate_entry := {
			"id": queue_id,
			"source": source,
			"response": normalized_response,
			"apply_event_conditions": apply_event_conditions,
			"skip_render": true,
			"metadata": entry_metadata,
		}
		pending_updates.append(duplicate_entry)
		if debug_enabled:
			print("[BattleEventQueue] enqueue source=%s skip_render=true batchSeq=%d eventSeq=%d p1ForceSwitch=%s p2ForceSwitch=%s duplicate_reason=%s" % [
				source,
				_get_batch_seq(normalized_response),
				_get_event_seq(normalized_response),
				_describe_response_force_switch(normalized_response, "p1"),
				_describe_response_force_switch(normalized_response, "p2"),
				str(dedupe.reason),
			])
		return {
			"enqueued": true,
			"duplicate": true,
			"key": dedupe.key,
			"reason": dedupe.reason,
			"source": source,
			"response": normalized_response,
			"skip_render": true,
			"apply_event_conditions": apply_event_conditions,
			"id": queue_id,
		}

	if dedupe.was_recorded and dedupe.key != "":
		if dedupe.kind == "batch_seq":
			seen_batch_seqs[str(dedupe.value)] = true
		elif dedupe.kind == "event_batch_id":
			seen_event_batch_ids[dedupe.key] = true
		elif dedupe.kind == "event_seq":
			last_event_seq = int(dedupe.value)

	var entry := {
		"id": queue_id,
		"source": source,
		"response": normalized_response,
		"apply_event_conditions": apply_event_conditions,
		"skip_render": false,
		"metadata": entry_metadata,
	}
	pending_updates.append(entry)

	if debug_enabled:
		print("[BattleEventQueue] enqueue source=%s skip_render=false batchSeq=%d eventSeq=%d p1ForceSwitch=%s p2ForceSwitch=%s" % [
			source,
			_get_batch_seq(normalized_response),
			_get_event_seq(normalized_response),
			_describe_response_force_switch(normalized_response, "p1"),
			_describe_response_force_switch(normalized_response, "p2"),
		])

	return {
		"enqueued": true,
		"duplicate": false,
		"key": dedupe.key,
		"response": normalized_response,
		"source": source,
		"id": queue_id,
	}

func dequeue_next() -> Dictionary:
	if pending_updates.is_empty():
		return {}
	return pending_updates.pop_front()

func _dedupe_metadata_for_response(response: Dictionary) -> Dictionary:
	var event_batch_id := _get_event_batch_id(response)
	if event_batch_id != "":
		if seen_event_batch_ids.has(event_batch_id):
			return {
				"should_drop": true,
				"reason": "eventBatchId already seen",
				"key": event_batch_id,
			}
		return {
				"should_drop": false,
				"was_recorded": true,
				"kind": "event_batch_id",
				"value": event_batch_id,
				"key": event_batch_id,
			}

	var batch_seq := _get_batch_seq(response)
	if batch_seq > 0:
		var batch_seq_key := str(batch_seq)
		if seen_batch_seqs.has(batch_seq_key):
			return {
				"should_drop": true,
				"reason": "batchSeq already seen",
				"key": batch_seq_key,
			}
		return {
				"should_drop": false,
				"was_recorded": true,
				"kind": "batch_seq",
				"value": batch_seq,
				"key": batch_seq_key,
			}

	var event_seq := _get_event_seq(response)
	if event_seq > 0:
		if event_seq <= last_event_seq:
			return {
				"should_drop": true,
				"reason": "eventSeq already seen or behind cursor",
				"key": str(event_seq),
			}
		return {
				"should_drop": false,
				"was_recorded": true,
				"kind": "event_seq",
				"value": event_seq,
				"key": str(event_seq),
			}

	return {
		"should_drop": false,
		"was_recorded": false,
		"key": "",
		}

func _get_event_batch_id(response: Dictionary) -> String:
	var event_batch_id := str(response.get("eventBatchId", "")).strip_edges()
	if event_batch_id != "":
		return event_batch_id

	var event_batches: Variant = response.get("eventBatches", [])
	if event_batches is Array:
		var batches: Array = event_batches as Array
		if not batches.is_empty():
			var last_batch: Dictionary = batches[batches.size() - 1] if (batches[batches.size() - 1] is Dictionary) else {}
			var last_batch_id := str(last_batch.get("eventBatchId", "")).strip_edges()
			if last_batch_id != "":
				return last_batch_id

	return ""

func _get_batch_seq(response: Dictionary) -> int:
	var batch_seq := int(response.get("batchSeq", 0))
	if batch_seq > 0:
		return batch_seq

	var event_batches: Variant = response.get("eventBatches", [])
	if event_batches is Array:
		var batches: Array = event_batches as Array
		if not batches.is_empty():
			var last_batch: Dictionary = batches[batches.size() - 1] if (batches[batches.size() - 1] is Dictionary) else {}
			var last_batch_seq := int(last_batch.get("batchSeq", 0))
			if last_batch_seq > 0:
				return last_batch_seq

	return 0

func _get_event_seq(response: Dictionary) -> int:
	var event_seq := int(response.get("eventSeq", 0))
	if event_seq > 0:
		return event_seq

	var event_batches: Variant = response.get("eventBatches", [])
	if event_batches is Array:
		var batches: Array = event_batches as Array
		if not batches.is_empty():
			var last_batch: Dictionary = batches[batches.size() - 1] if (batches[batches.size() - 1] is Dictionary) else {}
			var last_event_seq := int(last_batch.get("eventSeqEnd", 0))
			if last_event_seq > 0:
				return last_event_seq

	return 0

func _describe_response_force_switch(response: Dictionary, player_id: String) -> String:
	var requests_value: Variant = response.get("requests", {})
	if not (requests_value is Dictionary):
		return "missing"

	var request_value: Variant = (requests_value as Dictionary).get(player_id, {})
	if not (request_value is Dictionary):
		return "missing"

	var force_switch_value: Variant = (request_value as Dictionary).get("forceSwitch", [])
	if force_switch_value is Array:
		return str(force_switch_value)

	return str(force_switch_value)
