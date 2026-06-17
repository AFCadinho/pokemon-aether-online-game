extends Node

class_name GatewayApiConfigNode

const LOCAL_GATEWAY_URL := "http://localhost:8000"
const PRODUCTION_GATEWAY_URL := "https://api.pokeaether.com"
const ACCEPT_JSON_HEADER := "Accept: application/json"
const CONTENT_TYPE_JSON_HEADER := "Content-Type: application/json"

var cached_url := ""

func get_base_url() -> String:
	if cached_url != "":
		return cached_url
	
	if not OS.has_feature("editor"):
		cached_url = PRODUCTION_GATEWAY_URL
		return cached_url
	
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 1.0
	
	var error := http_request.request(LOCAL_GATEWAY_URL + "/health")
	if error == OK:
		var result: Array = await http_request.request_completed
		var response_code := int(result[1])
		cached_url = LOCAL_GATEWAY_URL if response_code == 200 else PRODUCTION_GATEWAY_URL
	else:
		cached_url = PRODUCTION_GATEWAY_URL
	
	http_request.queue_free()
	return cached_url


func get_accept_headers() -> PackedStringArray:
	var headers := PackedStringArray([ACCEPT_JSON_HEADER])
	return _append_authorization_header(headers)


func get_json_headers() -> PackedStringArray:
	var headers := PackedStringArray([CONTENT_TYPE_JSON_HEADER, ACCEPT_JSON_HEADER])
	return _append_authorization_header(headers)


func _append_authorization_header(headers: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = headers.duplicate()
	var auth_service: Object = get_node_or_null("/root/AuthService")
	if auth_service == null or not auth_service.has_method("get_authorization_header"):
		return result

	var auth_header := str(auth_service.call("get_authorization_header"))
	if auth_header != "":
		result.append(auth_header)
	return result
