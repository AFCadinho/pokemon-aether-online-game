extends WorldInteractable

class_name LockedDoorInteractable

@export var area_id := ""
@export var default_locked := true
@export var fallback_locked_dialogue_lines: Array[String] = [
	"This building is not available right now.",
]

var is_unlocked := false
var access_loaded := false
var access_request_in_flight := false
var locked_dialogue_lines: Array[String] = []


func _ready() -> void:
	interactable_kind = "locked_door"
	requires_facing = false
	_ensure_interaction_area()
	locked_dialogue_lines = fallback_locked_dialogue_lines.duplicate()
	_set_access_state(not default_locked)
	call_deferred("_refresh_access")


func _process(_delta: float) -> void:
	if _can_start_manual_interaction():
		await _start_manual_interaction(nearby_player)


func interact_with_player(_player: Node2D) -> void:
	await _refresh_access(true)
	if is_unlocked:
		return
	await show_dialogue(locked_dialogue_lines, display_name)


func _refresh_access(force_refresh := false) -> void:
	if access_request_in_flight or area_id.strip_edges().is_empty():
		return
	access_request_in_flight = true
	var transition_service := get_node_or_null("/root/WorldTransitionService")
	if transition_service == null or not transition_service.has_method("get_area_access"):
		access_request_in_flight = false
		access_loaded = false
		_set_access_state(false)
		return
	var result: Dictionary = await transition_service.call("get_area_access", area_id, force_refresh)
	access_request_in_flight = false
	if not bool(result.get("success", false)):
		access_loaded = false
		_set_access_state(false)
		return

	var access: Dictionary = result.get("access", {})
	access_loaded = true
	_set_access_state(bool(access.get("allowed", false)))
	if not is_unlocked:
		var dialogue_id := str(access.get("dialogueId", "")).strip_edges()
		if not dialogue_id.is_empty():
			var dialogue_service := get_node_or_null("/root/DialogueMetadataService")
			if dialogue_service == null or not dialogue_service.has_method("get_lines"):
				return
			var lines: Array = await dialogue_service.call("get_lines", dialogue_id)
			if not lines.is_empty():
				locked_dialogue_lines = lines


func _set_access_state(allowed: bool) -> void:
	is_unlocked = allowed
	blocks_movement = not allowed
	if interaction_area != null:
		interaction_area.monitoring = not allowed
		interaction_area.monitorable = not allowed
