extends Node

class_name GameErrorDialogServiceNode

const REPORT_TO_STAFF_LINES: Array[String] = [
	"Something is wrong.",
	"Please report this to staff.",
]
const DEFAULT_SPEAKER := "System"

func show_report_to_staff_message(dialogue_box: Node = null) -> void:
	var target_dialogue_box := dialogue_box
	if target_dialogue_box == null:
		target_dialogue_box = _get_dialogue_box()

	if target_dialogue_box == null or not target_dialogue_box.has_method("start_dialogue"):
		GameState.input_locked = false
		return

	target_dialogue_box.start_dialogue(REPORT_TO_STAFF_LINES, DEFAULT_SPEAKER)
	await target_dialogue_box.dialogue_finished

func _get_dialogue_box() -> Node:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.get_node_or_null("DialogueBox/Box")
