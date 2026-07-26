extends Node

class_name PokedexServiceNode

const SPECIES_ENDPOINT := "/game/pokedex/species"
const SPECIES_DETAIL_ENDPOINT := "/game/pokedex/species/%s"
const REQUEST_TIMEOUT_SECONDS := 8.0

var _owned_species_cache: Dictionary = {}


func search_species(
	query: String = "",
	limit: int = 50,
	dex_id: String = "national",
	shiny: bool = false
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var clamped_limit: int = clampi(limit, 1, 200)
	var endpoint := SPECIES_ENDPOINT + "?limit=%s" % clamped_limit
	var normalized_dex_id := dex_id.strip_edges().to_lower()
	if normalized_dex_id != "kanto":
		normalized_dex_id = "national"
	endpoint += "&dex=%s" % normalized_dex_id.uri_encode()
	endpoint += "&shiny=%s" % ("true" if shiny else "false")
	var trimmed_query := query.strip_edges()
	if trimmed_query != "":
		endpoint += "&query=%s" % trimmed_query.uri_encode()

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var owned_species_ids := _array_from_value(body.get("ownedSpeciesIds", []))
	_owned_species_cache[_owned_cache_key(shiny)] = owned_species_ids.duplicate()
	return {
		"success": true,
		"species": _array_from_value(body.get("species", [])),
		"total": int(body.get("total", 0)),
		"dexTotal": int(body.get("dexTotal", 0)),
		"ownedTotal": int(body.get("ownedTotal", 0)),
		"ownedSpeciesIds": owned_species_ids,
	}

func get_owned_species_ids(shiny: bool = false, force_refresh: bool = false) -> Array:
	var cache_key := _owned_cache_key(shiny)
	if not force_refresh and _owned_species_cache.has(cache_key):
		return (_owned_species_cache.get(cache_key, []) as Array).duplicate()

	var result := await search_species("", 1, "national", shiny)
	if not bool(result.get("success", false)):
		return []
	return _array_from_value(result.get("ownedSpeciesIds", []))

func is_species_owned(species_id: String, shiny: bool = false) -> bool:
	var normalized_species_id := _normalize_species_key(species_id)
	if normalized_species_id == "":
		return false
	for owned_species_value: Variant in _owned_species_cache.get(_owned_cache_key(shiny), []):
		if _normalize_species_key(str(owned_species_value)) == normalized_species_id:
			return true
	return false

func invalidate_owned_species_cache() -> void:
	_owned_species_cache.clear()

func _owned_cache_key(shiny: bool) -> String:
	return "shiny" if shiny else "normal"

func _normalize_species_key(species_id: String) -> String:
	return (
		species_id.strip_edges().to_lower()
		.replace(" ", "")
		.replace("-", "")
		.replace("_", "")
		.replace(".", "")
		.replace("'", "")
	)


func get_species_detail(species_id: String) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var trimmed_species_id := species_id.strip_edges()
	if trimmed_species_id == "":
		return {
			"success": false,
			"error": "Missing species.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + SPECIES_DETAIL_ENDPOINT % trimmed_species_id.uri_encode(),
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	return {
		"success": true,
		"species": _dictionary_from_value(response.get("body", {})),
	}


func _request_json(url: String, method: HTTPClient.Method, headers: PackedStringArray, body: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var error: Error = request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {
			"success": false,
			"error": "Could not start request: %s" % error_string(error),
		}

	var result: Array = await request.request_completed
	request.queue_free()

	var request_result: int = int(result[0])
	var response_code: int = int(result[1])
	var response_body: PackedByteArray = result[3]
	var response_text := response_body.get_string_from_utf8()

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _request_result_message(request_result),
			"raw": response_text,
		}

	var parsed_body: Variant = JSON.parse_string(response_text)
	var body_dictionary: Dictionary = {}
	if typeof(parsed_body) == TYPE_DICTIONARY:
		body_dictionary = parsed_body

	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
			"raw": response_text,
		}

	return {
		"success": true,
		"status": response_code,
		"body": body_dictionary,
	}


func _extract_error(body: Dictionary, response_code: int) -> String:
	if body.has("detail"):
		return str(body.get("detail"))
	if body.has("error"):
		return str(body.get("error"))
	return "Request failed with HTTP %s." % response_code


func _dictionary_from_value(value: Variant) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var dictionary: Dictionary = value
	return dictionary


func _array_from_value(value: Variant) -> Array:
	if typeof(value) != TYPE_ARRAY:
		return []
	var array: Array = value
	return array


func _request_result_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to server."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve server address."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "Connection error."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake failed."
		HTTPRequest.RESULT_TIMEOUT:
			return "Request timed out."
		_:
			return "Request failed."
