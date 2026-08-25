extends SceneTree

const NPC_SERVICE_FIXTURE := "res://tests/support/fake_npc_metadata_service.gd"
const DIALOGUE_SERVICE_FIXTURE := "res://tests/support/fake_dialogue_metadata_service.gd"
const BASE_NPC_SCRIPT := "res://scripts/world/npcs/base_npc.gd"
const DIALOGUE_NPC_SCRIPT := "res://scripts/world/npcs/dialogue_npc.gd"

class MetadataRequestCaller extends Node:
	signal finished(result: Dictionary)

	var service: Node
	var request_method: StringName
	var request_id := ""


	func _ready() -> void:
		var result_value: Variant = await service.call(request_method, request_id)
		finished.emit(result_value as Dictionary if result_value is Dictionary else {})

var failed := false
var completed_results: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _check_npc_request_coalescing()
	await _check_dialogue_request_coalescing()
	_check_proximity_prefetch_contract()
	_check_manual_interaction_frame_barrier()
	quit(1 if failed else 0)


func _check_npc_request_coalescing() -> void:
	var service_script := load(NPC_SERVICE_FIXTURE) as GDScript
	_check_equal(service_script != null, true, "NPC metadata coalescing fixture loads")
	if service_script == null:
		return
	var service := service_script.new() as Node
	root.add_child(service)
	completed_results.clear()
	_add_request_caller(service, &"get_npc_metadata", "test_npc")
	_add_request_caller(service, &"get_npc_metadata", "test_npc")
	await process_frame
	_check_equal(service.fetch_count, 1, "concurrent NPC metadata lookups share one request")
	service.release_fetch.emit()
	await _wait_for_completed_results(2)
	_check_equal(completed_results.size(), 2, "both NPC metadata callers receive a result")
	for result: Dictionary in completed_results:
		_check_equal(
			str((result.get("metadata", {}) as Dictionary).get("dialogueId", "")),
			"test_dialogue",
			"coalesced NPC metadata is normalized for every caller"
		)
	completed_results.clear()
	_add_request_caller(service, &"get_npc_metadata", "test_npc")
	await _wait_for_completed_results(1)
	_check_equal(service.fetch_count, 1, "completed NPC metadata is served from cache")
	service.queue_free()
	await process_frame


func _check_dialogue_request_coalescing() -> void:
	var service_script := load(DIALOGUE_SERVICE_FIXTURE) as GDScript
	_check_equal(service_script != null, true, "dialogue metadata coalescing fixture loads")
	if service_script == null:
		return
	var service := service_script.new() as Node
	root.add_child(service)
	completed_results.clear()
	_add_request_caller(service, &"get_dialogue", "test_dialogue")
	_add_request_caller(service, &"get_dialogue", "test_dialogue")
	await process_frame
	_check_equal(service.fetch_count, 1, "concurrent dialogue lookups share one request")
	service.release_fetch.emit()
	await _wait_for_completed_results(2)
	_check_equal(completed_results.size(), 2, "both dialogue callers receive a result")
	for result: Dictionary in completed_results:
		_check_equal(
			(result.get("metadata", {}) as Dictionary).get("lines", []),
			["Hello."],
			"coalesced dialogue metadata is normalized for every caller"
		)
	completed_results.clear()
	_add_request_caller(service, &"get_dialogue", "test_dialogue")
	await _wait_for_completed_results(1)
	_check_equal(service.fetch_count, 1, "completed dialogue metadata is served from cache")
	service.queue_free()
	await process_frame


func _check_proximity_prefetch_contract() -> void:
	var base_npc_text := FileAccess.get_file_as_string(BASE_NPC_SCRIPT)
	var dialogue_npc_text := FileAccess.get_file_as_string(DIALOGUE_NPC_SCRIPT)
	_check_equal(
		base_npc_text.contains("_prefetch_nearby_npc_content.call_deferred()"),
		true,
		"entering an NPC interaction area starts targeted nearby-content prefetch"
	)
	_check_equal(
		dialogue_npc_text.contains("func _prefetch_nearby_dialogue_metadata() -> void:")
		and dialogue_npc_text.contains("await DialogueMetadataService.get_dialogue(selected_dialogue_id)"),
		true,
		"DialogueNPC prefetches only its selected dialogue"
	)


func _check_manual_interaction_frame_barrier() -> void:
	var base_npc_text := FileAccess.get_file_as_string(BASE_NPC_SCRIPT)
	_check_equal(
		base_npc_text.contains("await get_tree().process_frame")
		and not base_npc_text.contains("MANUAL_INTERACTION_DELAY_SECONDS"),
		true,
		"manual interaction keeps one facing frame without a fixed timer"
	)


func _add_request_caller(service: Node, method: StringName, request_id: String) -> void:
	var caller := MetadataRequestCaller.new()
	caller.service = service
	caller.request_method = method
	caller.request_id = request_id
	caller.finished.connect(_on_request_finished.bind(caller))
	root.add_child(caller)


func _on_request_finished(result: Dictionary, caller: Node) -> void:
	completed_results.append(result)
	caller.queue_free()


func _wait_for_completed_results(expected_count: int) -> void:
	for _frame: int in range(30):
		if completed_results.size() >= expected_count:
			return
		await process_frame
	_check_equal(completed_results.size(), expected_count, "metadata requests complete within the test budget")


func _check_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual == expected:
		print("PASS %s" % message)
		return
	failed = true
	push_error("FAIL %s expected=%s actual=%s" % [message, str(expected), str(actual)])
