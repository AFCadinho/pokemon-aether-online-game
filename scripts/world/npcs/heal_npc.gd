@tool
extends DialogueNPC

class_name HealNPC

signal heal_sequence_started(duration_seconds: float, pokemon_count: int)

const DEFAULT_HEAL_ANIMATION_DURATION_SECONDS := 0.8

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
@export var heal_animation_name := &"heal_down"
@export var respawn_point_id := ""
@export var respawn_marker_path: NodePath = ^"RespawnMarker"
@export var respawn_spawn_marker := "HealNPC"
@export_enum("up", "down", "left", "right") var respawn_facing_direction := "down"


func interact_with_player(_player: Node2D) -> void:
	var metadata_response: Dictionary = await _load_npc_metadata_if_needed()
	if not bool(metadata_response.get("success", false)):
		await _show_report_to_staff_message()
		return

	var intro_dialogue_lines := await _get_dialogue_metadata_lines()
	if not intro_dialogue_lines.is_empty():
		await show_dialogue(intro_dialogue_lines)

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
		await _play_heal_animation(_get_player_party().size())
		_add_system_message(healed_system_message)
		await _save_respawn_point()
	else:
		await _save_respawn_point()
		await show_dialogue(await _resolve_dialogue_lines(already_healed_dialogue_id, already_healed_dialogue_lines))


func _play_heal_animation(pokemon_count: int) -> void:
	var duration_seconds := DEFAULT_HEAL_ANIMATION_DURATION_SECONDS
	var has_heal_animation := (
		sprite != null
		and sprite.sprite_frames != null
		and not heal_animation_name.is_empty()
		and sprite.sprite_frames.has_animation(heal_animation_name)
	)
	if has_heal_animation:
		duration_seconds = maxf(
			_get_animation_duration_seconds(heal_animation_name),
			DEFAULT_HEAL_ANIMATION_DURATION_SECONDS
		)

	heal_sequence_started.emit(duration_seconds, clampi(pokemon_count, 0, 6))
	if not has_heal_animation:
		await get_tree().create_timer(duration_seconds).timeout
		return

	var previous_animation := sprite.animation
	var previous_frame := sprite.frame
	var was_playing := sprite.is_playing()

	sprite.play(heal_animation_name)
	if duration_seconds > 0.0:
		await get_tree().create_timer(duration_seconds).timeout

	if sprite.sprite_frames.has_animation(previous_animation):
		sprite.animation = previous_animation
		sprite.frame = clampi(previous_frame, 0, sprite.sprite_frames.get_frame_count(previous_animation) - 1)
		if was_playing:
			sprite.play()
		else:
			sprite.stop()
	else:
		_set_idle_frame(facing_direction)


func _get_animation_duration_seconds(animation_name: StringName) -> float:
	var frames := sprite.sprite_frames
	var frames_per_second := frames.get_animation_speed(animation_name) * absf(sprite.speed_scale)
	if frames_per_second <= 0.0:
		return 0.0

	var total_frame_duration := 0.0
	for frame_index: int in range(frames.get_frame_count(animation_name)):
		total_frame_duration += frames.get_frame_duration(animation_name, frame_index)
	return total_frame_duration / frames_per_second


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
	return await NpcDialogueService.resolve_lines(
		dialogue_reference_id,
		fallback_lines,
		"HealNPC"
	)


func _load_npc_metadata_if_needed() -> Dictionary:
	if _get_npc_metadata_id().is_empty():
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
		"spawnMarker": respawn_spawn_marker.strip_edges(),
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
