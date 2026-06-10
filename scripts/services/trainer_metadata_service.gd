extends Node

class_name TrainerMetadataServiceNode

const TRAINER_METADATA_ENDPOINT := "/trainers/%s"

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
	var base_url: String = await GatewayApiConfig.get_base_url()
	var url := base_url + TRAINER_METADATA_ENDPOINT % trainer_id.uri_encode()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0
	
	var error := request.request(url, PackedStringArray(["Accept: application/json"]))
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Trainer metadata request failed to start",
			"code": error,
		}
	
	var result: Array = await request.request_completed
	request.queue_free()
	
	var response_code := int(result[1])
	var body: PackedByteArray = result[3]
	var response_text := body.get_string_from_utf8()
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": "Trainer metadata request failed with status %s" % response_code,
			"raw": response_text,
		}
	
	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {
			"success": false,
			"status": response_code,
			"error": "Trainer metadata response was not valid JSON",
			"raw": response_text,
		}
	
	var parsed_dictionary := parsed as Dictionary
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
	trainer_metadata["dialogue_before_battle"] = _get_string_array(
		trainer_metadata.get("dialogue_before_battle", [])
	)
	return trainer_metadata

func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))
	return strings
