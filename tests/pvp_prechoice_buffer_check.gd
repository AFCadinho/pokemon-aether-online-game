extends SceneTree

const PrechoiceBuffer := preload("res://scripts/battle/pvp_prechoice_buffer.gd")

var failed := false


func _init() -> void:
	_check_happy_path_and_choice_replacement()
	_check_stale_boundaries_are_rejected()
	quit(1 if failed else 0)


func _check_happy_path_and_choice_replacement() -> void:
	var buffer = PrechoiceBuffer.new()
	var fence := _fence()
	var completion := _completion()
	var decision := _decision("decision-7", 7)

	_check(buffer.open_window(fence, completion, decision), "completed local render opens prechoice window")
	_check(buffer.remember_choice({"choice_type": "move", "slot": 1}), "first local choice is buffered")
	_check(buffer.remember_choice({"choice_type": "move", "slot": 3, "mega": true}), "local choice can be changed before release")
	_check(buffer.open_window(fence, completion, decision), "idempotent snapshot keeps the same prechoice window open")
	_check(buffer.has_choice(), "idempotent snapshot does not erase the saved choice")
	var released: Dictionary = buffer.take_for_release(fence, decision)
	_check_equal(released.get("slot"), 3, "release takes the latest local choice")
	_check_equal(released.get("decision_id"), "decision-7", "choice remains tied to its private decision identity")
	_check(not buffer.is_window_open(), "release closes the local window")
	_check(not buffer.has_choice(), "release consumes the local choice once")


func _check_stale_boundaries_are_rejected() -> void:
	var buffer = PrechoiceBuffer.new()
	var fence := _fence()
	var completion := _completion()
	var decision := _decision("decision-7", 7)

	var wrong_completion := completion.duplicate(true)
	wrong_completion["event_batch_id"] = "other-batch"
	_check(not buffer.open_window(fence, wrong_completion, decision), "unrelated render completion cannot open prechoice")

	_check(buffer.open_window(fence, completion, decision), "valid window reopens")
	_check(buffer.remember_choice({"choice_type": "switch", "slot": 4}), "switch is buffered")
	_check(buffer.take_for_release(fence, _decision("decision-8", 8)).is_empty(), "new decision invalidates stale choice")

	_check(buffer.open_window(fence, completion, decision), "valid window opens after stale decision test")
	_check(buffer.remember_choice({"choice_type": "move", "slot": 2}), "move is buffered before newer fence")
	var newer_fence := fence.duplicate(true)
	newer_fence["eventBatchId"] = "batch-8"
	newer_fence["batchSeq"] = 8
	newer_fence["eventSeqEnd"] = 45
	buffer.invalidate_for_fence(newer_fence)
	_check(not buffer.is_window_open(), "new render fence clears the previous window")
	_check(buffer.take_for_release(fence, decision).is_empty(), "cleared choice cannot leak into a later release")


func _fence() -> Dictionary:
	return {
		"releasePending": true,
		"eventBatchId": "batch-7",
		"batchSeq": 7,
		"eventSeqEnd": 42,
	}


func _completion() -> Dictionary:
	return {
		"success": true,
		"event_batch_id": "batch-7",
		"batch_seq": 7,
		"event_seq_end": 42,
		"last_rendered_seq": 42,
	}


func _decision(decision_id: String, generation: int) -> Dictionary:
	return {
		"status": "ACTIVE",
		"decisionId": decision_id,
		"decisionGeneration": generation,
		"decisionKind": "MOVE_SELECTION",
	}


func _check(condition: bool, label: String) -> void:
	if condition:
		return
	failed = true
	push_error(label)


func _check_equal(actual: Variant, expected: Variant, label: String) -> void:
	_check(actual == expected, "%s expected=%s actual=%s" % [label, var_to_str(expected), var_to_str(actual)])
