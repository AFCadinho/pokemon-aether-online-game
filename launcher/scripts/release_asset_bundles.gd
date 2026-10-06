extends RefCounted
## Release adapter for pinned, individually approved 3D catalogs.
const BundleIndex = preload("asset_bundle_index.gd")
const BundleStore = preload("asset_bundle_store.gd")
const Approval = preload("model_pack_manifest.gd")
const V5 = preload("res://data/approved_3d_release_v5.json")
const V6 = preload("res://data/approved_3d_release_v6.json")
const V7 = preload("res://data/approved_3d_release_v7.json")
const V8 = preload("res://data/approved_3d_release_v8.json")
const V9 = preload("res://data/approved_3d_release_v9.json")
const V10 = preload("res://data/approved_3d_release_v10.json")

const DESCRIPTOR_SCHEMA := 1
const DESCRIPTOR_KIND := "pokeaether-release-asset-index"
const V1_ASSET_IDS: Array[String] = [
	"pokemon_3d:arcanine:base",
	"pokemon_3d:articuno:base",
	"pokemon_3d:dragonite:base",
	"pokemon_3d:lucario:base",
	"pokemon_3d:pikachu:base",
	"pokemon_3d:roaring-moon:base",
	"pokemon_3d:snorlax:base",
]
const RELEASE_ASSET_IDS: Array[String] = [
	"pokemon_3d:arcanine:base", "pokemon_3d:articuno:base",
	"pokemon_3d:charmeleon:base", "pokemon_3d:dragonite:base",
	"pokemon_3d:dunsparce:base", "pokemon_3d:flaaffy:base",
	"pokemon_3d:houndoom:base", "pokemon_3d:houndour:base",
	"pokemon_3d:igglybuff:base", "pokemon_3d:lucario:base",
	"pokemon_3d:mareep:base", "pokemon_3d:persian:base",
	"pokemon_3d:phanpy:base", "pokemon_3d:pikachu:base",
	"pokemon_3d:roaring-moon:base", "pokemon_3d:skiploom:base",
	"pokemon_3d:slowking:base", "pokemon_3d:snorlax:base",
	"pokemon_3d:stantler:base", "pokemon_3d:teddiursa:base",
	"pokemon_3d:ursaring:base",
]
const MEGA_ID := "pokemon_3d:dragonite:mega"

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
	if not requested is Array:
		return "Asset bundle release set is invalid."
	var normalized: Array[String] = []
	for value: Variant in requested:
		if not value is String or value in normalized:
			return "Asset bundle release set is invalid."
		normalized.append(value)
	normalized.sort()
	var original := V1_ASSET_IDS.duplicate()
	original.sort()
	var expanded := RELEASE_ASSET_IDS.duplicate()
	expanded.sort()
	var matched_pinned_set := false
	for release: Dictionary in _pinned_releases():
		var ids := _release_ids(release)
		ids.sort()
		if normalized != ids:
			continue
		matched_pinned_set = true
		var pin: Dictionary = release.index
		if (descriptor.revision == release.revision and descriptor.sha256 == pin.sha256
				and descriptor.sizeBytes == pin.size_bytes
				and str(descriptor.url).ends_with("/" + str(pin.object_key))):
			return ""
	# Successive pinned releases may intentionally contain the same IDs. Match
	# one complete revision/hash/size/key tuple, rather than requiring all pins.
	if matched_pinned_set:
		return "Asset bundle release index differs from the approved pinned revisions."
	return "" if normalized == original or normalized == expanded else "Asset bundle release set is not approved."


static func _pinned_releases() -> Array[Dictionary]:
	return [V10.data, V9.data, V8.data, V7.data, V6.data, V5.data]


static func _release_ids(release: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for asset_id: String in release.requiredAssetIds:
		result.append(asset_id)
	return result

static func _v5_ids() -> Array[String]:
	var result: Array[String] = []
	for asset_id: String in V5.data.requiredAssetIds:
		result.append(asset_id)
	return result


static func _v6_ids() -> Array[String]:
	var result: Array[String] = []
	for asset_id: String in V6.data.requiredAssetIds:
		result.append(asset_id)
	return result


static func _v7_ids() -> Array[String]:
	var result: Array[String] = []
	for asset_id: String in V7.data.requiredAssetIds:
		result.append(asset_id)
	return result


static func _v8_ids() -> Array[String]:
	var result: Array[String] = []
	for asset_id: String in V8.data.requiredAssetIds:
		result.append(asset_id)
	return result


static func _v9_ids() -> Array[String]:
	var result: Array[String] = []
	for asset_id: String in V9.data.requiredAssetIds:
		result.append(asset_id)
	return result


static func _v10_ids() -> Array[String]:
	var result: Array[String] = []
	for asset_id: String in V10.data.requiredAssetIds:
		result.append(asset_id)
	return result


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
	if not parsed is Dictionary or not _release_index_error(parsed, descriptor).is_empty():
		return {}
	return parsed


func jobs(descriptor: Dictionary, include_bundles := true) -> Dictionary:
	var error := descriptor_error(descriptor)
	if not error.is_empty():
		return {"error": error, "jobs": []}
	var index := cached_index(descriptor)
	if index.is_empty():
		return {"error": "", "jobs": [_index_job(descriptor)]}
	return _bundle_jobs(index, descriptor) if include_bundles else {"error": "", "jobs": []}


func accept_index(descriptor: Dictionary, downloaded_path: String, include_bundles := true) -> Dictionary:
	var error := descriptor_error(descriptor)
	if not error.is_empty():
		return {"error": error, "jobs": []}
	var file := FileAccess.open(downloaded_path, FileAccess.READ)
	if file == null or file.get_length() != int(descriptor.sizeBytes) or FileAccess.get_sha256(downloaded_path) != str(descriptor.sha256):
		return {"error": "Asset bundle index integrity check failed.", "jobs": []}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return {"error": "Asset bundle index is invalid.", "jobs": []}
	error = _release_index_error(parsed, descriptor)
	if not error.is_empty():
		return {"error": error, "jobs": []}
	if DirAccess.make_dir_recursive_absolute(index_root) != OK:
		return {"error": "Cannot create asset bundle index store.", "jobs": []}
	var destination := _index_path(str(descriptor.sha256))
	if FileAccess.file_exists(destination) and FileAccess.get_sha256(destination) == str(descriptor.sha256):
		return _bundle_jobs(parsed, descriptor) if include_bundles else {"error": "", "jobs": []}
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
	return _bundle_jobs(parsed, descriptor) if include_bundles else {"error": "", "jobs": []}


func accept_bundle(index: Dictionary, asset_id: String, downloaded_path: String) -> Dictionary:
	var error := _release_index_error(index)
	if not error.is_empty():
		return {"error": error}
	if (asset_id not in RELEASE_ASSET_IDS and asset_id not in _v5_ids() and asset_id not in _v6_ids()
			and asset_id not in _v7_ids() and asset_id not in _v8_ids() and asset_id not in _v9_ids() and asset_id not in _v10_ids()):
		return {"error": "Asset bundle is outside the approved release set."}
	return store.install_archive(index, asset_id, downloaded_path)


func accept_bundles(index: Dictionary, archives: Dictionary) -> Dictionary:
	var error := _release_index_error(index)
	if not error.is_empty():
		return {"error": error}
	return store.install_archives(index, archives)


func begin_collection(index: Dictionary, requested_ids: Array[String]) -> Dictionary:
	var error := _release_index_error(index)
	return {"error": error} if not error.is_empty() else store.begin_collection(index, requested_ids)


func stage_collection(session: Dictionary, asset_id: String, archive_path: String) -> Dictionary:
	var error := _release_index_error(session.get("index", {}))
	return {"error": error} if not error.is_empty() else store.stage_collection(session, asset_id, archive_path)


func finish_collection(session: Dictionary) -> Dictionary:
	var error := _release_index_error(session.get("index", {}))
	return {"error": error} if not error.is_empty() else store.finish_collection(session)


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
	var requested: Array[String] = []
	for asset_id: String in descriptor.requiredAssetIds:
		requested.append(asset_id)
	var plan: Dictionary = store.plan(index, requested)
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


func _release_index_error(index: Dictionary, descriptor: Dictionary = {}) -> String:
	var error := BundleIndex.validate(index)
	if not error.is_empty():
		return error
	var assets: Variant = index.get("assets")
	var expected: Array[String] = []
	if descriptor.has("requiredAssetIds"):
		for asset_id: String in descriptor.requiredAssetIds:
			expected.append(asset_id)
		if index.get("catalog_revision") != descriptor.get("revision"):
			return "Asset bundle index revision does not match its descriptor."
	else:
		for release: Dictionary in _pinned_releases():
			if release.revision == index.get("catalog_revision"):
				expected = _release_ids(release)
				break
		if expected.is_empty():
			# Keep the two historical, unpinned small catalogs compatible. Larger
			# catalogs must name a known revision, even if their sizes are equal.
			if assets is Array and assets.size() == V1_ASSET_IDS.size():
				expected = V1_ASSET_IDS.duplicate()
			elif assets is Array and assets.size() == RELEASE_ASSET_IDS.size():
				expected = RELEASE_ASSET_IDS.duplicate()
			else:
				return "Asset bundle index revision is not approved."
	if not assets is Array or assets.size() != expected.size():
		return "Asset bundle index does not contain the exact approved release set."
	var seen: Array[String] = []
	for asset: Variant in assets:
		if not asset is Dictionary:
			return "Asset bundle index contains an invalid asset."
		var asset_id := str(asset.get("asset_id", ""))
		var form := str(asset.get("form_id", ""))
		if asset_id not in expected or asset_id in seen or form not in ["base", "mega", "mega-x", "mega-y", "mega-z"]:
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
			var expected_identity := str(asset.species_id) + ("-" + form if form != "base" else "") + ("@shiny" if variant == "shiny" else "")
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
