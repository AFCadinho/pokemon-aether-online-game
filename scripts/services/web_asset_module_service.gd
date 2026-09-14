extends Node

## Downloads and mounts optional, immutable map packs before web-only entry.
## Desktop already has these resources in its normal PCK.

const MODULE_NAME := "aether-clash-maps"
const MANIFEST_PATH := "/modules/manifest.json"
const MODULE_SCENE := "res://scenes/overworld/aether_clash/aether_clash_duel.tscn"
const REQUEST_TIMEOUT_SECONDS := 60.0

var _module_loaded := false
var _load_in_flight := false
var _last_result: Dictionary = {}


func ensure_aether_clash_maps() -> Dictionary:
	if not OS.has_feature("web"):
		return {"success": true, "alreadyAvailable": true}
	if _module_loaded and ResourceLoader.exists(MODULE_SCENE):
		return {"success": true, "alreadyAvailable": true}
	while _load_in_flight:
		await get_tree().process_frame
		if not _load_in_flight:
			return _last_result.duplicate(true)
	_load_in_flight = true
	_last_result = await _download_and_mount()
	_load_in_flight = false
	return _last_result.duplicate(true)


func _download_and_mount() -> Dictionary:
	var origin := str(JavaScriptBridge.eval("window.location.origin", true)).strip_edges()
	if origin.is_empty():
		return _failure("Could not resolve the browser asset origin.")
	var manifest_response := await _request_bytes(origin + MANIFEST_PATH)
	if not bool(manifest_response.get("success", false)):
		return manifest_response
	var parsed: Variant = JSON.parse_string((manifest_response.get("bytes", PackedByteArray()) as PackedByteArray).get_string_from_utf8())
	if not parsed is Dictionary:
		return _failure("The web module manifest is invalid.")
	var modules: Dictionary = (parsed as Dictionary).get("modules", {}) as Dictionary
	var module: Dictionary = modules.get(MODULE_NAME, {}) as Dictionary
	var file_name := str(module.get("file", "")).strip_edges()
	var expected_hash := str(module.get("sha256", "")).strip_edges().to_lower()
	var version := str(module.get("version", "")).strip_edges()
	if file_name.get_file() != file_name or not file_name.ends_with(".pck") or expected_hash.length() != 64 or version.is_empty():
		return _failure("The Aether Clash module manifest is incomplete.")
	var pack_response := await _request_bytes(origin + "/modules/" + file_name.uri_encode())
	if not bool(pack_response.get("success", false)):
		return pack_response
	var pack_bytes: PackedByteArray = pack_response.get("bytes", PackedByteArray()) as PackedByteArray
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK or hashing.update(pack_bytes) != OK:
		return _failure("Could not verify the Aether Clash module.")
	if hashing.finish().hex_encode().to_lower() != expected_hash:
		return _failure("The Aether Clash module failed its integrity check.")
	var module_dir := "user://web_modules"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(module_dir)) != OK:
		return _failure("Could not prepare browser module storage.")
	var pack_path := "%s/%s-%s.pck" % [module_dir, MODULE_NAME, version]
	var file := FileAccess.open(pack_path, FileAccess.WRITE)
	if file == null:
		return _failure("Could not save the Aether Clash module.")
	file.store_buffer(pack_bytes)
	file.close()
	if not ProjectSettings.load_resource_pack(pack_path, false):
		return _failure("Could not mount the Aether Clash module.")
	if not ResourceLoader.exists(MODULE_SCENE):
		return _failure("The Aether Clash module is missing its arena scene.")
	_module_loaded = true
	return {"success": true, "bytes": pack_bytes.size(), "version": version}


func _request_bytes(url: String) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
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
