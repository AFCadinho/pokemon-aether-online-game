extends Node

class_name GatewayApiConfigNode

const LOCAL_GATEWAY_URL := "http://localhost:8000"
const PRODUCTION_GATEWAY_URL := "https://api.pokeaether.com"
const ACCEPT_JSON_HEADER := "Accept: application/json"
const CONTENT_TYPE_JSON_HEADER := "Content-Type: application/json"
const GATEWAY_URL_ENV := "POKEAETHER_GATEWAY_URL"

var cached_url := ""

func get_base_url() -> String:
	if cached_url != "":
		return cached_url
	
	var env_url := OS.get_environment(GATEWAY_URL_ENV).strip_edges()
	if env_url != "":
		cached_url = env_url.rstrip("/")
		return cached_url
	
	if OS.has_feature("editor"):
		cached_url = LOCAL_GATEWAY_URL
		return cached_url
	
	cached_url = PRODUCTION_GATEWAY_URL
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
