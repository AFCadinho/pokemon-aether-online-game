extends RefCounted
## Explicit desktop-debug preview admission, never battle/pack approval.
const EVIDENCE = preload("res://tools/sprite_factory/catalog_production_batch_01_results.json")

static func catalog_path() -> String:
	var override := OS.get_environment("POKEAETHER_PREVIEW_REVIEW_CATALOG")
	if not override.is_empty():
		return override
	var relative := "3d_models/PokeAether/catalog-production-01-review/catalog.json"
	var documents := OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS).path_join(relative)
	if FileAccess.file_exists(documents):
		return documents
	# Isolated slot XDG config may not define user-dirs.dirs. Check only the
	# explicit conventional Documents location, never scan other directories.
	return OS.get_environment("HOME").path_join("Documents").path_join(relative)

static func resolve(identity: String) -> Dictionary:
	if not OS.is_debug_build() or OS.has_feature("web") or OS.has_feature("mobile") or "@" in identity:
		return {}
	var expected := ""
	for row: Dictionary in EVIDENCE.data.entries:
		if row.species == identity and row.get("export_status") == "exported_for_review" and row.get("visual_review") == "pending" and row.get("runtime_approved") == false:
			expected = str(row.get("runtime_sha256", ""))
	if expected.length() != 64:
		return {}
	var path := catalog_path()
	if not path.is_absolute_path() or not FileAccess.file_exists(path):
		return {}
	var entries: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not entries is Array:
		return {}
	var matches := []
	for entry: Variant in entries:
		if entry is Dictionary and entry.get("species") == identity:
			matches.append(entry)
	if matches.size() != 1:
		return {}
	var entry: Dictionary = matches[0]
	var model_path := str(entry.get("runtime_path", ""))
	if entry.get("variant") != "normal" or entry.get("runtime_schema") != 1 or entry.get("runtime_sha256") != expected:
		return {}
	if not model_path.is_absolute_path() or not model_path.ends_with(".scn") or not FileAccess.file_exists(model_path):
		return {}
	if FileAccess.get_sha256(model_path) != expected:
		return {}
	return {"path": model_path, "profile": {"placement": {"scale": 1.0}, "review_candidate": true}}
