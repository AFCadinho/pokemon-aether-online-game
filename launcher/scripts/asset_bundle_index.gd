extends RefCounted
## Data-only index for optional, independently versioned asset bundles.
const SCHEMA := 1
const KIND := "pokeaether-optional-asset-index"
const SUPPORTED_TYPES := ["pokemon_3d"]
const MAX_ASSETS := 10000
const MAX_ARCHIVE_BYTES := 512 * 1024 * 1024


static func _hex(value: String) -> bool:
	if value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true


static func _token(value: String) -> bool:
	if value.is_empty() or value.length() > 100:
		return false
	for character in value:
		if character not in "abcdefghijklmnopqrstuvwxyz0123456789-_":
			return false
	return true


static func valid_asset_id(value: String) -> bool:
	var parts := value.split(":")
	if parts.size() != 3:
		return false
	for part: String in parts:
		if not _token(part):
			return false
	return true


static func safe_object_key(value: String) -> bool:
	if value.is_empty() or value.length() > 512 or value.is_absolute_path() or value.contains("\\") or value.contains(":"):
		return false
	for part in value.split("/"):
		if part in ["", ".", ".."]:
			return false
	return value.ends_with(".zip")


static func validate(index: Dictionary) -> String:
	if index.get("schema") != SCHEMA or index.get("kind") != KIND:
		return "Unsupported asset index."
	if not index.get("catalog_revision") is String or str(index.catalog_revision).strip_edges().is_empty():
		return "Asset index has no catalog revision."
	var contract: Variant = index.get("runtime_contract")
	if not contract is Dictionary or contract.get("pokemon_3d") != 1 or contract.get("godot") != "4.6":
		return "Unsupported runtime contract."
	var assets: Variant = index.get("assets")
	if not assets is Array or assets.is_empty() or assets.size() > MAX_ASSETS:
		return "Asset index has an invalid asset list."
	var ids := {}
	var identities := {}
	for value: Variant in assets:
		if not value is Dictionary:
			return "Asset index contains a non-object entry."
		var asset: Dictionary = value
		var asset_id := str(asset.get("asset_id", ""))
		var asset_type := str(asset.get("asset_type", ""))
		var species := str(asset.get("species_id", ""))
		var form := str(asset.get("form_id", ""))
		if not valid_asset_id(asset_id) or ids.has(asset_id):
			return "Asset index contains an invalid or duplicate asset ID."
		if asset_type not in SUPPORTED_TYPES or not _token(species) or not _token(form):
			return "Asset index contains invalid identity metadata."
		if asset_id != "%s:%s:%s" % [asset_type, species, form]:
			return "Asset ID and species/form identity differ."
		var version: Variant = asset.get("version")
		var bytes: Variant = asset.get("size_bytes")
		if not (version is int or version is float) or not is_finite(float(version)) or version != floor(float(version)) or version < 1:
			return "Asset version must be a positive integer."
		if not (bytes is int or bytes is float) or not is_finite(float(bytes)) or bytes != floor(float(bytes)) or bytes < 1 or bytes > MAX_ARCHIVE_BYTES:
			return "Asset archive size is invalid."
		if not _hex(str(asset.get("sha256", ""))) or not safe_object_key(str(asset.get("object_key", ""))):
			return "Asset archive identity is invalid."
		var appearances: Variant = asset.get("appearances")
		if not appearances is Array or appearances.is_empty() or appearances.size() > 8:
			return "Pokémon bundle has an invalid appearance list."
		var variants := {}
		for appearance_value: Variant in appearances:
			if not appearance_value is Dictionary:
				return "Pokémon bundle contains an invalid appearance."
			var appearance: Dictionary = appearance_value
			var variant := str(appearance.get("variant", ""))
			var identity := str(appearance.get("runtime_identity", ""))
			if variant not in ["normal", "shiny"] or variants.has(variant):
				return "Pokémon bundle contains an invalid or duplicate variant."
			if not _token(identity.trim_suffix("@shiny")) or (variant == "shiny") != identity.ends_with("@shiny"):
				return "Pokémon appearance has an invalid runtime identity."
			if identities.has(identity):
				return "Runtime identity is provided by multiple bundles."
			if not _hex(str(appearance.get("runtime_sha256", ""))):
				return "Pokémon appearance has no valid SHA-256."
			variants[variant] = true
			identities[identity] = asset_id
		var dependencies: Variant = asset.get("dependencies", [])
		if not dependencies is Array:
			return "Asset dependencies must be an array."
		var dependency_seen := {}
		for dependency: Variant in dependencies:
			if not dependency is String or not valid_asset_id(dependency) or dependency == asset_id or dependency_seen.has(dependency):
				return "Asset dependency is invalid."
			dependency_seen[dependency] = true
		ids[asset_id] = asset
	for asset_id: String in ids:
		for dependency: String in ids[asset_id].get("dependencies", []):
			if not ids.has(dependency):
				return "Asset dependency is absent from the index."
	if _has_dependency_cycle(ids):
		return "Asset dependencies contain a cycle."
	return ""


static func _has_dependency_cycle(assets: Dictionary) -> bool:
	var visiting := {}
	var visited := {}
	for asset_id: String in assets:
		if _visit(asset_id, assets, visiting, visited):
			return true
	return false


static func _visit(asset_id: String, assets: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(asset_id):
		return true
	if visited.has(asset_id):
		return false
	visiting[asset_id] = true
	for dependency: String in assets[asset_id].get("dependencies", []):
		if _visit(dependency, assets, visiting, visited):
			return true
	visiting.erase(asset_id)
	visited[asset_id] = true
	return false


static func by_id(index: Dictionary) -> Dictionary:
	var result := {}
	if not validate(index).is_empty():
		return result
	for asset: Dictionary in index.assets:
		result[asset.asset_id] = asset
	return result


static func plan(index: Dictionary, installed_state: Dictionary, requested_ids: Array[String]) -> Dictionary:
	var error := validate(index)
	if not error.is_empty():
		return {"error": error, "downloads": [], "unchanged": [], "missing": []}
	var remote := by_id(index)
	var installed: Dictionary = installed_state.get("assets", {}) if installed_state.get("assets", {}) is Dictionary else {}
	var downloads: Array[String] = []
	var unchanged: Array[String] = []
	var missing: Array[String] = []
	var requested := requested_ids.duplicate()
	requested.sort()
	var wanted: Array[String] = []
	for asset_id: String in requested:
		if not remote.has(asset_id):
			missing.append(asset_id)
			continue
		_append_dependencies(asset_id, remote, wanted)
	for asset_id: String in wanted:
		var desired: Dictionary = remote[asset_id]
		var local: Dictionary = installed.get(asset_id, {})
		if local.get("version") == desired.version and local.get("archive_sha256") == desired.sha256:
			unchanged.append(asset_id)
		else:
			downloads.append(asset_id)
	return {"error": "", "downloads": downloads, "unchanged": unchanged, "missing": missing}


static func _append_dependencies(asset_id: String, assets: Dictionary, ordered: Array[String]) -> void:
	if asset_id in ordered:
		return
	for dependency: String in assets[asset_id].get("dependencies", []):
		_append_dependencies(dependency, assets, ordered)
	ordered.append(asset_id)
