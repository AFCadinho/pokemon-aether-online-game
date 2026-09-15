extends SceneTree

const ROOT := "res://generated/tiled_visuals"
const BASELINE := "res://tests/fixtures/tiled/legacy_atlas_layout_baseline.json"
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failures: Array[String] = []
var checked := 0
var legacy := 0

func _init() -> void:
	var baseline = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
	if not baseline is Dictionary or baseline.get("schemaVersion") != 1 or not baseline.get("legacyTileSets") is Dictionary or not baseline.get("legacyScenes") is Dictionary:
		push_error("Invalid explicit legacy atlas baseline.")
		quit(1)
		return
	_scan(ROOT, baseline.legacyTileSets, baseline.legacyScenes)
	if checked + legacy == 0:
		failures.append("No generated atlas TileSets found.")
	for failure in failures:
		push_error(failure)
	print("GENERATED_ATLAS_LAYOUT ", JSON.stringify({"compact": checked, "unchangedLegacy": legacy, "success": failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)

func _scan(directory: String, baseline: Dictionary, scene_baseline: Dictionary) -> void:
	for name in DirAccess.get_files_at(directory):
		if not name.ends_with(".tileset.tres"):
			continue
		var path := directory.path_join(name)
		var scene_path := path.trim_suffix(".tileset.tres") + ".tscn"
		# Existing maps are explicit immutable migration exceptions, not a blanket
		# opt-out. New or edited unmarked files must pass the compact contract.
		if baseline.get(path, "") == FileAccess.get_sha256(path) and scene_baseline.get(scene_path, "") == FileAccess.get_sha256(scene_path):
			legacy += 1
			continue
		checked += 1
		var scene := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if scene == null:
			failures.append("Missing visual scene: " + scene_path)
			continue
		var root := scene.instantiate()
		for error in Validator.new().validate(root, path):
			failures.append(path + ": " + error)
		root.free()
	for child in DirAccess.get_directories_at(directory):
		_scan(directory.path_join(child), baseline, scene_baseline)
