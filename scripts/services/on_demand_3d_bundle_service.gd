extends Node
## Downloads only the approved models requested by desktop battles and previews.

const RELEASE = preload("res://data/approved_3d_release_v7.json")
const RELEASE_V8 = preload("res://data/approved_3d_release_v8.json")
const RELEASE_V9 = preload("res://data/approved_3d_release_v9.json")
const RELEASE_V10 = preload("res://data/approved_3d_release_v10.json")
const RELEASE_V11 = preload("res://data/approved_3d_release_v11.json")
const ReviewedModels = preload("res://scripts/battle/battle_ui/reviewed_model_catalog.gd")
const DesktopAssetStorage = preload("res://scripts/services/desktop_asset_storage.gd")
const ModelPlatform = preload("res://scripts/battle/battle_ui/model_platform.gd")
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
var _local_checks := 0
var _storage_tasks: Array[int] = []
var _history_task := -1
var _history_work: StorageWork


func _exit_tree() -> void:
	# Storage callbacks use this Node; keep it alive until pending work exits.
	for task in _storage_tasks:
		WorkerThreadPool.wait_for_task_completion(task)
	_storage_tasks.clear()
	if _history_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_history_task)
		_history_task = -1
		_history_work = null

func _ready() -> void:
	if not ModelPlatform.supported():
		return
	var launcher_root := DesktopAssetStorage._launcher_root("POKEAETHER_LAUNCHER_MODEL_DIR")
	if not launcher_root.is_empty():
		var error := DesktopAssetStorage.register_model_usage(launcher_root, OS.get_process_id())
		if error != OK:
			push_warning("Could not record model store usage: " + error_string(error))
	if FileAccess.file_exists(ROOT.path_join("runtime-catalog.json")):
		_busy = true
		_history_work = StorageWork.new()
		_history_task = WorkerThreadPool.add_task(_history_work.run.bind(_prune_cached_model_history))
	else:
		set_process(false)


func _process(_delta: float) -> void:
	if _history_task >= 0 and WorkerThreadPool.is_task_completed(_history_task):
		WorkerThreadPool.wait_for_task_completion(_history_task)
		_report_cleanup(_history_work.result)
		_history_task = -1
		_history_work = null
		_busy = false
		set_process(false)


func _prune_cached_model_history() -> Dictionary:
	var release := _selected_release()
	if not release.get("index") is Dictionary:
		return {"error": "", "removed_objects": 0}
	var index := _read_local_index(_local_index_path(release), release)
	return _prune_unused_models(_catalog(ROOT.path_join("runtime-catalog.json")), index)

class StorageWork extends RefCounted:
	var result: Variant
	func run(action: Callable) -> void:
		result = action.call()


func _check_installed_models(identities: Array[String], source_catalog: String) -> Dictionary:
	# Full index/file SHA checks still run on every entry. Disk I/O must not
	# stop the arena fade or the world frames while cached files are verified.
	return await _run_storage_work(_installed_models.bind(identities.duplicate(), source_catalog))


func _run_storage_work(action: Callable) -> Variant:
	# Workers only access file data; HTTPRequest and downloader state stay here.
	var work := StorageWork.new()
	_local_checks += 1
	var task := WorkerThreadPool.add_task(work.run.bind(action))
	_storage_tasks.append(task)
	while not WorkerThreadPool.is_task_completed(task):
		await get_tree().process_frame
	if _storage_tasks.has(task):
		WorkerThreadPool.wait_for_task_completion(task) # Already completed during normal gameplay.
		_storage_tasks.erase(task)
	_local_checks -= 1
	return work.result


func can_clear_cache() -> bool:
	return not _busy and _battle_waiters == 0 and _local_checks == 0


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
	if not ModelPlatform.supported():
		return
	_prefetch_generation += 1
	_run_prefetch.call_deferred(preload("res://scripts/battle/battle_ui/model_form_dependencies.gd").with_forms(identities), _prefetch_generation)


func cancel_prefetch() -> void:
	_prefetch_generation += 1


func _run_prefetch(identities: Array[String], generation: int) -> void:
	for identity in identities:
		# Spread cached area/party checks across frames instead of checking a
		# whole area synchronously in one frame after changing maps.
		await get_tree().process_frame
		if generation != _prefetch_generation or not is_inside_tree():
			return
		if _asset_id(identity).is_empty():
			continue
		var source: String = get_tree().root.get_node("SettingsManager").get_battle_3d_catalog_path()
		var cached := await _check_installed_models([identity], source)
		if generation != _prefetch_generation or not is_inside_tree():
			return
		if not cached.is_empty():
			OS.set_environment("POKEAETHER_MODEL_CATALOG", str(cached.path))
			continue
		while _busy or _battle_waiters > 0:
			await get_tree().process_frame
			if generation != _prefetch_generation or not is_inside_tree():
				return
		_busy = true
		source = get_tree().root.get_node("SettingsManager").get_battle_3d_catalog_path()
		var result := await _ensure_models([identity], source)
		_busy = false
		if str(result.get("error", "")).is_empty() and not str(result.get("path", "")).is_empty():
			OS.set_environment("POKEAETHER_MODEL_CATALOG", str(result.path))


func battle_download_progress() -> Dictionary:
	# Local verification/import work is deliberately not a download indicator.
	if not is_instance_valid(active_request):
		return {}
	return {"received_bytes": active_request.get_downloaded_bytes(), "total_bytes": active_size}


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
	# Installed, verified combatants need no downloader lock or catalog write.
	# A different model may still be downloading in the background.
	var cached := await _check_installed_models(identities, source_catalog)
	if not cached.is_empty():
		return cached
	_battle_waiters += 1
	while _busy:
		await get_tree().process_frame
	_battle_waiters -= 1
	_busy = true
	var result := await _ensure_models(identities, source_catalog)
	_busy = false
	return result


func _installed_models(identities: Array[String], source_catalog: String) -> Dictionary:
	var release := _selected_release()
	var index := _read_local_index(_local_index_path(release), release)
	if index.is_empty():
		return {} # Initial installs and missing indexes use the normal downloader.
	var expected := {}
	for identity in identities:
		var asset_id := asset_id_for_identity(identity)
		if asset_id not in release.requiredAssetIds:
			continue
		var canonical := ReviewedModels.canonical_identity(identity)
		var asset := _indexed_asset(index, asset_id)
		var digest := ""
		for appearance in asset.get("appearances", []):
			if appearance is Dictionary and str(appearance.get("runtime_identity", "")) == canonical:
				digest = str(appearance.get("runtime_sha256", ""))
		if digest.is_empty():
			return {}
		expected[canonical] = digest
	if expected.is_empty():
		return {}
	var paths: Array[String] = []
	if not source_catalog.is_empty():
		paths.append(source_catalog)
	var own := ProjectSettings.globalize_path(ROOT.path_join("runtime-catalog.json"))
	if source_catalog.is_empty() or ProjectSettings.globalize_path(source_catalog) != own:
		paths.append(own)
	for path in paths:
		var entries := _catalog(path)
		var ready := true
		var verified_models := {}
		for identity: String in expected:
			var verified := _verified_entry(entries, identity, expected[identity])
			if verified.is_empty():
				ready = false
				break
			verified_models[identity] = verified
		if ready:
			# Reuse only a complete existing catalog. Mixed sources are merged
			# under the normal lock so concurrent installs cannot lose entries.
			return {"error": "", "path": path, "catalog_changed": false, "verified_models": verified_models}
	return {}


func _ensure_models(identities: Array[String], source_catalog: String) -> Dictionary:
	var existing: Array = await _run_storage_work(_catalog.bind(source_catalog))
	var own: Array = await _run_storage_work(_catalog.bind(ROOT.path_join("runtime-catalog.json")))
	var entries: Array = await _run_storage_work(_merge_entries.bind(existing, own))
	var requested: Array[String] = await _run_storage_work(_requested_assets.bind(identities.duplicate()))
	if requested.is_empty():
		var fallback: String = source_catalog if own.is_empty() else await _run_storage_work(_publish_catalog.bind(entries))
		return {"error": "", "path": fallback}
	var index_result := await _approved_index()
	if not str(index_result.get("error", "")).is_empty():
		return index_result
	var index: Dictionary = index_result.index
	var plan: Dictionary = await _run_storage_work(_missing_assets.bind(index, identities.duplicate(), entries))
	if not str(plan.get("error", "")).is_empty():
		return plan
	var missing: Array[String] = plan.asset_ids
	for asset_id in missing:
		var asset: Dictionary = _indexed_asset(index, asset_id)
		if asset.is_empty():
			return {"error": "Approved 3D model is missing from the content index."}
		var installed := await _install_asset(asset)
		if not str(installed.get("error", "")).is_empty():
			return installed
		entries = await _run_storage_work(_merge_entries.bind(entries, installed.entries))
	var path: String = await _run_storage_work(_publish_catalog.bind(entries))
	if not path.is_empty():
		_report_cleanup(await _run_storage_work(_prune_unused_models.bind(entries, index)))
	return {"error": "Could not publish the 3D model catalog." if path.is_empty() else "", "path": path,
		"catalog_changed": not missing.is_empty()}


func _requested_assets(identities: Array[String]) -> Array[String]:
	var requested: Array[String] = []
	for identity in identities:
		var asset_id := _asset_id(identity)
		if not asset_id.is_empty() and asset_id not in requested:
			requested.append(asset_id)
	return requested


func _missing_assets(index: Dictionary, identities: Array[String], entries: Array) -> Dictionary:
	var missing: Array[String] = []
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
	return {"error": "", "asset_ids": missing}


func _asset_id(identity: String) -> String:
	var id := asset_id_for_identity(identity)
	var selected_release := _selected_release()
	return id if id in selected_release.requiredAssetIds else ""


func _selected_release() -> Dictionary:
	var launcher_path := OS.get_environment("POKEAETHER_MODEL_INDEX")
	if launcher_path.is_absolute_path():
		for release: Dictionary in [RELEASE_V11.data, RELEASE_V10.data, RELEASE_V9.data, RELEASE_V8.data]:
			var pin: Dictionary = release.index
			if _valid_file(launcher_path, int(pin.size_bytes), str(pin.sha256)):
				return release
	# Editor runs use the latest published, hash-pinned project index.
	var published: Array[Dictionary] = [RELEASE_V10.data, RELEASE_V9.data, RELEASE_V8.data]
	if OS.has_feature("editor") and _v11_publication_verified():
		published.push_front(RELEASE_V11.data)
	for release: Dictionary in published:
		var editor_path := _editor_local_index_path(release)
		var pin: Dictionary = release.index
		if not editor_path.is_empty() and _valid_file(editor_path, int(pin.size_bytes), str(pin.sha256)):
			return release
	return RELEASE.data


static func _v11_publication_verified() -> bool:
	# Preparation alone must not request unpublished URLs in editor encounters.
	# The normal release publication step supplies this hash-bound receipt.
	var file := FileAccess.open("res://release/approved_3d_bundles_v11_r2_receipt.json", FileAccess.READ)
	if file == null or file.get_length() > MAX_CATALOG_BYTES:
		return false
	var receipt: Variant = JSON.parse_string(file.get_as_text())
	if not receipt is Dictionary or receipt.get("revision") != RELEASE_V11.data.revision or receipt.get("content_index") != RELEASE_V11.data.index:
		return false
	if receipt.get("lossless_binding_sha256") != ReviewedModels.DATA.data.get("native_lossless_binding_sha256"):
		return false
	var verification: Variant = receipt.get("index_verification")
	if not verification is Dictionary or not verification.get("public_get_sha256_verified", false) or not verification.get("public_head_size_verified", false):
		return false
	for field: String in ["object_key", "sha256", "size_bytes"]:
		if verification.get(field) != RELEASE_V11.data.index[field]:
			return false
	var bundles: Variant = receipt.get("bundles")
	if not bundles is Array or bundles.size() != RELEASE_V11.data.requiredAssetIds.size():
		return false
	var seen := {}
	for row: Variant in bundles:
		if not row is Dictionary or row.get("asset_id") not in RELEASE_V11.data.requiredAssetIds or seen.has(row.get("asset_id")) or not row.get("public_get_sha256_verified", false) or not row.get("public_head_size_verified", false):
			return false
		seen[row.asset_id] = true
	return true


static func _editor_local_index_path(release: Dictionary) -> String:
	if not OS.has_feature("editor"):
		return ""
	if release.revision == RELEASE_V11.data.revision:
		return ProjectSettings.globalize_path("res://release/approved_3d_bundles_v11_index.json")
	if release.revision == RELEASE_V10.data.revision:
		return ProjectSettings.globalize_path("res://release/approved_3d_bundles_v10_index.json")
	if release.revision == RELEASE_V9.data.revision:
		return ProjectSettings.globalize_path("res://release/approved_3d_bundles_v9_index.json")
	if release.revision == RELEASE_V8.data.revision:
		return _editor_local_v8_index_path()
	return ""


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
	return not _verified_entry(entries, identity, expected_digest).is_empty()


func _verified_entry(entries: Array, identity: String, expected_digest: String) -> Dictionary:
	for entry in entries:
		if not entry is Dictionary:
			continue
		var key := str(entry.get("species", "")) + ("@shiny" if entry.get("variant") == "shiny" else "")
		var model_path := str(entry.get("runtime_path", ""))
		var digest := str(entry.get("runtime_sha256", ""))
		if key == identity and digest == expected_digest and not ReviewedModels.resolve(identity, digest).is_empty() and _valid_file(model_path, int(entry.get("bytes", 0)), digest):
			return {"path": model_path, "sha256": digest, "bytes": int(entry.bytes)}
	return {}


func _local_index_path(release: Dictionary) -> String:
	var pin: Dictionary = release.index
	var launcher_path := OS.get_environment("POKEAETHER_MODEL_INDEX")
	if launcher_path.is_absolute_path() and _valid_file(launcher_path, int(pin.size_bytes), str(pin.sha256)):
		return launcher_path
	elif release.revision in [RELEASE_V11.data.revision, RELEASE_V10.data.revision, RELEASE_V9.data.revision, RELEASE_V8.data.revision]:
		var editor_path := _editor_local_index_path(release)
		if not editor_path.is_empty() and _valid_file(editor_path, int(pin.size_bytes), str(pin.sha256)):
			return editor_path
	return ROOT.path_join("index-%s.json" % pin.sha256)


func _read_local_index(path: String, release: Dictionary) -> Dictionary:
	var pin: Dictionary = release.index
	if not _valid_file(path, int(pin.size_bytes), str(pin.sha256)):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("assets") is Array or parsed.get("catalog_revision") != release.revision:
		return {}
	return parsed


func _approved_index() -> Dictionary:
	var release: Dictionary = await _run_storage_work(_selected_release)
	var pin: Dictionary = release.index
	var path: String = await _run_storage_work(_local_index_path.bind(release))
	var valid: bool = await _run_storage_work(_valid_file.bind(path, int(pin.size_bytes), str(pin.sha256)))
	if not valid:
		var result := await _fetch(BASE_URL + str(pin.object_key), path, int(pin.size_bytes), str(pin.sha256), MAX_INDEX_BYTES, "3D content index")
		if not result.is_empty():
			return {"error": result}
	var parsed: Dictionary = await _run_storage_work(_read_local_index.bind(path, release))
	if parsed.is_empty():
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
	var valid: bool = await _run_storage_work(_valid_file.bind(zip_path, size, sha))
	if not valid:
		var error := await _fetch(BASE_URL + key, zip_path, size, sha, MAX_ARCHIVE_BYTES, parts[1])
		if not error.is_empty():
			return {"error": error}
	active_label = "Installing %s…" % parts[1]
	return await _run_storage_work(_install_verified_archive.bind(asset.duplicate(true), zip_path))


func _install_verified_archive(asset: Dictionary, zip_path: String) -> Dictionary:
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


func _report_cleanup(result: Dictionary) -> void:
	if not str(result.get("error", "")).is_empty():
		push_warning(str(result.error))


func _prune_unused_models(entries: Array, index: Dictionary, storage_root: String = ROOT) -> Dictionary:
	var result := {"error": "", "removed_objects": 0}
	# A missing index/catalog or interrupted publication must never remove files.
	if entries.is_empty() or index.is_empty() or not index.get("assets") is Array:
		return result
	var catalog_path := storage_root.path_join("runtime-catalog.json")
	if _catalog(catalog_path) != JSON.parse_string(JSON.stringify(entries)):
		return result
	var objects_root := ProjectSettings.globalize_path(storage_root.path_join("objects")).simplify_path()
	var parent := DirAccess.open(objects_root.get_base_dir())
	if parent == null or parent.is_link("objects"):
		return result
	var directory := DirAccess.open(objects_root)
	if directory == null:
		return result
	var referenced := {}
	for entry: Variant in entries:
		if not entry is Dictionary:
			return result
		var path := ProjectSettings.globalize_path(str(entry.get("runtime_path", ""))).simplify_path()
		if path.begins_with(objects_root + "/"):
			referenced[path.get_base_dir().get_file()] = true
	# Preserve completed and partial members of an interrupted current download.
	for asset: Variant in index.assets:
		if asset is Dictionary:
			referenced[str(asset.get("sha256", ""))] = true
	var candidates: Array[String] = []
	for digest in directory.get_directories():
		if digest.length() != 64 or not digest.is_valid_hex_number() or referenced.has(digest) or directory.is_link(digest):
			continue
		var child := DirAccess.open(objects_root.path_join(digest))
		if child == null or not child.get_directories().is_empty():
			continue
		var owned := true
		for name in child.get_files():
			if child.is_link(name) or name not in ["normal.scn", "shiny.scn", "normal.scn.partial", "shiny.scn.partial"]:
				owned = false
		if owned:
			candidates.append(objects_root.path_join(digest))
	if candidates.is_empty():
		return result
	# Independently verify the surviving local models before removing history.
	for entry: Dictionary in entries:
		var path := ProjectSettings.globalize_path(str(entry.get("runtime_path", ""))).simplify_path()
		if path.begins_with(objects_root + "/") and not _valid_file(path, int(entry.get("bytes", 0)), str(entry.get("runtime_sha256", ""))):
			result.error = "Current downloaded model failed verification; previous files kept."
			return result
	for path in candidates:
		if DesktopAssetStorage.remove_directory(path):
			result.removed_objects += 1
		else:
			result.error = "Could not remove a previous downloaded model version."
	return result


func _fetch(url: String, path: String, expected: int, digest: String, limit: int, label: String) -> String:
	if expected < 1 or expected > limit or not url.begins_with(BASE_URL):
		return "Invalid approved 3D download."
	var absolute := ProjectSettings.globalize_path(path)
	if DirAccess.make_dir_recursive_absolute(absolute.get_base_dir()) != OK:
		return "Could not prepare 3D download storage."
	active_request = HTTPRequest.new()
	active_request.use_threads = true
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
	return await _run_storage_work(_publish_verified_download.bind(absolute, expected, digest))


func _publish_verified_download(absolute: String, expected: int, digest: String) -> String:
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
