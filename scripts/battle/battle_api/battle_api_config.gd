extends Node

const LOCAL_API_URL = "http://localhost:8000"
const PRODUCTION_API_URL = "https://api.pokeaether.com"
const API_URL_ENV = "POKEAETHER_GATEWAY_URL"

var cached_url := ""

func get_base_url() -> String:
	if cached_url != "":
		return cached_url
	if OS.has_feature("web"):
		cached_url = WebRuntime.api_base_url()
		return cached_url
	
	var env_url := OS.get_environment(API_URL_ENV).strip_edges()
	if env_url != "":
		cached_url = env_url.rstrip("/")
		return cached_url
	
	if OS.has_feature("editor"):
		cached_url = LOCAL_API_URL
		return cached_url
	
	if not OS.has_feature("editor"):
		cached_url = PRODUCTION_API_URL
		return cached_url
	return cached_url
	
