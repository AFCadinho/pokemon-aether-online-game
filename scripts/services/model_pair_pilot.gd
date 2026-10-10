extends RefCounted
## Local opt-in until installers, real battles and platform release checks qualify.
const DATA = preload("res://data/model_pair_pilot.json")
const CATALOG_PATH := "res://data/model_pair_catalog.json"
static var _catalog := {}
static var _lookups := {}
static var _catalog_mutex := Mutex.new()
static var _lookup_mutex := Mutex.new()

static func catalog_enabled() -> bool:
	return OS.is_debug_build() and OS.get_environment("POKEAETHER_SHARED_MODEL_CATALOG_TEST") == "1"

static func enabled() -> bool:
	return catalog_enabled() or (OS.is_debug_build() and OS.get_environment("POKEAETHER_SHARED_MODEL_PILOT") == "1")

static func data_path() -> String:
	return CATALOG_PATH if catalog_enabled() else "res://data/model_pair_pilot.json"

static func catalog() -> Dictionary:
	if not catalog_enabled():
		return DATA.data
	_catalog_mutex.lock()
	if _catalog.is_empty():
		# Only this checked-in resource supplies bindings; a local index cannot.
		_catalog = load(CATALOG_PATH).data
	_catalog_mutex.unlock()
	return _catalog

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
				for appearance: Dictionary in asset.appearances:
					lookup[str(appearance.runtime_identity) + ":" + str(appearance.runtime_sha256)] = asset
		_lookups[path] = lookup
	var result: Dictionary = _lookups[path].get(identity + ":" + digest, {}).duplicate(true)
	_lookup_mutex.unlock()
	return result

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
