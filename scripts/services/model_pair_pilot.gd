extends RefCounted
## Local opt-in until installers, real battles and platform release checks qualify.
const DATA = preload("res://data/model_pair_pilot.json")
const CATALOG_PATH := "res://data/model_pair_catalog.json"
const QUALIFIED_PATH := "res://data/model_pair_qualified.json"
const REFERENCE_FORMAT := "model-pair-ref-v1"
static var _catalog := {}
static var _qualified_catalog := {}
static var _lookups := {}
static var _catalog_mutex := Mutex.new()
static var _lookup_mutex := Mutex.new()

static func catalog_enabled() -> bool:
	return OS.is_debug_build() and OS.get_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST") == "1"

static func qualified_enabled() -> bool:
	return OS.is_debug_build() and OS.get_environment("POKEAETHER_SHARED_MODEL_QUALIFIED_TEST") == "1"

static func enabled() -> bool:
	return qualified_enabled() or catalog_enabled() or (OS.is_debug_build() and OS.get_environment("POKEAETHER_SHARED_MODEL_PILOT") == "1")

static func data_path() -> String:
	if qualified_enabled():
		return QUALIFIED_PATH
	return CATALOG_PATH if catalog_enabled() else "res://data/model_pair_pilot.json"

static func catalog() -> Dictionary:
	if not catalog_enabled() and not qualified_enabled():
		return DATA.data
	_catalog_mutex.lock()
	if _catalog.is_empty():
		# Only this checked-in resource supplies bindings; a local index cannot.
		_catalog = load(CATALOG_PATH).data
	var result := _catalog
	if qualified_enabled():
		if _qualified_catalog.is_empty():
			_qualified_catalog = _expand_index(load(QUALIFIED_PATH).data, _catalog)
		result = _qualified_catalog
	_catalog_mutex.unlock()
	return result

static func release() -> Dictionary:
	if not enabled():
		return {}
	var path := data_path()
	var selected := catalog()
	var digest := FileAccess.get_sha256(path)
	var file := FileAccess.open(path, FileAccess.READ)
	var ids: Array[String] = []
	for asset: Dictionary in selected.assets:
		ids.append(str(asset.asset_id))
	return {"revision": selected.catalog_revision, "requiredAssetIds": ids,
		"index": {"object_key": "optional-assets/pokemon_3d/index/pilot-" + digest + ".json", "sha256": digest, "size_bytes": file.get_length()}}

static func asset_for(identity: String, digest: String) -> Dictionary:
	if not enabled():
		return {}
	var path := data_path()
	_lookup_mutex.lock()
	if not _lookups.has(path):
		var lookup := {}
		for asset: Dictionary in catalog().assets:
			if asset.get("format") == "model-pair-pck-v1":
				lookup["asset:" + str(asset.asset_id) + ":" + str(asset.sha256)] = asset
				for appearance: Dictionary in asset.appearances:
					lookup[str(appearance.runtime_identity) + ":" + str(appearance.runtime_sha256)] = asset
		_lookups[path] = lookup
	var result: Dictionary = _lookups[path].get(identity + ":" + digest, {}).duplicate(true)
	_lookup_mutex.unlock()
	return result

static func reference_asset(reference: Variant) -> Dictionary:
	if not reference is Dictionary or reference.size() != 2 or not reference.get("asset_id") is String or not reference.get("sha256") is String:
		return {}
	return asset_for("asset:" + reference.asset_id, reference.sha256)

static func _expand_index(value: Dictionary, trusted: Dictionary) -> Dictionary:
	if not value.get("assets") is Array:
		return {}
	var by_id := {}
	for asset: Dictionary in trusted.get("assets", []):
		by_id[str(asset.asset_id)] = asset
	var result := value.duplicate(true)
	for position in result.assets.size():
		var row: Variant = result.assets[position]
		if not row is Dictionary:
			return {}
		if row.get("format") != REFERENCE_FORMAT:
			continue
		var asset: Dictionary = by_id.get(row.get("asset_id", ""), {})
		if row.size() != 3 or asset.get("format") != "model-pair-pck-v1" or row.get("sha256") != asset.get("sha256"):
			return {}
		result.assets[position] = asset.duplicate(true)
	return result

static func expand_index(value: Dictionary) -> Dictionary:
	# References are meaningful only against the currently compiled opt-in set.
	return _expand_index(value, catalog() if enabled() else {})

static func compact_entries(entries: Array) -> Array:
	if not qualified_enabled():
		return entries
	var result := entries.duplicate(true)
	for entry: Dictionary in result:
		_compact_pair(entry)
	return result

static func expand_entries(value: Variant) -> Array:
	if not value is Array:
		return []
	for entry: Variant in value:
		if entry is Dictionary and not _expand_pair(entry):
			return []
	return value

static func compact_state(state: Dictionary) -> Dictionary:
	if not qualified_enabled():
		return state
	var result := state.duplicate(true)
	for entry: Dictionary in result.get("assets", {}).values():
		_compact_pair(entry)
	return result

static func expand_state(state: Dictionary) -> Dictionary:
	if not state.get("assets") is Dictionary:
		return {}
	for entry: Variant in state.assets.values():
		if not entry is Dictionary or not _expand_pair(entry):
			return {}
	return state

static func _compact_pair(entry: Dictionary) -> void:
	if entry.get("pair_asset") is Dictionary:
		var asset: Dictionary = entry.pair_asset
		var reference := {"asset_id": asset.get("asset_id"), "sha256": asset.get("sha256")}
		if reference_asset(reference) == asset:
			entry.erase("pair_asset")
			entry["pair_ref"] = reference

static func _expand_pair(entry: Dictionary) -> bool:
	if not entry.has("pair_ref"):
		return true
	if entry.has("pair_asset"):
		return false
	var asset := reference_asset(entry.pair_ref)
	if asset.is_empty():
		return false
	entry.erase("pair_ref")
	entry["pair_asset"] = asset
	return true

static func source_digest(identity: String, digest: String) -> String:
	for appearance: Dictionary in asset_for(identity, digest).get("appearances", []):
		if appearance.runtime_identity == identity:
			return str(appearance.source_sha256)
	return digest

static func entry_asset(entry: Dictionary) -> Dictionary:
	var identity := str(entry.get("species", "")).trim_suffix("@shiny")
	if entry.get("variant") == "shiny" or str(entry.get("species", "")).ends_with("@shiny"):
		identity += "@shiny"
	var asset := asset_for(identity, str(entry.get("runtime_sha256", "")))
	if asset.is_empty() or entry.get("pair_asset") != asset or not str(entry.get("pack_path", "")).is_absolute_path():
		return {}
	for appearance: Dictionary in asset.appearances:
		if appearance.runtime_identity == identity:
			if entry.get("runtime_path") == str(asset.pair_manifest.resource_root).path_join(appearance.runtime_path) and entry.get("bytes") == appearance.bytes:
				return asset
	return {}
