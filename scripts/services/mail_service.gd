extends Node

class_name MailServiceNode

const MAIL_ENDPOINT := "/game/mail"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_mail(box: String = "inbox") -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var normalized_box: String = _normalize_mail_box(box)
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAIL_ENDPOINT + "?box=%s" % normalized_box.uri_encode(),
		HTTPClient.METHOD_GET,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"mail": _array_from_value(body.get("mail", [])),
	}


func send_mail(
	recipient_username: String,
	subject: String,
	body: String,
	item_attachments: Array = [],
	pokemon_attachment_ids: Array = []
) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}

	var recipient := recipient_username.strip_edges().to_lower()
	var mail_subject := subject.strip_edges()
	if recipient == "":
		return {
			"success": false,
			"error": "Recipient username is required.",
		}
	if mail_subject == "":
		return {
			"success": false,
			"error": "Subject is required.",
		}

	var payload := {
		"recipientUsername": recipient,
		"subject": mail_subject,
		"body": body.strip_edges(),
		"itemAttachments": _normalize_item_attachments(item_attachments),
		"pokemonAttachmentIds": _normalize_pokemon_attachment_ids(pokemon_attachment_ids),
	}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAIL_ENDPOINT,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		JSON.stringify(payload)
	)
	if not bool(response.get("success", false)):
		return response

	var response_body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"sent": _dictionary_from_value(response_body.get("sent", {})),
		"mail": _array_from_value(response_body.get("mail", [])),
		"inventory": _array_from_value(_dictionary_from_value(response_body.get("inventory", {})).get("items", [])),
		"party": _array_from_value(_dictionary_from_value(response_body.get("party", {})).get("party", [])),
		"wallet": _dictionary_from_value(_dictionary_from_value(response_body.get("wallet", {})).get("wallet", {})),
	}


func claim_mail(mail_id: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if mail_id <= 0:
		return {
			"success": false,
			"error": "Missing mail id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAIL_ENDPOINT + "/%s/claim" % mail_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		"{}"
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"mail": _dictionary_from_value(body.get("mail", {})),
		"inventory": _array_from_value(_dictionary_from_value(body.get("inventory", {})).get("items", [])),
		"party": _array_from_value(_dictionary_from_value(body.get("party", {})).get("party", [])),
		"wallet": _dictionary_from_value(_dictionary_from_value(body.get("wallet", {})).get("wallet", {})),
		"storageLocations": _normalize_storage_locations(body.get("storageLocations", [])),
	}


func mark_mail_read(mail_id: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if mail_id <= 0:
		return {
			"success": false,
			"error": "Missing mail id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAIL_ENDPOINT + "/%s/read" % mail_id,
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		"{}"
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"mail": _dictionary_from_value(body.get("mail", {})),
	}


func claim_mail_attachment(mail_id: int, attachment_id: int) -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if mail_id <= 0:
		return {
			"success": false,
			"error": "Missing mail id.",
		}
	if attachment_id <= 0:
		return {
			"success": false,
			"error": "Missing attachment id.",
		}

	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAIL_ENDPOINT + "/%s/attachments/%s/claim" % [mail_id, attachment_id],
		HTTPClient.METHOD_POST,
		GatewayApiConfig.get_json_headers(),
		"{}"
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"mail": _dictionary_from_value(body.get("mail", {})),
		"inventory": _array_from_value(_dictionary_from_value(body.get("inventory", {})).get("items", [])),
		"party": _array_from_value(_dictionary_from_value(body.get("party", {})).get("party", [])),
		"wallet": _dictionary_from_value(_dictionary_from_value(body.get("wallet", {})).get("wallet", {})),
		"storageLocations": _normalize_storage_locations(body.get("storageLocations", [])),
	}


func delete_mail(mail_id: int, box: String = "inbox") -> Dictionary:
	if not AuthService.is_authenticated():
		return {
			"success": false,
			"error": "Not authenticated.",
		}
	if mail_id <= 0:
		return {
			"success": false,
			"error": "Missing mail id.",
		}

	var normalized_box: String = _normalize_mail_box(box)
	var base_url: String = await GatewayApiConfig.get_base_url()
	var response: Dictionary = await _request_json(
		base_url + MAIL_ENDPOINT + "/%s?box=%s" % [mail_id, normalized_box.uri_encode()],
		HTTPClient.METHOD_DELETE,
		GatewayApiConfig.get_accept_headers(),
		""
	)
	if not bool(response.get("success", false)):
		return response

	var body: Dictionary = _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"mail": _array_from_value(body.get("mail", [])),
	}


func _normalize_mail_box(box: String) -> String:
	var normalized: String = box.strip_edges().to_lower()
	return "sent" if normalized == "sent" else "inbox"


func _normalize_item_attachments(value: Array) -> Array:
	var normalized: Array = []
	for attachment_value: Variant in value:
		if not (attachment_value is Dictionary):
			continue

		var attachment: Dictionary = attachment_value as Dictionary
		var item_id := str(attachment.get("itemId", attachment.get("id", ""))).strip_edges().to_lower()
		var quantity: int = max(int(attachment.get("quantity", 1)), 1)
		if item_id == "":
			continue

		normalized.append({
			"itemId": item_id,
			"quantity": quantity,
		})

	return normalized


func _normalize_pokemon_attachment_ids(value: Array) -> Array:
	var normalized: Array = []
	for pokemon_id_value: Variant in value:
		var pokemon_id: int = int(pokemon_id_value)
		if pokemon_id <= 0:
			continue
		if normalized.has(pokemon_id):
			continue
		normalized.append(pokemon_id)
		if normalized.size() >= 5:
			break

	return normalized


func _normalize_storage_locations(value: Variant) -> Array:
	var normalized: Array = []
	if typeof(value) != TYPE_ARRAY:
		return normalized
	var locations: Array = value
	for location_value: Variant in locations:
		var location := PokemonStorageService.normalize_storage_location(location_value)
		if not location.is_empty():
			normalized.append(location)
	return normalized


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
		"body": parsed_body,
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
