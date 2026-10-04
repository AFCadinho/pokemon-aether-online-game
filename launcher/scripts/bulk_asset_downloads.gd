extends RefCounted
## Plans optional complete downloads against the manifest selected by the launcher.
const SPRITE_PACK_IDS: Array[String] = [
	"pokemon-home", "pokemon-home-shiny", "pokemon-front", "pokemon-back",
	"pokemon-shiny-front", "pokemon-shiny-back", "pokemon-gen5-front",
	"pokemon-gen5-back", "pokemon-gen5-shiny-front", "pokemon-gen5-shiny-back",
]

static func bytes_in(jobs: Array) -> int:
	var total := 0
	for job: Dictionary in jobs:
		total += int(job.get("size_bytes", 0))
	return total

static func game_catalog_path() -> String:
	return OS.get_user_data_dir().get_base_dir().path_join("PokeAether/on-demand-3d-v1/runtime-catalog.json")

static func models_plan(service: RefCounted, descriptor: Dictionary, game_catalog := "") -> Dictionary:
	var plan: Dictionary = service.jobs(descriptor, true)
	if not str(plan.get("error", "")).is_empty():
		return plan
	var index: Dictionary = service.cached_index(descriptor)
	if index.is_empty():
		return {"error": "Update the game first to load the download catalog.", "jobs": []}
	var by_id := {}
	for asset: Dictionary in index.assets:
		by_id[asset.asset_id] = asset
	var installed := {}
	if not game_catalog.is_empty() and FileAccess.file_exists(game_catalog):
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(game_catalog))
		if raw is Array:
			for entry: Variant in raw:
				if entry is Dictionary:
					var identity := str(entry.get("species", "")).trim_suffix("@shiny")
					if entry.get("variant", "normal") == "shiny" or str(entry.get("species", "")).ends_with("@shiny"):
						identity += "@shiny"
					installed[identity] = entry
	var jobs: Array[Dictionary] = []
	for job: Dictionary in plan.get("jobs", []):
		if not _available(by_id.get(job.id, {}), installed):
			jobs.append(job)
	return {"error": "", "jobs": jobs, "total_bytes": bytes_in(jobs),
		"available": index.assets.size() - jobs.size(), "count": index.assets.size()}

static func _available(asset: Dictionary, entries: Dictionary) -> bool:
	if asset.get("appearances", []).is_empty():
		return false
	for appearance: Dictionary in asset.appearances:
		var entry: Dictionary = entries.get(str(appearance.runtime_identity), {})
		var path := str(entry.get("runtime_path", ""))
		if entry.get("runtime_schema") != 1 or int(entry.get("bytes", 0)) <= 0 or entry.get("runtime_sha256") != appearance.runtime_sha256 or not path.is_absolute_path() or not path.ends_with(".scn") or not FileAccess.file_exists(path):
			return false
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null or file.get_length() != int(entry.bytes):
			return false
		if FileAccess.get_sha256(path) != appearance.runtime_sha256:
			return false
	return true

static func sprites_plan(launcher: Node) -> Dictionary:
	var jobs: Array[Dictionary] = []
	var count := 0
	var versions: Dictionary = launcher.local_versions.get("assetPacks", {})
	for pack: Variant in launcher.manifest.get("assetPacks", []):
		if not pack is Dictionary or str(pack.get("id", "")) not in SPRITE_PACK_IDS:
			continue
		count += 1
		if launcher._is_asset_pack_installed(pack, versions):
			continue
		jobs.append({"type": "asset_pack", "id": pack.id, "version": pack.version,
			"url": pack.url, "sha256": pack.sha256, "size_bytes": int(pack.sizeBytes),
			"file_name": "%s-%s.zip" % [pack.id, pack.version], "label": pack.get("label", pack.id)})
	return {"error": "" if count > 0 else "No sprite packs are available in this release.",
		"jobs": jobs, "count": count, "available": count - jobs.size(), "total_bytes": bytes_in(jobs)}
