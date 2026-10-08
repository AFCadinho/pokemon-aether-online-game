extends Node

class_name TrainerMetadataServiceNode

const TRAINER_METADATA_ENDPOINT := "/trainers/%s"
const REQUEST_TIMEOUT_SECONDS := 12.0
const MAX_REQUEST_ATTEMPTS := 2
const RETRY_DELAY_SECONDS := 0.25

var trainer_metadata_cache: Dictionary = {}

func get_trainer_metadata(trainer_id: String) -> Dictionary:
	if trainer_metadata_cache.has(trainer_id):
		return trainer_metadata_cache[trainer_id]
	
	var response := await _fetch_trainer_metadata(trainer_id)
	if not response.get("success", false):
		return response

	var normalized_metadata := _normalize_trainer_metadata(trainer_id, response.get("metadata", {}))
	var result := {
		"success": true,
		"metadata": normalized_metadata,
	}
	trainer_metadata_cache[trainer_id] = result
	return result

func clear_cache() -> void:
	trainer_metadata_cache.clear()

func _fetch_trainer_metadata(trainer_id: String) -> Dictionary:
	for attempt: int in range(MAX_REQUEST_ATTEMPTS):
		var response := await _request_trainer_metadata(trainer_id)
		if (
			bool(response.get("success", false))
			or not bool(response.get("retryable", false))
			or attempt == MAX_REQUEST_ATTEMPTS - 1
		):
			return response
		await get_tree().create_timer(RETRY_DELAY_SECONDS).timeout
	return {"success": false, "error": "Trainer metadata request failed"}


func _request_trainer_metadata(trainer_id: String) -> Dictionary:
	await GatewayApiConfig.wait_for_metadata_request_frame()
	var base_url: String = await GatewayApiConfig.get_base_url()
	var url := base_url + TRAINER_METADATA_ENDPOINT % trainer_id.uri_encode()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = REQUEST_TIMEOUT_SECONDS
	
	var error := request.request(url, GatewayApiConfig.get_accept_headers())
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Trainer metadata request failed to start",
			"code": error,
		}
	
	var result: Array = await request.request_completed
	request.queue_free()
	
	var request_result := int(result[0])
	var response_code := int(result[1])
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"code": request_result,
			"error": BackendErrorLocalizationService.transport_message(request_result),
			"retryable": request_result in [
				HTTPRequest.RESULT_CANT_RESOLVE,
				HTTPRequest.RESULT_CANT_CONNECT,
				HTTPRequest.RESULT_CONNECTION_ERROR,
				HTTPRequest.RESULT_NO_RESPONSE,
				HTTPRequest.RESULT_REQUEST_FAILED,
				HTTPRequest.RESULT_TIMEOUT,
				HTTPRequest.RESULT_CHUNKED_BODY_SIZE_MISMATCH,
			],
		}
	var body: PackedByteArray = result[3]
	var response_text := body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": "Trainer metadata request failed with status %s" % response_code,
			"raw": response_text,
		}
	
	var parser := JSON.new()
	if parser.parse(response_text) != OK or not parser.data is Dictionary:
		return {
			"success": false,
			"status": response_code,
			"error": "Trainer metadata response was not valid JSON",
			"raw": response_text,
		}
	
	var parsed_dictionary := parser.data as Dictionary
	if parsed_dictionary.has("trainer") and parsed_dictionary["trainer"] is Dictionary:
		return {
			"success": true,
			"metadata": parsed_dictionary["trainer"],
		}
	
	return {
		"success": false,
		"status": response_code,
		"error": "Trainer metadata response did not include trainer metadata",
		"raw": response_text,
	}

func _normalize_trainer_metadata(trainer_id: String, metadata: Dictionary) -> Dictionary:
	var trainer_metadata := metadata.duplicate(true)
	trainer_metadata["id"] = str(trainer_metadata.get("id", trainer_id))
	trainer_metadata["name"] = str(trainer_metadata.get("name", ""))
	trainer_metadata["dialogueId"] = str(trainer_metadata.get("dialogueId", trainer_metadata.get("dialogue_id", "")))
	trainer_metadata["introDialogueId"] = str(trainer_metadata.get("introDialogueId", trainer_metadata.get("intro_dialogue_id", "")))
	trainer_metadata["battleIntroDialogueId"] = str(trainer_metadata.get("battleIntroDialogueId", trainer_metadata.get("battle_intro_dialogue_id", "")))
	trainer_metadata["outroDialogueId"] = str(trainer_metadata.get("outroDialogueId", trainer_metadata.get("outro_dialogue_id", "")))
	trainer_metadata["completedDialogueId"] = str(trainer_metadata.get("completedDialogueId", trainer_metadata.get("completed_dialogue_id", "")))
	trainer_metadata["rematchDialogueId"] = str(trainer_metadata.get("rematchDialogueId", trainer_metadata.get("rematch_dialogue_id", "")))
	trainer_metadata["battleTransitionStyle"] = str(
		trainer_metadata.get(
			"battleTransitionStyle",
			trainer_metadata.get("battle_transition_style", "")
		)
	).strip_edges().to_lower()
	trainer_metadata["dialogue_before_battle"] = _get_string_array(
		trainer_metadata.get("dialogue_before_battle", [])
	)
	trainer_metadata["dialogue_after_battle"] = _get_string_array(
		trainer_metadata.get("dialogue_after_battle", [])
	)
	trainer_metadata["dialogue_rematch"] = _get_string_array(
		trainer_metadata.get("dialogue_rematch", [])
	)
	var battle_banter_value: Variant = trainer_metadata.get(
		"battle_banter",
		trainer_metadata.get("battleBanter", {})
	)
	trainer_metadata["battle_banter"] = (
		(battle_banter_value as Dictionary).duplicate(true)
		if battle_banter_value is Dictionary
		else {}
	)
	var battle_voice_value: Variant = trainer_metadata.get(
		"battle_voice",
		trainer_metadata.get("battleVoice", {})
	)
	trainer_metadata["battle_voice"] = (
		(battle_voice_value as Dictionary).duplicate(true)
		if battle_voice_value is Dictionary
		else {}
	)
	return trainer_metadata

func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))
	return strings
