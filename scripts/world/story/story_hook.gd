extends Node

class_name StoryHook

const ALLOWED_TRIGGERS: Array[String] = ["interact", "area_enter"]
const COMPLETE_ATTEMPTS := 2
const PLAYER_ACTIONABLE_SEQUENCE_ERROR_CODES: Array[String] = [
	"pokemon_level_cap_party_ineligible",
]

@export var interaction_id := ""
@export var entity_id := ""
@export var enabled := true

var _in_flight := false


func is_configured() -> bool:
	return enabled and interaction_id.strip_edges() != ""


func try_handle_interaction(host: Node, player: Node2D, trigger: String) -> Dictionary:
	if not is_configured():
		return {"success": true, "handled": false, "attempted": false}
	if _in_flight:
		return {"success": false, "handled": true, "status": "busy"}

	var normalized_trigger := trigger.strip_edges()
	var map_id := _current_map_id()
	var resolved_entity_id := _resolve_entity_id(host)
	if normalized_trigger not in ALLOWED_TRIGGERS or map_id == "" or resolved_entity_id == "":
		await _show_generic_error()
		return {
			"success": false,
			"handled": true,
			"status": "invalid_story_hook_context",
		}

	_in_flight = true
	var resolve_result: Dictionary = await PlayerGameStateService.resolve_story_interaction(
		interaction_id,
		map_id,
		resolved_entity_id,
		normalized_trigger
	)
	if not bool(resolve_result.get("success", false)):
		await _show_generic_error()
		return _finish({
			"success": false,
			"handled": true,
			"status": "resolve_failed",
		})

	var resolved_interaction_id := str(resolve_result.get("interactionId", "")).strip_edges()
	if resolved_interaction_id != interaction_id.strip_edges():
		await _show_generic_error()
		return _finish({
			"success": false,
			"handled": true,
			"status": "interaction_identity_mismatch",
		})

	if not bool(resolve_result.get("handled", false)):
		return _finish({
			"success": true,
			"handled": false,
			"attempted": true,
		})

	var sequence_result: Dictionary = await StorySequenceRunner.run_sequence(
		resolve_result.get("actions", []),
		host,
		player
	)
	if str(sequence_result.get("status", "")) == "pending_battle":
		return _finish({
			"success": false,
			"handled": true,
			"status": "pending_battle",
			"battleId": str(sequence_result.get("battleId", "")),
		})
	if not bool(sequence_result.get("success", false)):
		await _show_sequence_error(sequence_result)
		return _finish({
			"success": false,
			"handled": true,
			"status": "sequence_failed",
		})

	if not bool(resolve_result.get("completionRequired", false)):
		return _finish({"success": true, "handled": true, "status": "completed"})

	var request_id := _new_request_id()
	if request_id == "":
		await _show_generic_error()
		return _finish({
			"success": false,
			"handled": true,
			"status": "request_id_unavailable",
		})

	var completion_result: Dictionary = {}
	for attempt: int in range(COMPLETE_ATTEMPTS):
		completion_result = await PlayerGameStateService.complete_story_interaction(
			resolved_interaction_id,
			request_id,
			int(resolve_result.get("revision", 0)),
			map_id,
			resolved_entity_id,
			normalized_trigger
		)
		if bool(completion_result.get("success", false)):
			break
		if not _is_retryable_completion_failure(completion_result) or attempt == COMPLETE_ATTEMPTS - 1:
			break

	if not bool(completion_result.get("success", false)):
		await _show_generic_error()
		return _finish({
			"success": false,
			"handled": true,
			"status": "completion_failed",
			"requestId": request_id,
		})

	# Idempotent retries intentionally replay their original server snapshot. If
	# another trusted event has already advanced the local projection, keep that
	# newer state while still treating this completion receipt as successful.
	StoryService.apply_story_if_not_stale(completion_result.get("story", {}))
	var effects := completion_result.get("effects", []) as Array
	if not effects.is_empty():
		await InventoryService.load_inventory()
		if InventoryService.notify_story_reward_effects(effects):
			SfxManager.play("item_received")
	return _finish({
		"success": true,
		"handled": true,
		"status": "completed",
		"requestId": request_id,
		"effects": completion_result.get("effects", []),
	})


func _finish(result: Dictionary) -> Dictionary:
	_in_flight = false
	return result


func _resolve_entity_id(host: Node) -> String:
	var configured_entity_id := entity_id.strip_edges()
	if configured_entity_id != "":
		return configured_entity_id
	if host == null:
		return ""
	for property_name: String in ["npc_id", "interactable_id"]:
		if _has_property(host, property_name):
			var value := str(host.get(property_name)).strip_edges()
			if value != "":
				return value
	return ""


func _current_map_id() -> String:
	var current_map: Node = GameState.current_map
	if current_map != null and is_instance_valid(current_map) and current_map.has_method("get_map_id"):
		return str(current_map.call("get_map_id")).strip_edges()
	return ""


func _has_property(target: Object, property_name: String) -> bool:
	for property: Dictionary in target.get_property_list():
		if str(property.get("name", "")) == property_name:
			return true
	return false


func _is_retryable_completion_failure(result: Dictionary) -> bool:
	var status := int(result.get("status", 0))
	return status == 0 or status >= 500


func _new_request_id() -> String:
	for _attempt: int in range(2):
		var bytes := Crypto.new().generate_random_bytes(16)
		if bytes.size() != 16:
			continue
		bytes[6] = (bytes[6] & 0x0f) | 0x40
		bytes[8] = (bytes[8] & 0x3f) | 0x80
		var value := bytes.hex_encode()
		return "%s-%s-%s-%s-%s" % [
			value.substr(0, 8),
			value.substr(8, 4),
			value.substr(12, 4),
			value.substr(16, 4),
			value.substr(20, 12),
		]
	return ""


func _show_generic_error() -> void:
	await GameErrorDialogService.show_report_to_staff_message()


func _show_sequence_error(sequence_result: Dictionary) -> void:
	if _is_player_actionable_sequence_error(sequence_result):
		await GameErrorDialogService.show_response(sequence_result)
		return
	await _show_generic_error()


func _is_player_actionable_sequence_error(sequence_result: Dictionary) -> bool:
	return (
		BackendErrorLocalizationService.error_code(sequence_result)
		in PLAYER_ACTIONABLE_SEQUENCE_ERROR_CODES
	)
