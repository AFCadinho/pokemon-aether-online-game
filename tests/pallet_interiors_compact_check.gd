extends SceneTree

func _init() -> void:
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/tiled/pallet_interiors_fingerprints.json"))
	var valid := true
	for id in expected:
		var scene_path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var scene := ResourceLoader.load(scene_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var root := scene.instantiate()
		var actual := preload("res://tests/support/visual_atlas_fingerprint.gd").new().capture(root)
		var errors := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd").new().validate(root, scene_path.trim_suffix(".tscn") + ".tileset.tres")
		for key in expected[id]:
			if actual[key] != expected[id][key]:
				errors.append("Original artwork/layout/TileData fingerprint or compact budget changed: " + key)
		for error in errors:
			push_error(id + ": " + error)
		valid = valid and errors.is_empty()
		root.free()
	print("PALLET_INTERIORS_COMPACT_CHECK ", JSON.stringify({"success": valid, "maps": expected.size()}))
	quit(0 if valid else 1)
