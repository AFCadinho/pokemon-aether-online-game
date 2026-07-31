extends Area2D

class_name StoryTrigger

@export var story_host_path: NodePath

var _in_flight := false
var _owns_overworld_lock := false


func _ready() -> void:
	var entered := Callable(self, "_on_body_entered")
	if not body_entered.is_connected(entered):
		body_entered.connect(entered)


func _on_body_entered(body: Node2D) -> void:
	if (
		_in_flight
		or GameState.is_overworld_input_locked()
		or GameState.is_ui_input_locked()
		or not _is_player(body)
	):
		return
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
