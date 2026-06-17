extends Node

class_name EncounterMetadataServiceNode

const ENCOUNTER_AREA_ENDPOINT := "/encounters/areas/%s"

var encounter_area_cache: Dictionary = {}

func get_encounter_area_metadata(area_id: String) -> Dictionary:
	if encounter_area_cache.has(area_id):
		return encounter_area_cache[area_id]

	var response := await _fetch_encounter_area_metadata(area_id)
	if response.get("success", false):
		encounter_area_cache[area_id] = response

	return response

func clear_cache() -> void:
	encounter_area_cache.clear()

func _fetch_encounter_area_metadata(area_id: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0

	var url := "%s/encounters/areas/%s" % [base_url, area_id.uri_encode()]
	var error := request.request(url, GatewayApiConfig.get_accept_headers())
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Encounter metadata request failed to start",
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
			"error": "Encounter metadata request failed with status %s" % response_code,
			"raw": response_text,
		}

	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {
			"success": false,
			"status": response_code,
			"error": "Encounter metadata response was not valid JSON",
			"raw": response_text,
		}

	var parsed_dictionary := parsed as Dictionary
	if parsed_dictionary.has("area") and parsed_dictionary["area"] is Dictionary:
		return {
			"success": true,
			"metadata": parsed_dictionary["area"],
		}

	return {
		"success": false,
		"status": response_code,
		"error": "Encounter metadata response did not include area metadata",
		"raw": response_text,
	}
