extends RefCounted
## Local opt-in until installers, real battles and platform release checks qualify.
const DATA = preload("res://data/model_pair_pilot.json")

static func enabled() -> bool:
	return OS.is_debug_build() and OS.get_environment("POKEAETHER_SHARED_MODEL_PILOT") == "1"

static func release() -> Dictionary:
	if not enabled():
		return {}
	var path := "res://data/model_pair_pilot.json"
	var digest := FileAccess.get_sha256(path)
	var file := FileAccess.open(path, FileAccess.READ)
	var ids: Array[String] = []
	for asset: Dictionary in DATA.data.assets:
		ids.append(str(asset.asset_id))
	return {"revision": DATA.data.catalog_revision, "requiredAssetIds": ids,
		"index": {"object_key": "optional-assets/pokemon_3d/index/pilot-" + digest + ".json", "sha256": digest, "size_bytes": file.get_length()}}

static func asset_for(identity: String, digest: String) -> Dictionary:
	if not enabled():
		return {}
	for asset: Dictionary in DATA.data.assets:
		if asset.get("format") != "model-pair-pck-v1":
			continue
		for appearance: Dictionary in asset.appearances:
			if appearance.runtime_identity == identity and appearance.runtime_sha256 == digest:
				return asset.duplicate(true)
	return {}

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

