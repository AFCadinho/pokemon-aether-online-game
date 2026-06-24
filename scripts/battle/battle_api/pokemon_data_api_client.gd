extends Node

func parse_pokemon(request_node: HTTPRequest, text: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/pokemon/parse",
		{"text": text}
	)

func parse_team(request_node: HTTPRequest, text: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/team/parse",
		{"text": text}
	)

func create_pokemon_from_text(request_node: HTTPRequest, text: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/pokemon/create-from-text",
		{"text": text}
	)

func create_pokemon(request_node: HTTPRequest, pokemon_data: Dictionary) -> Dictionary:
	return await send_post_request(
		request_node,
		"/pokemon/create",
		{"pokemon": pokemon_data}
	)

func create_team_from_text(request_node: HTTPRequest, text: String) -> Dictionary:
	return await send_post_request(
		request_node,
		"/team/create-from-text",
		{"text": text}
	)

func get_pokemon_stats(request_node: HTTPRequest, species: String, level: int = 100) -> Dictionary:
	var query: String = "?species=%s&level=%s" % [
		species.uri_encode(),
		str(level).uri_encode(),
	]
	return await send_get_request(
		request_node,
		"/pokemon/stats%s" % query
	)

func search_damage_calc_items(request_node: HTTPRequest, q: String, limit: int = 30) -> Dictionary:
	var normalized_limit: int = max(1, min(int(limit), 100))
	var query: String = "?q=%s&limit=%s" % [
		q.uri_encode(),
		str(normalized_limit).uri_encode(),
	]
	return await send_get_request(
		request_node,
		"/damage-calc/catalog/items%s" % query
	)

func search_damage_calc_abilities(request_node: HTTPRequest, q: String, species: String = "", limit: int = 30) -> Dictionary:
	var normalized_limit: int = max(1, min(int(limit), 100))
	var query: String = "?q=%s&species=%s&limit=%s" % [
		q.uri_encode(),
		str(species).uri_encode(),
		str(normalized_limit).uri_encode(),
	]
	return await send_get_request(
		request_node,
		"/damage-calc/catalog/abilities%s" % query
	)

func search_damage_calc_natures(request_node: HTTPRequest, q: String = "", limit: int = 30) -> Dictionary:
	var normalized_limit: int = max(1, min(int(limit), 100))
	var query: String = "?q=%s&limit=%s" % [
		q.uri_encode(),
		str(normalized_limit).uri_encode(),
	]
	return await send_get_request(
		request_node,
		"/damage-calc/catalog/natures%s" % query
	)

func send_get_request(request_node: HTTPRequest, path: String) -> Dictionary:
	var api_base_url: String = await GatewayApiConfig.get_base_url()

	var error: int = request_node.request(
		api_base_url + path,
		GatewayApiConfig.get_accept_headers(),
		HTTPClient.METHOD_GET
	)

	if error != OK:
		return {
			"success": false,
			"error": "Request failed to start",
			"code": error,
		}

	return await _read_json_response(request_node)

func send_post_request(request_node: HTTPRequest, path: String, body: Dictionary) -> Dictionary:
	var api_base_url: String = await GatewayApiConfig.get_base_url()
	
	var error: int = request_node.request(
		api_base_url + path,
		GatewayApiConfig.get_json_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(body)
	)
	
	if error != OK:
		return {
			"success": false,
			"error": "Request failed to start",
			"code": error,
		}

	return await _read_json_response(request_node)

func _read_json_response(request_node: HTTPRequest) -> Dictionary:
	var result: Array = await request_node.request_completed
	var request_result: int = int(result[0])
	var response_code: int = result[1]
	var response_body: PackedByteArray = result[3]
	var response_text: String = response_body.get_string_from_utf8()

	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": _get_request_error_message(request_result),
			"code": request_result,
			"raw": response_text
		}

	var parsed: Variant = JSON.parse_string(response_text)
	
	if typeof(parsed) != TYPE_DICTIONARY:
		return {
			"success": false,
			"status": response_code, 
			"error": _get_invalid_json_error_message(response_code, response_text),
			"raw": response_text
		}
	var response: Dictionary = parsed as Dictionary
	response["status"] = response_code
	if not response.has("error") and response.has("detail"):
		response["error"] = str(response["detail"])
	return response

func _get_invalid_json_error_message(response_code: int, response_text: String) -> String:
	var message := "Invalid JSON response"
	if response_code > 0:
		message += " (status %s)" % response_code

	var response_excerpt := response_text.strip_edges().replace("\n", " ")
	if response_excerpt.length() > 160:
		response_excerpt = response_excerpt.substr(0, 160) + "..."
	if response_excerpt != "":
		message += ": %s" % response_excerpt

	return message

func _get_request_error_message(request_result: int) -> String:
	match request_result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "Cannot connect to API gateway."
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Cannot resolve API gateway."
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "API gateway connection error."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "API gateway TLS error."
		HTTPRequest.RESULT_TIMEOUT:
			return "API gateway request timed out."
		_:
			return "API gateway request failed."
