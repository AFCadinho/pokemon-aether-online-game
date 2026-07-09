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
@export var success_dialogue_id := ""
@export var already_healed_dialogue_id := ""
@export var no_party_dialogue_id := ""
@export var failure_dialogue_id := ""
@export var healed_system_message := "Your party was healed."
@export var respawn_point_id := ""
@export var respawn_marker_path: NodePath = ^"RespawnMarker"
@export_enum("up", "down", "left", "right") var respawn_facing_direction := "down"


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata_if_needed()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return

	if not dialogue_lines.is_empty() or not dialogue_id.strip_edges().is_empty():
		await show_dialogue(dialogue_lines)

	if _get_player_party().is_empty():
		await show_dialogue(await _resolve_dialogue_lines(no_party_dialogue_id, no_party_dialogue_lines))
		return

	var party_heal_service := get_node_or_null("/root/PartyHealService")
	if party_heal_service == null or not party_heal_service.has_method("heal_current_party_and_save"):
		await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
		return

	var respawn_point := _build_respawn_point_payload()
	var result: Dictionary = await party_heal_service.call("heal_current_party_and_save", respawn_point)
	if not bool(result.get("success", false)):
		push_warning("HealNPC: party heal failed: %s" % str(result.get("error", "Unknown error")))
		await show_dialogue(await _resolve_dialogue_lines(failure_dialogue_id, failure_dialogue_lines))
		return

	if bool(result.get("changed", false)):
		_add_system_message(healed_system_message)
		await _save_respawn_point()
		await show_dialogue(await _resolve_dialogue_lines(success_dialogue_id, success_dialogue_lines))
	else:
		await _save_respawn_point()
		await show_dialogue(await _resolve_dialogue_lines(already_healed_dialogue_id, already_healed_dialogue_lines))


func _apply_npc_metadata(metadata: Dictionary) -> void:
	super._apply_npc_metadata(metadata)

	var metadata_success_dialogue := _get_string_array(metadata.get("successDialogue", []))
	if not metadata_success_dialogue.is_empty():
		success_dialogue_lines = metadata_success_dialogue
	success_dialogue_id = _get_metadata_dialogue_id(metadata, "successDialogueId", "success_dialogue_id", success_dialogue_id)

	var metadata_already_healed_dialogue := _get_string_array(metadata.get("alreadyHealedDialogue", []))
	if not metadata_already_healed_dialogue.is_empty():
		already_healed_dialogue_lines = metadata_already_healed_dialogue
	already_healed_dialogue_id = _get_metadata_dialogue_id(metadata, "alreadyHealedDialogueId", "already_healed_dialogue_id", already_healed_dialogue_id)

	var metadata_no_party_dialogue := _get_string_array(metadata.get("noPartyDialogue", []))
	if not metadata_no_party_dialogue.is_empty():
		no_party_dialogue_lines = metadata_no_party_dialogue
	no_party_dialogue_id = _get_metadata_dialogue_id(metadata, "noPartyDialogueId", "no_party_dialogue_id", no_party_dialogue_id)

	var metadata_failure_dialogue := _get_string_array(metadata.get("failureDialogue", []))
	if not metadata_failure_dialogue.is_empty():
		failure_dialogue_lines = metadata_failure_dialogue
	failure_dialogue_id = _get_metadata_dialogue_id(metadata, "failureDialogueId", "failure_dialogue_id", failure_dialogue_id)

	var metadata_healed_system_message := str(metadata.get("healedSystemMessage", "")).strip_edges()
	if not metadata_healed_system_message.is_empty():
		healed_system_message = metadata_healed_system_message


func _get_metadata_dialogue_id(metadata: Dictionary, camel_key: String, snake_key: String, current_value: String) -> String:
	var metadata_dialogue_id := str(metadata.get(camel_key, metadata.get(snake_key, ""))).strip_edges()
	if metadata_dialogue_id.is_empty():
		return current_value
	return metadata_dialogue_id


func _resolve_dialogue_lines(dialogue_reference_id: String, fallback_lines: Array[String]) -> Array[String]:
	var resolved_dialogue_id := dialogue_reference_id.strip_edges()
	if resolved_dialogue_id.is_empty():
		return fallback_lines

	var lines: Array[String] = await DialogueMetadataService.get_lines(resolved_dialogue_id)
	if lines.is_empty():
		push_warning("HealNPC: Dialogue metadata was empty for %s; falling back to inline dialogue." % resolved_dialogue_id)
		return fallback_lines

	return lines


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


func _save_respawn_point() -> void:
	var payload := _build_respawn_point_payload()
	if payload.is_empty():
		return

	var player_game_state_service := get_node_or_null("/root/PlayerGameStateService")
	if player_game_state_service == null or not player_game_state_service.has_method("save_respawn_point"):
		return

	var result: Dictionary = await player_game_state_service.call("save_respawn_point", payload)
	if not bool(result.get("success", false)):
		push_warning("HealNPC: respawn point save failed: %s" % str(result.get("error", "Unknown error")))


func _build_respawn_point_payload() -> Dictionary:

	var current_map: Node = GameState.current_map
	if current_map == null:
		return {}

	var marker := get_node_or_null(respawn_marker_path) as Node2D
	if marker == null:
		marker = self

	var map_scene_path := _get_map_scene_path(current_map)
	if map_scene_path.is_empty():
		push_warning("HealNPC: cannot save respawn point without map scene path.")
		return {}

	var marker_id := respawn_point_id.strip_edges()
	if marker_id.is_empty():
		marker_id = npc_id.strip_edges()
	if marker_id.is_empty():
		marker_id = name

	return {
		"mapId": _get_map_id(current_map),
		"mapScenePath": map_scene_path,
		"position": {
			"x": marker.global_position.x,
			"y": marker.global_position.y,
		},
		"facingDirection": respawn_facing_direction,
		"markerId": marker_id,
	}


func _get_map_id(map: Node) -> String:
	if map != null and map.has_method("get_map_id"):
		return str(map.call("get_map_id")).strip_edges()
	if map != null:
		return map.name
	return ""


func _get_map_scene_path(map: Node) -> String:
	if map == null:
		return ""
	var scene_file_path := str(map.scene_file_path).strip_edges()
	if not scene_file_path.is_empty():
		return scene_file_path
	var filename := str(map.get("filename")).strip_edges()
	return filename
