extends Node

class_name GatewayApiConfigNode

const LOCAL_GATEWAY_URL := "http://localhost:8000"
const PRODUCTION_GATEWAY_URL := "https://api.pokeaether.com"

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
