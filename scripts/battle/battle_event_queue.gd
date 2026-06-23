extends RefCounted
class_name BattleEventQueue

var is_rendering := false
var pending_updates: Array[Dictionary] = []
var seen_event_batch_ids: Dictionary = {}
var seen_batch_seqs: Dictionary = {}
var last_event_seq := -1
var current_event_batch_id := ""
var current_batch_seq := -1
var current_event_seq_end := -1
var last_rendered_seq := -1
var debug_enabled := false
var render_completed_callback: Callable = Callable()
var _next_id := 1

func clear() -> void:
	pending_updates.clear()
	is_rendering = false
	seen_event_batch_ids.clear()
	seen_batch_seqs.clear()
	last_event_seq = -1
	current_event_batch_id = ""
	current_batch_seq = -1
	current_event_seq_end = -1
	last_rendered_seq = -1

func has_pending() -> bool:
	return not pending_updates.is_empty()

func set_render_completed_callback(callback: Callable) -> void:
	render_completed_callback = callback

func begin_render_batch(response: Dictionary, source: String = "") -> Dictionary:
	if current_event_batch_id != "":
		if debug_enabled:
			print("[BattleEventQueue] render batch already active current=%s source=%s" % [
				current_event_batch_id,
				source,
			])
		return {
			"started": false,
			"reason": "render batch already active",
			"current_event_batch_id": current_event_batch_id,
		}

	var event_batch_id := get_response_event_batch_id(response)
	var batch_seq := get_response_batch_seq(response)
	var event_seq_end := get_response_event_seq_end(response)
	var turn := _get_response_turn(response)
	var phase := str(response.get("phase", "")).strip_edges()
	if event_batch_id == "":
		event_batch_id = "%s:%d:%d" % [source if source != "" else "pvp_render", batch_seq, event_seq_end]

	current_event_batch_id = event_batch_id
	current_batch_seq = batch_seq
	current_event_seq_end = event_seq_end

	return {
		"started": true,
		"event_batch_id": current_event_batch_id,
		"batch_seq": current_batch_seq,
		"event_seq_end": current_event_seq_end,
		"turn": turn,
		"phase": phase,
		"source": source,
	}

func complete_render_batch(context: Dictionary, success := true) -> void:
	var context_batch_id := str(context.get("event_batch_id", ""))
	var context_event_seq_end := int(context.get("event_seq_end", -1))
	var context_batch_seq := int(context.get("batch_seq", -1))
	var context_source := str(context.get("source", ""))
	var context_turn := int(context.get("turn", -1))
	var context_phase := str(context.get("phase", "")).strip_edges()

	if success and context_event_seq_end > last_rendered_seq:
		last_rendered_seq = context_event_seq_end

	var completion := {
		"event_batch_id": context_batch_id,
		"batch_seq": context_batch_seq,
		"event_seq_end": context_event_seq_end,
		"last_rendered_seq": last_rendered_seq,
		"turn": context_turn,
		"phase": context_phase,
		"source": context_source,
		"success": success,
	}
	if render_completed_callback.is_valid():
		render_completed_callback.call(completion)

	if context_batch_id == "" or context_batch_id == current_event_batch_id:
		current_event_batch_id = ""
		current_batch_seq = -1
		current_event_seq_end = -1

func get_response_event_batch_id(response: Dictionary) -> String:
	return _get_event_batch_id(response)

func get_response_batch_seq(response: Dictionary) -> int:
	return _get_batch_seq(response)

func get_response_event_seq_end(response: Dictionary) -> int:
	return _get_event_seq(response)

func enqueue_response(response: Dictionary, source: String, apply_event_conditions := true, metadata: Dictionary = {}) -> Dictionary:
	var normalized_response: Dictionary = response.duplicate(true)
	var dedupe: Dictionary = _dedupe_metadata_for_response(normalized_response)
	var entry_metadata: Dictionary = metadata.duplicate(true)
	var queue_id: int = _next_id
	_next_id += 1

	if dedupe.should_drop:
		if bool(entry_metadata.get("drop_duplicate", false)):
			return {
				"enqueued": false,
				"duplicate": true,
				"dropped": true,
				"key": dedupe.key,
				"reason": dedupe.reason,
				"source": source,
				"skip_render": true,
				"apply_event_conditions": apply_event_conditions,
				"id": queue_id,
			}

		var duplicate_entry := {
			"id": queue_id,
			"source": source,
			"response": normalized_response,
			"apply_event_conditions": apply_event_conditions,
			"skip_render": true,
			"metadata": entry_metadata,
		}
		pending_updates.append(duplicate_entry)
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
	var event_seq := -1
	if response.has("eventSeq"):
		event_seq = int(response.get("eventSeq", -1))
	if event_seq >= 0:
		return event_seq

	var event_batches: Variant = response.get("eventBatches", [])
	if event_batches is Array:
		var batches: Array = event_batches as Array
		if not batches.is_empty():
			var last_batch: Dictionary = batches[batches.size() - 1] if (batches[batches.size() - 1] is Dictionary) else {}
			var last_event_seq := int(last_batch.get("eventSeqEnd", -1))
			if last_event_seq >= 0:
				return last_event_seq

	return -1

func _get_response_turn(response: Dictionary) -> int:
	var turn := int(response.get("turn", -1))
	if turn >= 0:
		return turn

	var state_value: Variant = response.get("state", {})
	if state_value is Dictionary:
		return int((state_value as Dictionary).get("turn", -1))

	return -1
