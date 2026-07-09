extends Node

class_name OverworldPokemonMetadataServiceNode

const OVERWORLD_POKEMON_METADATA_ENDPOINT := "/overworld-pokemon/%s"

var overworld_pokemon_metadata_cache: Dictionary = {}


func get_overworld_pokemon_metadata(overworld_pokemon_id: String) -> Dictionary:
	if overworld_pokemon_metadata_cache.has(overworld_pokemon_id):
		return overworld_pokemon_metadata_cache[overworld_pokemon_id]

	var response := await _fetch_overworld_pokemon_metadata(overworld_pokemon_id)
	if not response.get("success", false):
		return response

	var normalized_metadata := _normalize_overworld_pokemon_metadata(
		overworld_pokemon_id,
		response.get("metadata", {})
	)
	var result := {
		"success": true,
		"metadata": normalized_metadata,
	}
	overworld_pokemon_metadata_cache[overworld_pokemon_id] = result
	return result


func clear_cache() -> void:
	overworld_pokemon_metadata_cache.clear()


func _fetch_overworld_pokemon_metadata(overworld_pokemon_id: String) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var url := base_url + OVERWORLD_POKEMON_METADATA_ENDPOINT % overworld_pokemon_id.uri_encode()
	var request := HTTPRequest.new()
	add_child(request)
	request.timeout = 3.0

	var error := request.request(url, GatewayApiConfig.get_accept_headers())
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Overworld Pokemon metadata request failed to start",
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
			"error": "Overworld Pokemon metadata request failed with status %s" % response_code,
			"raw": response_text,
		}

	var parsed: Variant = JSON.parse_string(response_text)
	if not (parsed is Dictionary):
		return {
			"success": false,
			"status": response_code,
			"error": "Overworld Pokemon metadata response was not valid JSON",
			"raw": response_text,
		}

	var parsed_dictionary := parsed as Dictionary
	if parsed_dictionary.has("pokemon") and parsed_dictionary["pokemon"] is Dictionary:
		return {
			"success": true,
			"metadata": parsed_dictionary["pokemon"],
		}

	return {
		"success": false,
		"status": response_code,
		"error": "Overworld Pokemon metadata response did not include pokemon metadata",
		"raw": response_text,
	}


func _normalize_overworld_pokemon_metadata(overworld_pokemon_id: String, metadata: Dictionary) -> Dictionary:
	var pokemon_metadata := metadata.duplicate(true)
	pokemon_metadata["id"] = str(pokemon_metadata.get("id", overworld_pokemon_id))
	pokemon_metadata["speciesId"] = str(pokemon_metadata.get("speciesId", pokemon_metadata.get("species_id", "")))
	pokemon_metadata["name"] = str(pokemon_metadata.get("name", pokemon_metadata.get("displayName", pokemon_metadata.get("display_name", ""))))
	pokemon_metadata["dialogueId"] = str(pokemon_metadata.get("dialogueId", pokemon_metadata.get("dialogue_id", "")))
	pokemon_metadata["interactionType"] = str(pokemon_metadata.get("interactionType", pokemon_metadata.get("interaction_type", "cry")))
	pokemon_metadata["level"] = int(pokemon_metadata.get("level", 1))
	return pokemon_metadata
