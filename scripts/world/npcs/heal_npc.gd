extends DialogueNPC

class_name HealNPC

@export var success_dialogue_lines: Array[String] = [
	"Your party is fully healed.",
]
@export var already_healed_dialogue_lines: Array[String] = [
	"Your party is already fully healed.",
]
@export var no_party_dialogue_lines: Array[String] = [
	"You do not have any Pokemon with you.",
]
@export var failure_dialogue_lines: Array[String] = [
	"I could not heal your party right now.",
	"Please try again in a moment.",
]
@export var healed_system_message := "Your party was healed."


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata_if_needed()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return

	if not dialogue_lines.is_empty():
		await show_dialogue(dialogue_lines)

	if _get_player_party().is_empty():
		await show_dialogue(no_party_dialogue_lines)
		return

	var party_heal_service := get_node_or_null("/root/PartyHealService")
	if party_heal_service == null or not party_heal_service.has_method("heal_current_party_and_save"):
		await show_dialogue(failure_dialogue_lines)
		return

	var result: Dictionary = await party_heal_service.call("heal_current_party_and_save")
	if not bool(result.get("success", false)):
		push_warning("HealNPC: party heal failed: %s" % str(result.get("error", "Unknown error")))
		await show_dialogue(failure_dialogue_lines)
		return

	if bool(result.get("changed", false)):
		_add_system_message(healed_system_message)
		await show_dialogue(success_dialogue_lines)
	else:
		await show_dialogue(already_healed_dialogue_lines)


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	var metadata_success_dialogue := _get_string_array(metadata.get("successDialogue", []))
	if not metadata_success_dialogue.is_empty():
		success_dialogue_lines = metadata_success_dialogue

	var metadata_already_healed_dialogue := _get_string_array(metadata.get("alreadyHealedDialogue", []))
	if not metadata_already_healed_dialogue.is_empty():
		already_healed_dialogue_lines = metadata_already_healed_dialogue

	var metadata_no_party_dialogue := _get_string_array(metadata.get("noPartyDialogue", []))
	if not metadata_no_party_dialogue.is_empty():
		no_party_dialogue_lines = metadata_no_party_dialogue

	var metadata_failure_dialogue := _get_string_array(metadata.get("failureDialogue", []))
	if not metadata_failure_dialogue.is_empty():
		failure_dialogue_lines = metadata_failure_dialogue

	var metadata_healed_system_message := str(metadata.get("healedSystemMessage", "")).strip_edges()
	if not metadata_healed_system_message.is_empty():
		healed_system_message = metadata_healed_system_message


func _load_npc_metadata_if_needed() -> Dictionary:
	if npc_id.is_empty():
		return {
			"success": true,
			"metadata": {},
		}

	return await _load_npc_metadata()


func _show_report_to_staff_message() -> void:
	var error_dialog_service := get_node_or_null("/root/GameErrorDialogService")
	if error_dialog_service != null and error_dialog_service.has_method("show_report_to_staff_message"):
		await error_dialog_service.call("show_report_to_staff_message")
		return

	await show_dialogue(failure_dialogue_lines)


func _get_player_party() -> Array:
	var player_save := get_node_or_null("/root/PlayerSave")
	if player_save == null:
		return []

	var party_value: Variant = player_save.get("party")
	if party_value is Array:
		return party_value as Array
	return []


func _add_system_message(text: String) -> void:
	var message := text.strip_edges()
	if message.is_empty():
		return

	var ui_overlay := get_tree().current_scene.get_node_or_null("UIOverlay") if get_tree().current_scene != null else null
	if ui_overlay != null and ui_overlay.has_method("add_system_message"):
		ui_overlay.call("add_system_message", message)
