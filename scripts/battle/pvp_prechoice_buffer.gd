extends RefCounted

var _window: Dictionary = {}
var _choice: Dictionary = {}


func reset() -> void:
	_window.clear()
	_choice.clear()


func is_window_open() -> bool:
	return not _window.is_empty()


func has_choice() -> bool:
	return not _choice.is_empty()


func open_window(fence: Dictionary, completion: Dictionary, decision: Dictionary) -> bool:
	if not bool(completion.get("success", false)):
		return false

	var event_batch_id := str(fence.get("eventBatchId", "")).strip_edges()
	var batch_seq := int(fence.get("batchSeq", -1))
	var event_seq_end := int(fence.get("eventSeqEnd", -1))
	if event_batch_id == "" or batch_seq < 0 or event_seq_end < 0:
		return false
	if str(completion.get("event_batch_id", "")).strip_edges() != event_batch_id:
		return false
	if int(completion.get("batch_seq", -1)) != batch_seq:
		return false
	if int(completion.get("event_seq_end", -1)) != event_seq_end:
		return false
	if int(completion.get("last_rendered_seq", -1)) < event_seq_end:
		return false

	var decision_id := str(decision.get("decisionId", "")).strip_edges()
	var decision_generation := int(decision.get("decisionGeneration", -1))
	if (
		str(decision.get("status", "")).strip_edges().to_upper() != "ACTIVE"
		or decision_id == ""
		or decision_generation < 0
	):
		return false

	var candidate_window := {
		"event_batch_id": event_batch_id,
		"batch_seq": batch_seq,
		"event_seq_end": event_seq_end,
		"decision_id": decision_id,
		"decision_generation": decision_generation,
	}
	if _window == candidate_window:
		return true
	reset()
	_window = candidate_window
	return true


func remember_choice(choice: Dictionary) -> bool:
	if _window.is_empty():
		return false
	var choice_type := str(choice.get("choice_type", "")).strip_edges()
	var slot := int(choice.get("slot", 0))
	if choice_type not in ["move", "switch"] or slot <= 0:
		return false

	_choice = choice.duplicate(true)
	_choice["decision_id"] = _window.get("decision_id", "")
	_choice["decision_generation"] = _window.get("decision_generation", -1)
	return true


func invalidate_for_fence(fence: Dictionary) -> void:
	if _window.is_empty():
		return
	if not _fence_matches_window(fence):
		reset()


func take_for_release(released_fence: Dictionary, decision: Dictionary) -> Dictionary:
	if _window.is_empty():
		return {}
	if not _fence_matches_window(released_fence) or not _decision_matches_window(decision):
		reset()
		return {}

	var result := _choice.duplicate(true)
	reset()
	return result


func _fence_matches_window(fence: Dictionary) -> bool:
	return (
		str(fence.get("eventBatchId", "")).strip_edges() == str(_window.get("event_batch_id", ""))
		and int(fence.get("batchSeq", -1)) == int(_window.get("batch_seq", -1))
		and int(fence.get("eventSeqEnd", -1)) == int(_window.get("event_seq_end", -1))
	)


func _decision_matches_window(decision: Dictionary) -> bool:
	return (
		str(decision.get("status", "")).strip_edges().to_upper() == "ACTIVE"
		and str(decision.get("decisionId", "")).strip_edges() == str(_window.get("decision_id", ""))
		and int(decision.get("decisionGeneration", -1)) == int(_window.get("decision_generation", -1))
	)
