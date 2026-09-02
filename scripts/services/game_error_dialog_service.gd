extends Node

class_name GameErrorDialogServiceNode

const DEFAULT_SPEAKER := "System"

func show_report_to_staff_message(dialogue_box: Node = null) -> void:
	await show_message(
		[LocalizationManager.text("backend.error.unexpected_report")],
		DEFAULT_SPEAKER,
		dialogue_box
	)


func show_response(
	response: Dictionary,
	fallback_key: String = "backend.error.generic",
	dialogue_box: Node = null
) -> void:
	await show_message(response_lines(response, fallback_key), DEFAULT_SPEAKER, dialogue_box)


func response_lines(
	response: Dictionary,
	fallback_key: String = "backend.error.generic"
) -> Array[String]:
	var lines: Array[String] = [
		BackendErrorLocalizationService.message(response, fallback_key),
	]
	var reference := BackendErrorLocalizationService.support_id(response)
	if not reference.is_empty():
		lines.append(LocalizationManager.text(
			"backend.error.reference",
			{"reference": reference}
		))
	return lines


func show_message(lines: Array[String], speaker: String = DEFAULT_SPEAKER, dialogue_box: Node = null) -> void:
	var target_dialogue_box := dialogue_box
	if target_dialogue_box == null:
		target_dialogue_box = _get_dialogue_box()

	if target_dialogue_box == null or not target_dialogue_box.has_method("start_dialogue"):
		GameState.unlock_input()
		return

	target_dialogue_box.start_dialogue(lines, speaker)
	await target_dialogue_box.dialogue_finished


func show_single_message_deferred(message: String, speaker: String = DEFAULT_SPEAKER) -> void:
	var lines: Array[String] = [message]
	await show_message(lines, speaker)

func _get_dialogue_box() -> Node:
	if get_tree().current_scene == null:
		return null

	return get_tree().current_scene.get_node_or_null("DialogueBox/Box")
