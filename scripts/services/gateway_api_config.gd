extends Node

class_name GatewayApiConfigNode

const ClientBuild := preload("res://scripts/services/client_build.gd")
const LOCAL_GATEWAY_URL := "http://localhost:8000"
const PRODUCTION_GATEWAY_URL := "https://api.pokeaether.com"
const ACCEPT_JSON_HEADER := "Accept: application/json"
const CONTENT_TYPE_JSON_HEADER := "Content-Type: application/json"
const GATEWAY_URL_ENV := "POKEAETHER_GATEWAY_URL"

var cached_url := ""

func get_base_url() -> String:
	if cached_url != "":
		return cached_url
	if OS.has_feature("web"):
		cached_url = WebRuntime.api_base_url()
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


func get_accept_headers(locale: String = "") -> PackedStringArray:
	var headers := PackedStringArray([ACCEPT_JSON_HEADER, _get_accept_language_header(locale)])
	return _append_authorization_header(headers)


func get_json_headers(locale: String = "") -> PackedStringArray:
	var headers := PackedStringArray([CONTENT_TYPE_JSON_HEADER, ACCEPT_JSON_HEADER, _get_accept_language_header(locale)])
	return _append_authorization_header(headers)


func _get_accept_language_header(locale: String = "") -> String:
	var http_locale := "en"
	var localization_manager := get_node_or_null("/root/LocalizationManager")
	if localization_manager != null and localization_manager.has_method("get_http_locale"):
		http_locale = str(localization_manager.call("get_http_locale", locale))
	return "Accept-Language: %s" % http_locale


func _append_authorization_header(headers: PackedStringArray) -> PackedStringArray:
	var result: PackedStringArray = ClientBuild.append_http_header(headers)
	var auth_service: Object = get_node_or_null("/root/AuthService")
	if auth_service == null or not auth_service.has_method("get_authorization_header"):
		return result

	var auth_header := str(auth_service.call("get_authorization_header"))
	if auth_header != "":
		result.append(auth_header)
	return result
