@tool
extends DialogueNPC

class_name MoveMentorNPC


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata()
	if not bool(metadata_response.get("success", false)):
		await show_dialogue([
			_text("ui.move_mentor.npc.records_unavailable"),
			_text("npc.error.try_again"),
		])
		return
	await show_dialogue()
	var ui_overlay := (
		get_tree().current_scene.get_node_or_null("UIOverlay")
		if get_tree().current_scene != null
		else null
	)
	if ui_overlay != null and ui_overlay.has_method("open_move_mentor"):
		ui_overlay.call("open_move_mentor")
		return
	await show_dialogue([_text("ui.move_mentor.npc.service_unavailable")])


func _text(key: String) -> String:
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	return str(localization_manager.call("text", key)) if localization_manager != null else key
