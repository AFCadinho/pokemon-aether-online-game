extends SceneTree

func _init() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tiled/migrated_visual_fingerprints.json"))
	var ids: Array = []
	for batch in preload("res://tools/migrate_remaining_visuals.gd").BATCHES:
		ids.append_array(batch)
	var valid := expected.size() == ids.size()
	for id in ids:
		valid = valid and expected.has(id)
	for id in expected:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var scene := ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if scene == null:
			valid = false
			continue
		var root := scene.instantiate()
		var actual := preload("res://tests/support/visual_atlas_fingerprint.gd").new().capture(root)
		var errors := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(root, path.trim_suffix(".tscn") + ".tileset.tres")
		var matches := true
		for key in expected[id]:
			matches = matches and actual.get(key) == expected[id][key]
		if not matches or not errors.is_empty():
			push_error("Original artwork/layout/TileData or compact budget changed: " + id + str(errors))
			valid = false
		root.free()
	print("MIGRATED_VISUALS_CHECK ", JSON.stringify({"maps": expected.size(), "success": valid}))
	quit(0 if valid else 1)
