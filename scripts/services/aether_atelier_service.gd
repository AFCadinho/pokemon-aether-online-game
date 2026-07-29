extends Node

class_name AetherAtelierServiceNode

const CharacterAppearanceService := preload("res://scripts/services/character_appearance_service.gd")
const CATALOG_ENDPOINT := "/game/aether-atelier"
const CREATE_ENDPOINT := "/game/aether-atelier/outfits/%s/create"
const DYE_ENDPOINT := "/game/aether-atelier/chroma/%s/dye"
const DYE_OUTFIT_ENDPOINT := "/game/aether-atelier/chroma-outfit/dye"
const REQUEST_TIMEOUT_SECONDS := 8.0


func load_catalog() -> Dictionary:
	if not _is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if gateway == null:
		return {"success": false, "error": "Gateway API config is unavailable."}
	var base_url: String = await gateway.call("get_base_url")
	var response := await _request_json(
		base_url + CATALOG_ENDPOINT,
		HTTPClient.METHOD_GET,
		gateway.call("get_accept_headers"),
		""
	)
	return parse_catalog_response(response)


func create_bundle(box_item_id: String) -> Dictionary:
	var normalized_box_item_id := box_item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	if normalized_box_item_id == "":
		return {"success": false, "error": "Missing outfit box id."}
	if not _is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if gateway == null:
		return {"success": false, "error": "Gateway API config is unavailable."}
	var base_url: String = await gateway.call("get_base_url")
	var response := await _request_json(
		base_url + CREATE_ENDPOINT % normalized_box_item_id.uri_encode(),
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		""
	)
	return parse_create_response(response)

func dye_chroma_item(item_id: String, color: String) -> Dictionary:
	var normalized_item_id := item_id.strip_edges().to_lower().replace("_", "-").replace(" ", "-")
	var normalized_color := CharacterAppearanceService.normalize_hex_color_code(color)
	if normalized_item_id == "":
		return {"success": false, "error": "Missing Chroma item id."}
	if normalized_color == "":
		return {"success": false, "error": "Enter a valid #RRGGBB colour."}
	if not _is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if gateway == null:
		return {"success": false, "error": "Gateway API config is unavailable."}
	var base_url: String = await gateway.call("get_base_url")
	var response := await _request_json(
		base_url + DYE_ENDPOINT % normalized_item_id.uri_encode(),
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		JSON.stringify({"color": normalized_color})
	)
	return parse_dye_response(response)


func dye_chroma_outfit(changes: Array[Dictionary]) -> Dictionary:
	if changes.is_empty():
		return {"success": false, "error": "Choose at least one new colour."}
	if not _is_authenticated():
		return {"success": false, "error": "Not authenticated."}
	var normalized_changes: Array[Dictionary] = []
	for change: Dictionary in changes:
		var item_id := str(change.get("itemId", "")).strip_edges()
		var color := CharacterAppearanceService.normalize_hex_color_code(
			str(change.get("color", ""))
		)
		if item_id == "" or color == "":
			return {"success": false, "error": "Invalid Chroma outfit change."}
		normalized_changes.append({"itemId": item_id, "color": color})
	var gateway := get_node_or_null("/root/GatewayApiConfig")
	if gateway == null:
		return {"success": false, "error": "Gateway API config is unavailable."}
	var base_url: String = await gateway.call("get_base_url")
	var response := await _request_json(
		base_url + DYE_OUTFIT_ENDPOINT,
		HTTPClient.METHOD_POST,
		gateway.call("get_json_headers"),
		JSON.stringify({"changes": normalized_changes})
	)
	return parse_dye_outfit_response(response)


func parse_catalog_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	return {
		"success": true,
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"outfits": normalize_outfits(body.get("outfits", [])),
		"chromaItems": normalize_chroma_items(body.get("chromaItems", [])),
	}


func parse_create_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var inventory := _dictionary_from_value(body.get("inventory", {}))
	return {
		"success": true,
		"createdBoxItemId": str(body.get("createdBoxItemId", "")),
		"fee": maxi(int(body.get("fee", 0)), 0),
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"inventory": _array_from_value(inventory.get("items", [])),
		"outfits": normalize_outfits(body.get("outfits", [])),
		"chromaItems": normalize_chroma_items(body.get("chromaItems", [])),
	}

func parse_dye_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var appearance_inventory := _dictionary_from_value(body.get("appearanceInventory", {}))
	var normalized_items := normalize_chroma_items([body.get("item", {})])
	return {
		"success": true,
		"item": normalized_items[0] if not normalized_items.is_empty() else {},
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"appearanceUnlocks": _array_from_value(appearance_inventory.get("unlocks", [])),
		"appearanceSlotLimit": int(appearance_inventory.get("slotLimit", 8)),
		"appearanceSlotCounts": _dictionary_from_value(
			appearance_inventory.get("slotCounts", {})
		),
	}


func parse_dye_outfit_response(response: Dictionary) -> Dictionary:
	if not bool(response.get("success", false)):
		return response
	var body := _dictionary_from_value(response.get("body", {}))
	var appearance_inventory := _dictionary_from_value(body.get("appearanceInventory", {}))
	return {
		"success": true,
		"items": normalize_chroma_items(body.get("items", [])),
		"fee": maxi(int(body.get("fee", 0)), 0),
		"wallet": _dictionary_from_value(body.get("wallet", {})),
		"appearanceUnlocks": _array_from_value(appearance_inventory.get("unlocks", [])),
		"appearanceSlotLimit": int(appearance_inventory.get("slotLimit", 8)),
		"appearanceSlotCounts": _dictionary_from_value(appearance_inventory.get("slotCounts", {})),
	}


func normalize_outfits(value: Variant) -> Array[Dictionary]:
	var outfits: Array[Dictionary] = []
	for outfit_value: Variant in _array_from_value(value):
		var outfit := _dictionary_from_value(outfit_value)
		var components: Array[Dictionary] = []
		for component_value: Variant in _array_from_value(outfit.get("components", [])):
			var component := _dictionary_from_value(component_value)
			components.append({
				"itemId": str(component.get("itemId", "")),
				"name": str(component.get("name", "")),
				"requiredQuantity": maxi(int(component.get("requiredQuantity", 1)), 1),
				"ownedQuantity": maxi(int(component.get("ownedQuantity", 0)), 0),
				"hasEnough": bool(component.get("hasEnough", false)),
			})
		var genders: Array[String] = []
		for gender_value: Variant in _array_from_value(outfit.get("genders", [])):
			var gender := str(gender_value).strip_edges().to_lower()
			if gender in ["male", "female"] and not genders.has(gender):
				genders.append(gender)
		outfits.append({
			"boxItemId": str(outfit.get("boxItemId", "")),
			"name": str(outfit.get("name", "")),
			"shortDesc": str(outfit.get("shortDesc", "")),
			"genders": genders,
			"fee": maxi(int(outfit.get("fee", 0)), 0),
			"components": components,
			"ownedComponentCount": maxi(int(outfit.get("ownedComponentCount", 0)), 0),
			"totalComponentCount": maxi(int(outfit.get("totalComponentCount", components.size())), 1),
			"missingItemIds": _array_from_value(outfit.get("missingItemIds", [])),
			"canCreate": bool(outfit.get("canCreate", false)),
		})
	return outfits


func normalize_chroma_items(value: Variant) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	for item_value: Variant in _array_from_value(value):
		var item := _dictionary_from_value(item_value)
		var item_id := str(item.get("itemId", "")).strip_edges()
		var appearance_id := str(item.get("appearanceId", "")).strip_edges()
		var slot := CharacterAppearanceService.normalize_part_category(
			str(item.get("slot", ""))
		)
		if item_id == "" or appearance_id == "" or slot == "":
			continue
		var genders: Array[String] = []
		for gender_value: Variant in _array_from_value(item.get("genders", [])):
			var gender := str(gender_value).strip_edges().to_lower()
			if gender in ["male", "female"] and not genders.has(gender):
				genders.append(gender)
		var color := CharacterAppearanceService.normalize_hex_color_code(
			str(item.get("color", "#ffffff"))
		)
		items.append({
			"itemId": item_id,
			"name": str(item.get("name", item_id)),
			"slot": slot,
			"appearanceId": appearance_id,
			"genders": genders,
			"color": color if color != "" else "#ffffff",
			"fee": maxi(int(item.get("fee", 0)), 0),
			"equipped": bool(item.get("equipped", false)),
			"tintable": bool(item.get("tintable", false)),
		})
	return items


func _request_json(
	url: String,
	method: HTTPClient.Method,
	headers: PackedStringArray,
	body: String
) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)
	var error: Error = request.request(url, headers, method, body)
	if error != OK:
		request.queue_free()
		return {"success": false, "error": "Could not start request: %s" % error_string(error)}
	var result: Array = await request.request_completed
	request.queue_free()
	var request_result := int(result[0])
	var response_code := int(result[1])
	var response_text := (result[3] as PackedByteArray).get_string_from_utf8()
	if request_result != HTTPRequest.RESULT_SUCCESS:
		return {
			"success": false,
			"status": response_code,
			"error": "The Atelier service could not be reached.",
		}
	var parsed_body: Variant = JSON.parse_string(response_text)
	var body_dictionary := _dictionary_from_value(parsed_body)
	if response_code < 200 or response_code >= 300:
		return {
			"success": false,
			"status": response_code,
			"error": _extract_error(body_dictionary, response_code),
			"body": body_dictionary,
		}
	return {"success": true, "status": response_code, "body": body_dictionary}


func _extract_error(body: Dictionary, response_code: int) -> String:
	return BackendErrorLocalizationService.message({"body": body, "status": response_code})


func _is_authenticated() -> bool:
	var auth_service := get_node_or_null("/root/AuthService")
	return (
		auth_service != null
		and auth_service.has_method("is_authenticated")
		and bool(auth_service.call("is_authenticated"))
	)


func _dictionary_from_value(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}


func _array_from_value(value: Variant) -> Array:
	return value as Array if value is Array else []
