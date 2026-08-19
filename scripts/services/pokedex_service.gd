extends Node

class_name PokedexServiceNode

const SPECIES_ENDPOINT := "/game/pokedex/species"
const SPECIES_DETAIL_ENDPOINT := "/game/pokedex/species/%s"
const REQUEST_TIMEOUT_SECONDS := 8.0
const DEFAULT_WARMUP_LIMIT := 80
const DEFAULT_WARMUP_DEX_ID := "national"
const DEFAULT_WARMUP_SHINY := false

signal default_catalog_warmup_finished

var _owned_species_cache: Dictionary = {}
var _species_search_cache: Dictionary = {}
var _species_detail_cache: Dictionary = {}
var _default_catalog_warmup_in_progress := false
var _cache_generation := 0


func search_species(
	query: String = "",
	limit: int = 50,
	dex_id: String = "national",
	shiny: bool = false,
	offset: int = 0
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var clamped_limit: int = clampi(limit, 1, 200)
	var normalized_offset := maxi(offset, 0)
	var endpoint := SPECIES_ENDPOINT + "?limit=%s&offset=%s" % [clamped_limit, normalized_offset]
	var normalized_dex_id := dex_id.strip_edges().to_lower()
	if normalized_dex_id != "kanto":
		normalized_dex_id = "national"
	endpoint += "&dex=%s" % normalized_dex_id.uri_encode()
	endpoint += "&shiny=%s" % ("true" if shiny else "false")
	var trimmed_query := query.strip_edges()
	if trimmed_query != "":
		endpoint += "&query=%s" % trimmed_query.uri_encode()
	var cache_key := _species_search_cache_key(
		trimmed_query,
		clamped_limit,
		normalized_dex_id,
		shiny,
		normalized_offset
	)
	if trimmed_query == "" and _species_search_cache.has(cache_key):
		return (_species_search_cache.get(cache_key, {}) as Dictionary).duplicate(true)
	if cache_key == _default_warmup_cache_key() and _default_catalog_warmup_in_progress:
		await default_catalog_warmup_finished
		if _species_search_cache.has(cache_key):
			return (_species_search_cache.get(cache_key, {}) as Dictionary).duplicate(true)

	return await _fetch_species_search(
		endpoint,
		cache_key,
		trimmed_query == "",
		shiny,
		_cache_generation,
		normalized_offset
	)


func _fetch_species_search(
	endpoint: String,
	cache_key: String,
	cache_result: bool,
	shiny: bool,
	cache_generation: int,
	request_offset: int
) -> Dictionary:
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + endpoint,
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response
	if cache_generation != _cache_generation:
		return {
			"success": false,
			"error": "Pokédex request was superseded by an account state change.",
		}

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	var owned_species_ids := _array_from_value(body.get("ownedSpeciesIds", []))
	_owned_species_cache[_owned_cache_key(shiny)] = owned_species_ids.duplicate()
	var result := {
		"success": true,
		"species": _array_from_value(body.get("species", [])),
		"total": int(body.get("total", 0)),
		"offset": int(body.get("offset", request_offset)),
		"hasMore": bool(body.get("hasMore", false)),
		"dexTotal": int(body.get("dexTotal", 0)),
		"ownedTotal": int(body.get("ownedTotal", 0)),
		"ownedSpeciesIds": owned_species_ids,
	}
	if cache_result:
		_species_search_cache[cache_key] = result.duplicate(true)
	return result


func warm_up_default_catalog() -> void:
	if not AuthService.is_authenticated() or _species_search_cache.has(_default_warmup_cache_key()):
		return
	if _default_catalog_warmup_in_progress:
		await default_catalog_warmup_finished
		return

	_default_catalog_warmup_in_progress = true
	var endpoint := (
		SPECIES_ENDPOINT
		+ "?limit=%s&offset=0&dex=%s&shiny=false" % [DEFAULT_WARMUP_LIMIT, DEFAULT_WARMUP_DEX_ID]
	)
	var result := await _fetch_species_search(
		endpoint,
		_default_warmup_cache_key(),
		true,
		DEFAULT_WARMUP_SHINY,
		_cache_generation,
		0
	)
	if bool(result.get("success", false)):
		var species_values := _array_from_value(result.get("species", []))
		if not species_values.is_empty() and species_values[0] is Dictionary:
			var first_species_id := str((species_values[0] as Dictionary).get("id", "")).strip_edges()
			if first_species_id != "":
				await get_species_detail(first_species_id)
	_default_catalog_warmup_in_progress = false
	default_catalog_warmup_finished.emit()

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
	_cache_generation += 1
	_owned_species_cache.clear()
	_species_search_cache.clear()

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
	var cache_key := _normalize_species_key(trimmed_species_id)
	if _species_detail_cache.has(cache_key):
		return (_species_detail_cache.get(cache_key, {}) as Dictionary).duplicate(true)

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + SPECIES_DETAIL_ENDPOINT % trimmed_species_id.uri_encode(),
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var result := {
		"success": true,
		"species": _dictionary_from_value(response.get("body", {})),
	}
	_species_detail_cache[cache_key] = result.duplicate(true)
	return result


func _default_warmup_cache_key() -> String:
	return _species_search_cache_key(
		"",
		DEFAULT_WARMUP_LIMIT,
		DEFAULT_WARMUP_DEX_ID,
		DEFAULT_WARMUP_SHINY,
		0
	)


func _species_search_cache_key(
	query: String,
	limit: int,
	dex_id: String,
	shiny: bool,
	offset: int
) -> String:
	return "%s|%s|%s|%s|%s" % [
		dex_id,
		"shiny" if shiny else "normal",
		limit,
		offset,
		query,
	]


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
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


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
	return BackendErrorLocalizationService.transport_message(result)
