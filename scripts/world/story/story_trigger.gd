extends Area2D

class_name StoryTrigger

@export var story_host_path: NodePath
@export var required_quest_id := ""
@export var required_step_id := ""

var _in_flight := false
var _owns_overworld_lock := false
var _pending_body: Node2D = null


func _ready() -> void:
	var entered := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(entered):
		body_entered.connect(entered)


func _exit_tree() -> void:
	_release_owned_overworld_lock()


func _story_step_is_active() -> bool:
	return required_quest_id.is_empty() or StoryService.is_requirement_met(
		required_quest_id, required_step_id, "active"
	)


func _process(_delta: float) -> void:
	if _pending_body == null:
		return
	if not is_instance_valid(_pending_body) or not overlaps_body(_pending_body):
		_pending_body = null
		return
	if (
		_in_flight
		or not _story_step_is_active()
		or GameState.is_overworld_input_locked()
		or GameState.is_ui_input_locked()
	):
		return

	var body := _pending_body
	_pending_body = null
	_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	if _in_flight or not _is_player(body):
		return
	if not _story_step_is_active() or GameState.is_overworld_input_locked() or GameState.is_ui_input_locked():
		# Map transitions and fossil collection can activate a story while the
		# player is already inside the area. Keep the entry pending until its
		# step and input are ready, without stopping unrelated passers-by.
		_pending_body = body
		return
	_pending_body = null
	var story_hook := _find_story_hook()
	if story_hook == null or not bool(story_hook.call("is_configured")):
		return

	_in_flight = true
	GameState.lock_overworld_input()
	_owns_overworld_lock = true
	while is_instance_valid(body) and body.has_method("is_tile_moving") and bool(body.call("is_tile_moving")):
		await get_tree().process_frame
	if not is_instance_valid(body):
		_release_owned_overworld_lock()
		_in_flight = false
		return

	var story_host := _resolve_story_host()
	if story_host == null:
		await _show_generic_error()
		_release_owned_overworld_lock()
		_in_flight = false
		return
	if story_host.has_method("set_story_player"):
		story_host.call("set_story_player", body)

	var result_value: Variant = await story_hook.call(
		"try_handle_interaction",
		story_host,
		body,
		"area_enter"
	)
	if not (result_value is Dictionary):
		await _show_generic_error()
		_release_owned_overworld_lock()
		_in_flight = false
		return
	var result: Dictionary = result_value as Dictionary
	if result.has("success") and not bool(result.get("success")) and str(result.get("status", "")) != "pending_battle":
		if is_instance_valid(story_host) and story_host.has_method("abort_story_sequence"):
			story_host.call("abort_story_sequence")
	if str(result.get("status", "")) == "pending_battle":
		# World owns the battle lock from here.
		_owns_overworld_lock = false
	else:
		_release_owned_overworld_lock()
	_in_flight = false


func _release_owned_overworld_lock() -> void:
	if not _owns_overworld_lock:
		return
	_owns_overworld_lock = false
	GameState.unlock_overworld_input()


func show_dialogue(lines: Array[String], speaker_name := "") -> bool:
	var dialogue_box := _get_dialogue_box()
	if dialogue_box == null or not dialogue_box.has_method("start_dialogue"):
		push_warning("StoryTrigger: DialogueBox/Box not found.")
		return false
	if lines.is_empty():
		return false
	dialogue_box.call("start_dialogue", lines, speaker_name)
	await dialogue_box.dialogue_finished
	return true


func _resolve_story_host() -> Node:
	if story_host_path.is_empty():
		return self
	return get_node_or_null(story_host_path)


func _find_story_hook() -> Node:
	for child: Node in get_children():
		if child.has_method("try_handle_interaction") and child.has_method("is_configured"):
			return child
	return null


func _is_player(body: Node2D) -> bool:
	return body != null and (body.is_in_group("player") or body.name == "Player")


func _get_dialogue_box() -> Node:
	if get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("DialogueBox/Box")


func _show_generic_error() -> void:
	await GameErrorDialogService.show_report_to_staff_message()
