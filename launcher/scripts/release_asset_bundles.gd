extends RefCounted
## Minimal release adapter for the seven approved desktop 3D Pokemon bundles.
const BundleIndex = preload("asset_bundle_index.gd")
const BundleStore = preload("asset_bundle_store.gd")
const Approval = preload("model_pack_manifest.gd")

const DESCRIPTOR_SCHEMA := 1
const DESCRIPTOR_KIND := "pokeaether-release-asset-index"
const RELEASE_ASSET_IDS: Array[String] = [
	"pokemon_3d:arcanine:base",
	"pokemon_3d:articuno:base",
	"pokemon_3d:dragonite:base",
	"pokemon_3d:lucario:base",
	"pokemon_3d:pikachu:base",
	"pokemon_3d:roaring-moon:base",
	"pokemon_3d:snorlax:base",
]

var store: RefCounted
var index_root: String


func _init(store_directory := "user://asset-bundles-v1", index_directory := "user://asset-bundle-indexes-v1") -> void:
	store = BundleStore.new(store_directory)
	index_root = ProjectSettings.globalize_path(index_directory)


static func descriptor_error(descriptor: Dictionary) -> String:
	if descriptor.get("schema") != DESCRIPTOR_SCHEMA or descriptor.get("kind") != DESCRIPTOR_KIND:
		return "Unsupported asset bundle index descriptor."
	for field in ["revision", "url", "objectBaseUrl", "sha256"]:
		if not descriptor.get(field) is String or str(descriptor.get(field)).is_empty():
			return "Asset bundle index descriptor is incomplete."
	if not BundleIndex._hex(str(descriptor.sha256)) or int(descriptor.get("sizeBytes", 0)) < 1 or int(descriptor.sizeBytes) > BundleStore.MAX_JSON:
		return "Asset bundle index integrity metadata is invalid."
	if not _http_url(str(descriptor.url)) or not _http_url(str(descriptor.objectBaseUrl)):
		return "Asset bundle index URL is invalid."
	var requested: Variant = descriptor.get("requiredAssetIds")
	if not requested is Array or requested.size() != RELEASE_ASSET_IDS.size():
		return "Asset bundle release set is invalid."
	var normalized: Array[String] = []
	for value: Variant in requested:
		if not value is String or value in normalized:
			return "Asset bundle release set is invalid."
		normalized.append(value)
	normalized.sort()
	var expected := RELEASE_ASSET_IDS.duplicate()
	expected.sort()
	if normalized != expected:
		return "Asset bundle release set is not approved."
	return ""


static func _http_url(value: String) -> bool:
	return value.begins_with("https://") or (OS.is_debug_build() and value.begins_with("http://"))


func cached_index(descriptor: Dictionary) -> Dictionary:
	if not descriptor_error(descriptor).is_empty():
		return {}
	var path := _index_path(str(descriptor.sha256))
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(descriptor.sizeBytes) or FileAccess.get_sha256(path) != str(descriptor.sha256):
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not _release_index_error(parsed).is_empty():
		return {}
	return parsed


func jobs(descriptor: Dictionary) -> Dictionary:
	var error := descriptor_error(descriptor)
	if not error.is_empty():
		return {"error": error, "jobs": []}
	var index := cached_index(descriptor)
	if index.is_empty():
		return {"error": "", "jobs": [_index_job(descriptor)]}
	return _bundle_jobs(index, descriptor)


func accept_index(descriptor: Dictionary, downloaded_path: String) -> Dictionary:
	var error := descriptor_error(descriptor)
	if not error.is_empty():
		return {"error": error, "jobs": []}
	var file := FileAccess.open(downloaded_path, FileAccess.READ)
	if file == null or file.get_length() != int(descriptor.sizeBytes) or FileAccess.get_sha256(downloaded_path) != str(descriptor.sha256):
		return {"error": "Asset bundle index integrity check failed.", "jobs": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"error": "Asset bundle index is invalid.", "jobs": []}
	error = _release_index_error(parsed)
	if not error.is_empty():
		return {"error": error, "jobs": []}
	if DirAccess.make_dir_recursive_absolute(index_root) != OK:
		return {"error": "Cannot create asset bundle index store.", "jobs": []}
	var destination := _index_path(str(descriptor.sha256))
	if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) == str(descriptor.sha256):
		return _bundle_jobs(parsed, descriptor)
	var temporary := index_root.path_join(".index-" + str(Time.get_ticks_usec()))
	var output := FileAccess.open(temporary, FileAccess.WRITE)
	if output == null:
		return {"error": "Cannot stage asset bundle index.", "jobs": []}
	output.store_buffer(FileAccess.get_file_as_bytes(downloaded_path))
	var write_error := output.get_error()
	output.close()
	var previous := destination + ".invalid"
	DirAccess.remove_absolute(previous)
	if write_error != OK or FileAccess.get_sha256(temporary) != str(descriptor.sha256):
		DirAccess.remove_absolute(temporary)
		return {"error": "Cannot publish asset bundle index.", "jobs": []}
	if FileAccess.file_exists(destination) and DirAccess.rename_absolute(destination, previous) != OK:
		DirAccess.remove_absolute(temporary)
		return {"error": "Cannot replace invalid asset bundle index.", "jobs": []}
	if DirAccess.rename_absolute(temporary, destination) != OK:
		if FileAccess.file_exists(previous):
			DirAccess.rename_absolute(previous, destination)
		DirAccess.remove_absolute(temporary)
		return {"error": "Cannot publish asset bundle index.", "jobs": []}
	DirAccess.remove_absolute(previous)
	return _bundle_jobs(parsed, descriptor)


func accept_bundle(index: Dictionary, asset_id: String, downloaded_path: String) -> Dictionary:
	var error := _release_index_error(index)
	if not error.is_empty():
		return {"error": error}
	if asset_id not in RELEASE_ASSET_IDS:
		return {"error": "Asset bundle is outside the approved release set."}
	return store.install_archive(index, asset_id, downloaded_path)


func catalog_path() -> String:
	return store.catalog_path()


func _index_path(digest: String) -> String:
	return index_root.path_join(digest + ".json")


func _index_job(descriptor: Dictionary) -> Dictionary:
	return {
		"type": "asset_bundle_index",
		"id": "approved-pokemon-3d-index",
		"version": str(descriptor.revision),
		"url": str(descriptor.url),
		"sha256": str(descriptor.sha256),
		"size_bytes": int(descriptor.sizeBytes),
		"file_name": "approved-pokemon-3d-index.json",
		"label": "approved 3D Pokemon index",
	}


func _bundle_jobs(index: Dictionary, descriptor: Dictionary) -> Dictionary:
	var plan: Dictionary = store.plan(index, RELEASE_ASSET_IDS)
	if not str(plan.get("error", "")).is_empty():
		return {"error": str(plan.error), "jobs": []}
	if not plan.get("missing", []).is_empty():
		return {"error": "Approved release bundle is missing from the content index.", "jobs": []}
	var indexed := BundleIndex.by_id(index)
	var result: Array[Dictionary] = []
	for asset_id: String in plan.downloads:
		var asset: Dictionary = indexed[asset_id]
		var object_key := str(asset.object_key)
		if not _safe_object_key(asset_id, object_key):
			return {"error": "Asset bundle object key is invalid.", "jobs": []}
		result.append({
			"type": "asset_bundle",
			"id": asset_id,
			"version": str(asset.version),
			"url": str(descriptor.objectBaseUrl).trim_suffix("/") + "/" + object_key,
			"sha256": str(asset.sha256),
			"size_bytes": int(asset.size_bytes),
			"file_name": object_key.get_file(),
			"label": str(asset.species_id) + " 3D models",
		})
	return {"error": "", "jobs": result, "unchanged": plan.unchanged}


func _release_index_error(index: Dictionary) -> String:
	var error := BundleIndex.validate(index)
	if not error.is_empty():
		return error
	var assets: Variant = index.get("assets")
	if not assets is Array or assets.size() != RELEASE_ASSET_IDS.size():
		return "Asset bundle index does not contain the exact approved release set."
	var seen: Array[String] = []
	for asset: Variant in assets:
		if not asset is Dictionary:
			return "Asset bundle index contains an invalid asset."
		var asset_id := str(asset.get("asset_id", ""))
		if asset_id not in RELEASE_ASSET_IDS or asset_id in seen or asset.get("form_id") != "base":
			return "Asset bundle index contains an unapproved asset."
		seen.append(asset_id)
		var appearances: Variant = asset.get("appearances")
		if not appearances is Array or appearances.size() != 2:
			return "Approved Pokemon bundle must contain normal and shiny appearances."
		var variants: Array[String] = []
		for appearance: Variant in appearances:
			if not appearance is Dictionary:
				return "Asset bundle appearance is invalid."
			var variant := str(appearance.get("variant", ""))
			var identity := str(appearance.get("runtime_identity", ""))
			var expected_identity := str(asset.species_id) + ("@shiny" if variant == "shiny" else "")
			var approved: Dictionary = Approval.DATA.data.models.get(identity, {})
			if variant not in ["normal", "shiny"] or variant in variants or identity != expected_identity:
				return "Asset bundle appearance identity is not approved."
			if not Approval.approved_digest(approved, str(appearance.get("runtime_sha256", ""))):
				return "Asset bundle model hash is not release-approved."
			variants.append(variant)
		variants.sort()
		if variants != ["normal", "shiny"]:
			return "Approved Pokemon bundle must contain normal and shiny appearances."
	seen.sort()
	var expected := RELEASE_ASSET_IDS.duplicate()
	expected.sort()
	return "" if seen == expected else "Asset bundle index does not contain the exact approved release set."


static func _safe_object_key(asset_id: String, key: String) -> bool:
	var parts := asset_id.split(":")
	if parts.size() != 3:
		return false
	var prefix := "optional-assets/pokemon_3d/%s/%s/" % [parts[1], parts[2]]
	if not key.begins_with(prefix) or not key.ends_with(".zip") or key.contains("\\") or key.contains(":"):
		return false
	for part in key.split("/"):
		if part in ["", ".", ".."]:
			return false
	return true
