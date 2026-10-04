extends Node
## Downloads only the approved models requested by desktop battles and previews.

const RELEASE = preload("res://data/approved_3d_release_v7.json")
const RELEASE_V8 = preload("res://data/approved_3d_release_v8.json")
const ReviewedModels = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const DesktopAssetStorage = preload("res://scripts/services/desktop_asset_storage.gd")
const BASE_URL := "https://updates.pokeaether.com/"
const ROOT := "user://on-demand-3d-v1"
const MAX_INDEX_BYTES := 1024 * 1024
const MAX_CATALOG_BYTES := 8 * 1024 * 1024
const MAX_ARCHIVE_BYTES := 512 * 1024 * 1024


static func downloaded_bytes() -> int:
	return _directory_bytes(ProjectSettings.globalize_path(ROOT)) + DesktopAssetStorage.legacy_model_bytes()


static func clear_downloaded_models() -> bool:
	return _clear_directory(ProjectSettings.globalize_path(ROOT)) and DesktopAssetStorage.clear_legacy_models()


static func _directory_bytes(path: String) -> int:
	var directory := DirAccess.open(path)
	if directory == null:
		return 0
	var total := 0
	for name in directory.get_files():
		var file := FileAccess.open(path.path_join(name), FileAccess.READ)
		if file != null:
			total += file.get_length()
	for name in directory.get_directories():
		if not directory.is_link(name):
			total += _directory_bytes(path.path_join(name))
	return total


static func _clear_directory(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return true
	for name in directory.get_files():
		if DirAccess.remove_absolute(path.path_join(name)) != OK:
			return false
	for name in directory.get_directories():
		var child := path.path_join(name)
		if not directory.is_link(name) and not _clear_directory(child):
			return false
		if DirAccess.remove_absolute(child) != OK:
			return false
	return true

var active_request: HTTPRequest
var active_label := ""
var active_size := 0
var active_started_ms := 0
var _busy := false
var _battle_waiters := 0
var _prefetch_generation := 0


func can_clear_cache() -> bool:
	return not _busy and _battle_waiters == 0


func clear_cache() -> bool:
	if not can_clear_cache():
		return false
	_prefetch_generation += 1
	var catalog := OS.get_environment("POKEAETHER_MODEL_CATALOG")
	var own_root := ProjectSettings.globalize_path(ROOT).trim_suffix("/") + "/"
	var legacy_root := OS.get_environment("POKEAETHER_LAUNCHER_MODEL_DIR").trim_suffix("/") + "/"
	var cleared := clear_downloaded_models()
	if cleared:
		if catalog.begins_with(own_root) or (legacy_root != "/" and catalog.begins_with(legacy_root)):
			OS.unset_environment("POKEAETHER_MODEL_CATALOG")
		preload("res://scripts/battle/battle_ui/model_resource_cache.gd").clear()
	return cleared


func prefetch_models(identities: Array[String]) -> void:
	if OS.has_feature("web") or OS.has_feature("mobile"):
		return
	_prefetch_generation += 1
	_run_prefetch.call_deferred(identities.duplicate(), _prefetch_generation)


func cancel_prefetch() -> void:
	_prefetch_generation += 1


func _run_prefetch(identities: Array[String], generation: int) -> void:
	for identity in identities:
		if generation != _prefetch_generation or not is_inside_tree():
			return
		if _asset_id(identity).is_empty():
			continue
		while _busy or _battle_waiters > 0:
			await get_tree().process_frame
			if generation != _prefetch_generation or not is_inside_tree():
				return
		_busy = true
		var source: String = get_tree().root.get_node("SettingsManager").get_battle_3d_catalog_path()
		var result := await _ensure_models([identity], source)
		_busy = false
		if str(result.get("error", "")).is_empty() and not str(result.get("path", "")).is_empty():
			OS.set_environment("POKEAETHER_MODEL_CATALOG", str(result.path))


func progress_text() -> String:
	if not is_instance_valid(active_request):
		return active_label
	var received := active_request.get_downloaded_bytes()
	var total := active_size
	if total <= 0:
		return "Downloading %s…" % active_label
	var percent := mini(99, int(100.0 * received / total))
	var elapsed := maxi(1, Time.get_ticks_msec() - active_started_ms)
	var remaining := int((total - received) * elapsed / maxi(1, received) / 1000.0) if received > 0 else -1
	var estimate := " · about %ds left" % remaining if remaining >= 0 else ""
	return "Downloading %s… %d%% (%d / %d MiB)%s" % [active_label, percent,
		int(received / 1048576.0), int(ceil(total / 1048576.0)), estimate]


func ensure_models(identities: Array[String], source_catalog: String) -> Dictionary:
	_battle_waiters += 1
	while _busy:
		await get_tree().process_frame
	_battle_waiters -= 1
	_busy = true
	var result := await _ensure_models(identities, source_catalog)
	_busy = false
	return result


func _ensure_models(identities: Array[String], source_catalog: String) -> Dictionary:
	var existing := _catalog(source_catalog)
	var own := _catalog(ROOT.path_join("runtime-catalog.json"))
	var entries := _merge_entries(existing, own)
	var missing: Array[String] = []
	var requested: Array[String] = []
	for identity in identities:
		var asset_id := _asset_id(identity)
		if asset_id.is_empty():
			continue # This Pokémon has no approved 3D bundle.
		if asset_id not in requested:
			requested.append(asset_id)
	if requested.is_empty():
		return {"error": "", "path": source_catalog if own.is_empty() else _publish_catalog(entries)}
	var index_result := await _approved_index()
	if not str(index_result.get("error", "")).is_empty():
		return index_result
	var index: Dictionary = index_result.index
	for identity in identities:
		var asset_id := _asset_id(identity)
		if asset_id.is_empty():
			continue
		var runtime_identity := ReviewedModels.canonical_identity(identity)
		var asset := _indexed_asset(index, asset_id)
		if asset.is_empty():
			return {"error": "Approved 3D model is missing from the content index."}
		var expected_digest := ""
		for appearance in asset.get("appearances", []):
			if appearance is Dictionary and str(appearance.get("runtime_identity", "")) == runtime_identity:
				expected_digest = str(appearance.get("runtime_sha256", ""))
		if expected_digest.is_empty():
			return {"error": "Approved 3D appearance is missing from the content index."}
		if not _entry_available(entries, runtime_identity, expected_digest) and asset_id not in missing:
			missing.append(asset_id)
	for asset_id in missing:
		var asset: Dictionary = _indexed_asset(index, asset_id)
		if asset.is_empty():
			return {"error": "Approved 3D model is missing from the content index."}
		var installed := await _install_asset(asset)
		if not str(installed.get("error", "")).is_empty():
			return installed
		entries = _merge_entries(entries, installed.entries)
	var path := _publish_catalog(entries)
	return {"error": "Could not publish the 3D model catalog." if path.is_empty() else "", "path": path,
		"catalog_changed": not missing.is_empty()}


func _asset_id(identity: String) -> String:
	var id := asset_id_for_identity(identity)
	var selected_release := _selected_release()
	return id if id in selected_release.requiredAssetIds else ""


func _selected_release() -> Dictionary:
	var launcher_path := OS.get_environment("POKEAETHER_MODEL_INDEX")
	if launcher_path.is_absolute_path():
		var pin: Dictionary = RELEASE_V8.data.index
		if _valid_file(launcher_path, int(pin.size_bytes), str(pin.sha256)):
			return RELEASE_V8.data
	# The development editor has the reviewed v8 index in the project itself.
	# Use it automatically for local editor runs; exported clients keep their
	# launcher-selected release and otherwise use the pinned production release.
	var editor_path := _editor_local_v8_index_path()
	if not editor_path.is_empty():
		var editor_pin: Dictionary = RELEASE_V8.data.index
		if _valid_file(editor_path, int(editor_pin.size_bytes), str(editor_pin.sha256)):
			return RELEASE_V8.data
	return RELEASE.data


static func _editor_local_v8_index_path() -> String:
	if not OS.has_feature("editor"):
		return ""
	return ProjectSettings.globalize_path("res://release/approved_3d_bundles_v8_index.json")


static func asset_id_for_identity(identity: String) -> String:
	var runtime_identity := ReviewedModels.canonical_identity(identity)
	var species := runtime_identity.trim_suffix("@shiny")
	var form := "base"
	for candidate: String in ["mega-x", "mega-y", "mega-z", "mega"]:
		if species.ends_with("-" + candidate):
			form = candidate
			species = species.trim_suffix("-" + candidate)
			break
	return "pokemon_3d:%s:%s" % [species, form]


func _catalog(path: String) -> Array:
	if path.is_empty() or not FileAccess.file_exists(path):
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_CATALOG_BYTES:
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Array else []


func _merge_entries(first: Array, second: Array) -> Array:
	var by_key := {}
	for entry in first + second:
		if entry is Dictionary:
			var key := str(entry.get("species", "")) + ":" + str(entry.get("variant", ""))
			if not key.begins_with(":"):
				by_key[key] = entry
	var keys := by_key.keys()
	keys.sort()
	var result := []
	for key in keys:
		result.append(by_key[key])
	return result


func _entry_available(entries: Array, identity: String, expected_digest: String) -> bool:
	for entry in entries:
		if not entry is Dictionary:
			continue
		var key := str(entry.get("species", "")) + ("@shiny" if entry.get("variant") == "shiny" else "")
		var model_path := str(entry.get("runtime_path", ""))
		var digest := str(entry.get("runtime_sha256", ""))
		if key == identity and digest == expected_digest and not ReviewedModels.resolve(identity, digest).is_empty() and _valid_file(model_path, int(entry.get("bytes", 0)), digest):
			return true
	return false


func _approved_index() -> Dictionary:
	var release := _selected_release()
	var pin: Dictionary = release.index
	var path := ROOT.path_join("index-%s.json" % pin.sha256)
	var launcher_path := OS.get_environment("POKEAETHER_MODEL_INDEX")
	if launcher_path.is_absolute_path() and _valid_file(launcher_path, int(pin.size_bytes), str(pin.sha256)):
		path = launcher_path
	elif release.revision == RELEASE_V8.data.revision:
		var editor_path := _editor_local_v8_index_path()
		if not editor_path.is_empty() and _valid_file(editor_path, int(pin.size_bytes), str(pin.sha256)):
			path = editor_path
	if not _valid_file(path, int(pin.size_bytes), str(pin.sha256)):
		var result := await _fetch(BASE_URL + str(pin.object_key), path, int(pin.size_bytes), str(pin.sha256), MAX_INDEX_BYTES, "3D content index")
		if not result.is_empty():
			return {"error": result}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("assets") is Array or parsed.get("catalog_revision") != release.revision:
		return {"error": "Approved 3D content index is invalid."}
	return {"error": "", "index": parsed}


func _indexed_asset(index: Dictionary, asset_id: String) -> Dictionary:
	for value in index.assets:
		if value is Dictionary and value.get("asset_id") == asset_id:
			return value
	return {}


func _install_asset(asset: Dictionary) -> Dictionary:
	var key := str(asset.get("object_key", ""))
	var sha := str(asset.get("sha256", ""))
	var id := str(asset.get("asset_id", ""))
	var parts := id.split(":")
	var size := int(asset.get("size_bytes", 0))
	if parts.size() != 3 or not key.begins_with("optional-assets/pokemon_3d/%s/%s/" % [parts[1], parts[2]]) or not key.ends_with(".zip") or key.contains("..") or size < 1 or size > MAX_ARCHIVE_BYTES:
		return {"error": "Approved 3D bundle metadata is invalid."}
	var zip_path := ROOT.path_join("downloads").path_join(sha + ".zip")
	if not _valid_file(zip_path, size, sha):
		var error := await _fetch(BASE_URL + key, zip_path, size, sha, MAX_ARCHIVE_BYTES, parts[1])
		if not error.is_empty():
			return {"error": error}
	var installed := _unpack_asset(asset, zip_path)
	if str(installed.get("error", "")).is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
	return installed


func _unpack_asset(asset: Dictionary, zip_path: String) -> Dictionary:
	var sha := str(asset.get("sha256", ""))
	var parts := str(asset.get("asset_id", "")).split(":")
	if parts.size() != 3 or not _valid_file(zip_path, int(asset.get("size_bytes", 0)), sha):
		return {"error": "Approved 3D bundle failed verification."}
	var reader := ZIPReader.new()
	if reader.open(zip_path) != OK:
		return {"error": "Could not open the approved 3D bundle."}
	var paths := reader.get_files()
	if paths.size() != 3 or not paths.has("bundle.json") or not paths.has("models/normal.scn") or not paths.has("models/shiny.scn"):
		reader.close()
		return {"error": "Approved 3D bundle has unexpected files."}
	var result := []
	for appearance in asset.get("appearances", []):
		if not appearance is Dictionary or appearance.get("variant") not in ["normal", "shiny"]:
			reader.close()
			return {"error": "Approved 3D appearance is invalid."}
		var variant := str(appearance.variant)
		if parts[2] not in ["base", "mega", "mega-x", "mega-y", "mega-z"]:
			reader.close()
			return {"error": "Approved 3D form is unsupported."}
		var identity := parts[1] + ("-" + parts[2] if parts[2] != "base" else "") + ("@shiny" if variant == "shiny" else "")
		if appearance.get("runtime_identity") != identity:
			reader.close()
			return {"error": "Approved 3D identity is invalid."}
		var bytes := reader.read_file("models/%s.scn" % variant)
		var digest := str(appearance.get("runtime_sha256", ""))
		if bytes.is_empty() or _sha256(bytes) != digest or ReviewedModels.resolve(identity, digest).is_empty():
			reader.close()
			return {"error": "Approved 3D model failed verification."}
		var model_path := ROOT.path_join("objects").path_join(sha).path_join("%s.scn" % variant)
		if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(model_path.get_base_dir())) != OK:
			reader.close()
			return {"error": "Could not prepare 3D model storage."}
		if not _valid_file(model_path, bytes.size(), digest):
			var file := FileAccess.open(model_path + ".partial", FileAccess.WRITE)
			if file == null:
				reader.close()
				return {"error": "Could not write the 3D model."}
			file.store_buffer(bytes)
			file.close()
			if not _valid_file(model_path + ".partial", bytes.size(), digest) or DirAccess.rename_absolute(ProjectSettings.globalize_path(model_path + ".partial"), ProjectSettings.globalize_path(model_path)) != OK:
				reader.close()
				return {"error": "Could not publish the verified 3D model."}
		result.append({"species": identity.trim_suffix("@shiny"), "variant": variant,
			"runtime_schema": 1, "runtime_path": ProjectSettings.globalize_path(model_path),
			"runtime_sha256": digest, "bytes": bytes.size()})
	reader.close()
	return {"error": "", "entries": result}


func _publish_catalog(entries: Array) -> String:
	var path := ProjectSettings.globalize_path(ROOT.path_join("runtime-catalog.json"))
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return ""
	var temporary := path + ".partial"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return ""
	file.store_string(JSON.stringify(entries, "\t") + "\n")
	file.close()
	return path if DirAccess.rename_absolute(temporary, path) == OK else ""


func _fetch(url: String, path: String, expected: int, digest: String, limit: int, label: String) -> String:
	if expected < 1 or expected > limit or not url.begins_with(BASE_URL):
		return "Invalid approved 3D download."
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return "Could not prepare 3D download storage."
	active_request = HTTPRequest.new()
	active_request.timeout = 180.0
	active_request.body_size_limit = limit
	active_request.download_file = absolute + ".partial"
	add_child(active_request)
	active_label = label
	active_size = expected
	active_started_ms = Time.get_ticks_msec()
	var start := active_request.request(url)
	if start != OK:
		active_request.queue_free()
		active_request = null
		return "Could not start the 3D model download."
	var response: Array = await active_request.request_completed
	active_request.queue_free()
	active_request = null
	active_label = "Verifying %s…" % label
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS or int(response[1]) != 200:
		DirAccess.remove_absolute(absolute + ".partial")
		return "3D model download failed."
	if not _valid_file(absolute + ".partial", expected, digest):
		return "3D model download failed verification."
	if DirAccess.rename_absolute(absolute + ".partial", absolute) != OK:
		return "Could not save the verified 3D download."
	return ""


func _valid_file(path: String, size: int, digest: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	return file != null and file.get_length() == size and FileAccess.get_sha256(path) == digest


func _sha256(bytes: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
