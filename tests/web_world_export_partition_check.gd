extends SceneTree

var failed := false


func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json"))
	var scope: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/browser-full-world-scope.json"))
	var misty: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/browser-misty-scope.json"))
	var covered: Array = scope.coreMapIds + scope.extendedMapIds + misty.additionalMapIds
	for map_id: String in catalog.areas:
		var area: Dictionary = catalog.areas[map_id]
		if map_id.begins_with("kanto_") and not str(area.get("scenePath", "")).is_empty():
			_check(covered.has(map_id), "every playable Kanto map is assigned to a browser export: " + map_id)

	var config := ConfigFile.new()
	_check(config.load("res://export_presets.cfg") == OK, "browser export presets load")
	var presets := {}
	for section: String in config.get_sections():
		if not section.ends_with(".options"):
			presets[str(config.get_value(section, "name", ""))] = section
	var excluded := str(config.get_value(presets["Web Local Preview"], "exclude_filter", "")).split(",")
	for module in [["Web Extended Kanto Maps", scope.extendedMapIds], ["Web Misty Maps Trial", misty.additionalMapIds]]:
		var files: PackedStringArray = config.get_value(presets[module[0]], "export_files", PackedStringArray())
		for map_id: String in module[1]:
			var path := str((catalog.areas.get(map_id, {}) as Dictionary).get("scenePath", ""))
			_check(not path.is_empty() and files.has(path), "on-demand browser pack includes its map: " + map_id)
			var excluded_from_core := false
			for pattern: String in excluded:
				excluded_from_core = excluded_from_core or path.trim_prefix("res://").match(pattern)
			_check(excluded_from_core, "on-demand browser map stays outside the initial core export: " + map_id)
	if not failed:
		print("PASS Browser world export partition covers all playable Kanto maps")
	quit(1 if failed else 0)


func _check(condition: bool, label: String) -> void:
	if not condition:
		failed = true
		push_error(label)
