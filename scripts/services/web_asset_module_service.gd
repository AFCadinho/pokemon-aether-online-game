extends Node

## Downloads and mounts optional, immutable map packs before web-only entry.
## Desktop already has these resources in its normal PCK.

const MODULE_NAME := "aether-clash-maps"
const MANIFEST_PATH := "/modules/manifest.json"
const MODULE_SCENE := "res://scenes/overworld/aether_clash/aether_clash_duel.tscn"
const MISTY_MODULE_NAME := "kanto-through-misty-maps"
const MISTY_MODULE_SCENE := "res://scenes/overworld/kanto/routes/kanto_route_3.tscn"
const MISTY_MAP_SCENES := {
	"kanto_route_3": MISTY_MODULE_SCENE,
	"kanto_route_3_pokemon_center": "res://scenes/overworld/kanto/routes/route_3_pokemon_center.tscn",
	"kanto_mt_moon_1f": "res://scenes/overworld/kanto/caves/mt_moon/1f.tscn",
	"kanto_mt_moon_b1f": "res://scenes/overworld/kanto/caves/mt_moon/b1f.tscn",
	"kanto_mt_moon_b2f": "res://scenes/overworld/kanto/caves/mt_moon/b2f.tscn",
	"kanto_route_4": "res://scenes/overworld/kanto/routes/kanto_route_4.tscn",
	"kanto_cerulean_city": "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn",
	"kanto_cerulean_city_pokemon_center": "res://scenes/overworld/kanto/towns/cerulean_city/pokemon_center.tscn",
	"kanto_cerulean_city_house_1": "res://scenes/overworld/kanto/towns/cerulean_city/house1.tscn",
	"kanto_cerulean_city_house_2": "res://scenes/overworld/kanto/towns/cerulean_city/house2.tscn",
	"kanto_cerulean_city_house_3": "res://scenes/overworld/kanto/towns/cerulean_city/house3.tscn",
	"kanto_cerulean_city_bike_store": "res://scenes/overworld/kanto/towns/cerulean_city/bike_store.tscn",
	"kanto_cerulean_city_gym": "res://scenes/overworld/kanto/towns/cerulean_city/cerulean_gym.tscn",
	"kanto_route_24": "res://scenes/overworld/kanto/routes/kanto_route_24.tscn",
	"kanto_route_25": "res://scenes/overworld/kanto/routes/route25/kanto_route_25.tscn",
	"kanto_route_25_bills_house": "res://scenes/overworld/kanto/routes/route25/bills_house.tscn",
}
const REQUEST_TIMEOUT_SECONDS := 60.0

var _loaded_modules: Dictionary = {}
var _loading_modules: Dictionary = {}
var _module_results: Dictionary = {}


static func module_for_scene(scene_path: String) -> String:
	if scene_path in [MODULE_SCENE, "res://scenes/overworld/aether_clash/waiting_area.tscn", "res://scenes/overworld/aether_clash/aether_clash_battle_royale.tscn"]:
		return MODULE_NAME
	if scene_path in MISTY_MAP_SCENES.values():
		return MISTY_MODULE_NAME
	return ""


func ensure_scene_available(scene_path: String) -> Dictionary:
	if not _is_browser() or _scene_exists(scene_path):
		return {"success": true, "alreadyAvailable": true}
	var module := module_for_scene(scene_path)
	if module.is_empty():
		return _failure("This map is unavailable in the browser.")
	var result := await _ensure_module(module, scene_path)
	return result


func ensure_aether_clash_maps() -> Dictionary:
	return await _ensure_module(MODULE_NAME, MODULE_SCENE)


func _ensure_module(module_name: String, scene_path: String) -> Dictionary:
	if not _is_browser():
		return {"success": true, "alreadyAvailable": true}
	if _loaded_modules.has(module_name) and _scene_exists(scene_path):
		return {"success": true, "alreadyAvailable": true}
	while _loading_modules.has(module_name):
		await get_tree().process_frame
		if not _loading_modules.has(module_name):
			if bool((_module_results.get(module_name, {}) as Dictionary).get("success", false)) and not _scene_exists(scene_path):
				return _failure("The downloaded module is missing the requested map.")
			return (_module_results.get(module_name, {}) as Dictionary).duplicate(true)
	_loading_modules[module_name] = true
	var result := await _download_and_mount(module_name, scene_path)
	_module_results[module_name] = result.duplicate(true)
	_loading_modules.erase(module_name)
	if bool(result.get("success", false)):
		_loaded_modules[module_name] = true
	return result


func _download_and_mount(module_name: String, required_scene: String) -> Dictionary:
	var origin := str(JavaScriptBridge.eval("window.location.origin", true)).strip_edges()
	if origin.is_empty():
		return _failure("Could not resolve the browser asset origin.")
	var manifest_response := await _request_bytes(origin + MANIFEST_PATH)
	if not bool(manifest_response.get("success", false)):
		return manifest_response
	var validated := validate_module_manifest((manifest_response.get("bytes", PackedByteArray()) as PackedByteArray).get_string_from_utf8(), module_name)
	if not bool(validated.get("success", false)):
		return validated
	var module: Dictionary = validated.get("module", {}) as Dictionary
	var file_name := str(module.get("file", "")).strip_edges()
	var expected_hash := str(module.get("sha256", "")).strip_edges().to_lower()
	var version := str(module.get("version", "")).strip_edges()
	if file_name.get_file() != file_name or not file_name.ends_with(".pck") or expected_hash.length() != 64 or version.is_empty():
		return _failure("The map module manifest is incomplete.")
	var module_dir := "user://web_modules"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(module_dir)) != OK:
		return _failure("Could not prepare browser module storage.")
	var pack_path := "%s/%s-%s.pck" % [module_dir, module_name, expected_hash]
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	request.body_size_limit = 32 * 1024 * 1024
	request.download_file = pack_path
	add_child(request)
	var start_error := request.request(origin + "/modules/" + file_name.uri_encode())
	if start_error != OK:
		request.queue_free()
		return _failure("Could not start the map download. Please try again.")
	var completed: Array = await request.request_completed
	request.queue_free()
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS or int(completed[1]) != 200:
		return _failure("Could not download the map module. Please try again.")
	if FileAccess.get_sha256(pack_path) != expected_hash:
		return _failure("The map module failed its integrity check.")
	var file := FileAccess.open(pack_path, FileAccess.READ)
	if file == null:
		return _failure("Could not read the downloaded map module.")
	var pack_size := file.get_length()
	file.close()
	if not ProjectSettings.load_resource_pack(pack_path, false):
		return _failure("Could not mount the map module.")
	if not ResourceLoader.exists(required_scene):
		return _failure("The map module is missing the requested scene.")
	return {"success": true, "bytes": pack_size, "version": version}


func _request_bytes(url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	request.body_size_limit = 1024 * 1024
	add_child(request)
	var start_error := request.request(url, PackedStringArray(["Accept: application/octet-stream"]))
	if start_error != OK:
		request.queue_free()
		return _failure("Could not start the Aether Clash module download.")
	var completed: Array = await request.request_completed
	request.queue_free()
	if int(completed[0]) != HTTPRequest.RESULT_SUCCESS or int(completed[1]) < 200 or int(completed[1]) >= 300:
		return _failure("Could not download the Aether Clash module.")
	return {"success": true, "bytes": completed[3] as PackedByteArray}


func _failure(message: String) -> Dictionary:
	return {"success": false, "error": message}


func _is_browser() -> bool:
	return OS.has_feature("web")


func _scene_exists(scene_path: String) -> bool:
	return ResourceLoader.exists(scene_path)


static func validate_module_manifest(raw: String, module_name: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(raw)
	if not parsed is Dictionary or not parsed.get("modules") is Dictionary:
		return {"success": false, "error": "The map module manifest is invalid."}
	var module: Variant = parsed.modules.get(module_name)
	if not module is Dictionary:
		return {"success": false, "error": "This map module is not available yet."}
	var file_name := str(module.get("file", ""))
	var hash := str(module.get("sha256", "")).to_lower()
	if file_name.get_file() != file_name or not file_name.ends_with(".pck") or hash.length() != 64 or not hash.is_valid_hex_number(false) or str(module.get("version", "")).is_empty():
		return {"success": false, "error": "The map module manifest is incomplete."}
	return {"success": true, "module": module}
