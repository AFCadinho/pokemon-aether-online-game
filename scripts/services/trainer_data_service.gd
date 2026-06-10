extends Node

class_name TrainerDataServiceNode

const TRAINER_ENDPOINT := "/battle/npc/trainers/%s"

var trainer_cache: Dictionary = {}

func get_trainer_data(trainer_id: String, fallback_data: Dictionary) -> Dictionary:
	if trainer_cache.has(trainer_id):
		return trainer_cache[trainer_id]
	
	var api_data := await _fetch_trainer_data(trainer_id)
	if not api_data.is_empty():
		var normalized_api_data := _normalize_trainer_data(trainer_id, api_data)
		trainer_cache[trainer_id] = normalized_api_data
		return normalized_api_data
	
	return _normalize_trainer_data(trainer_id, fallback_data)

func clear_cache() -> void:
	trainer_cache.clear()

func _fetch_trainer_data(trainer_id: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var url := base_url + TRAINER_ENDPOINT % trainer_id.uri_encode()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0
	
	var error := request.request(url, PackedStringArray(["Accept: application/json"]))
	if error != OK:
		request.queue_free()
		return {}
	
	var result: Array = await request.request_completed
	request.queue_free()
	
	var response_code := int(result[1])
	if response_code < 200 or response_code >= 300:
		return {}
	
	var body: PackedByteArray = result[3]
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return {}
	
	var parsed_dictionary := parsed as Dictionary
	if parsed_dictionary.has("trainer") and parsed_dictionary["trainer"] is Dictionary:
		return parsed_dictionary["trainer"]
	
	return parsed_dictionary

func _normalize_trainer_data(trainer_id: String, fallback_data: Dictionary) -> Dictionary:
	var trainer_data := fallback_data.duplicate(true)
	trainer_data["id"] = str(trainer_data.get("id", trainer_id))
	trainer_data["name"] = str(trainer_data.get("name", "Trainer"))
	trainer_data["dialogue_before_battle"] = _get_string_array(
		trainer_data.get("dialogue_before_battle", [])
	)
	return trainer_data

func _get_string_array(value: Variant) -> Array[String]:
	var strings: Array[String] = []
	if value is Array:
		for item: Variant in value:
			strings.append(str(item))
	return strings
