extends SceneTree

func _init() -> void:
	var parser := preload("res://addons/tiled_tmx_importer/importer/tmx_xml_parser.gd").new()
	var path := "res://tests/fixtures/tiled/missing_tileset.tmx"
	var selected := "res://tests/fixtures/tiled/visual_only_tileset.tsx"
	assert(parser.parse_tmx(path).map.tilesets[0].has("external_error"))
	assert(parser.parse_tmx(path, {"missing.tsx": "res://does-not-exist.tsx"}).map.tilesets[0].has("external_error"))
	var repaired: Dictionary = parser.parse_tmx(path, {"missing.tsx": selected})
	assert(repaired.get("success", false))
	assert(repaired.map.tilesets[0].source_path == selected)
	assert(repaired.map.tilesets[0].image.path == ProjectSettings.globalize_path("res://assets/tilesets/fiver/tiles_env2_floors32.png"))
	assert(not parser.parse_tmx("res://tests/fixtures/tiled/visual_only_regular.tmx", {"visual_only_tileset.tsx": "res://does-not-exist.tsx"}).map.tilesets[0].has("external_error"))
	var scratch := "user://missing_dependency_cli_%d" % OS.get_process_id()
	assert(not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(scratch)))
	var output: Array = []
	var code := OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://addons/tiled_tmx_importer/import_tmx_cli.gd", "--", path, scratch.path_join("test.visual.tscn"), "res://tests/fixtures/tiled/missing_tileset_paths.json"], output, true)
	var scene := ResourceLoader.load(scratch.path_join("test.visual.tscn"), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene if code == 0 else null
	var valid := scene != null
	if scene != null:
		var node := scene.instantiate()
		valid = preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(node, scratch.path_join("test.visual.tileset.tres")).is_empty()
		node.free()
	_cleanup(scratch, scratch)
	if not valid:
		push_error("CLI explicit dependency repair failed: " + str(output))
		quit(1)
		return
	print("TMX_MISSING_DEPENDENCY_CHECK success=true (missing reported, explicit repair, image base, existing dependency preserved)")
	quit(0)

func _cleanup(path: String, scratch: String) -> void:
	assert(path == scratch or path.begins_with(scratch + "/"))
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	for name in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(name), scratch)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
