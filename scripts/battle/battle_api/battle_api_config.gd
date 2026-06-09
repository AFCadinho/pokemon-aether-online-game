extends Node

const LOCAL_API_URL = "http://localhost:8000"
const PRODUCTION_API_URL = "https://api.pokemonaetheronline.com"

var cached_url := ""

func get_base_url() -> String:
	if cached_url != "":
		return cached_url
	
	if not OS.has_feature("editor"):
		cached_url = PRODUCTION_API_URL
		return cached_url
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var error = http_request.request(LOCAL_API_URL + "/health")
	if error == OK:
		var result = await http_request.request_completed
		var response_code = result[1]
		
		if response_code == 200:
			cached_url = LOCAL_API_URL
		else:
			cached_url = PRODUCTION_API_URL
	else:
		cached_url = PRODUCTION_API_URL
		
	http_request.queue_free()
	return cached_url
	
