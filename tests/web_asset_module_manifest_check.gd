extends SceneTree
const LOADER := preload("res://scripts/services/web_asset_module_service.gd")


func _init() -> void:
	var failures := 0
	var valid := {"file": "maps.pck", "sha256": "a".repeat(64), "version": "v1"}
	var cases: Array = [null, [], {}, {"modules": []}, {"modules": {LOADER.MISTY_MODULE_NAME: []}}]
	for case: Variant in cases:
		if LOADER.validate_module_manifest(JSON.stringify(case), LOADER.MISTY_MODULE_NAME).success:
			failures += 1
	for property: String in ["file", "sha256", "version"]:
		var invalid := valid.duplicate(true)
		invalid[property] = ""
		if LOADER.validate_module_manifest(JSON.stringify({"modules": {LOADER.MISTY_MODULE_NAME: invalid}}), LOADER.MISTY_MODULE_NAME).success:
			failures += 1
	for file: String in ["../maps.pck", "folder/maps.pck"]:
		var invalid := valid.duplicate(true)
		invalid.file = file
		if LOADER.validate_module_manifest(JSON.stringify({"modules": {LOADER.MISTY_MODULE_NAME: invalid}}), LOADER.MISTY_MODULE_NAME).success:
			failures += 1
	if not LOADER.validate_module_manifest(JSON.stringify({"modules": {LOADER.MISTY_MODULE_NAME: valid}}), LOADER.MISTY_MODULE_NAME).success:
		failures += 1
	if LOADER.module_for_scene("res://scenes/overworld/kanto/routes/kanto_route_5.tscn") != "":
		failures += 1
	if LOADER.module_for_scene("res://scenes/overworld/kanto/towns/cerulean_city/cerulean_city.tscn") != LOADER.MISTY_MODULE_NAME:
		failures += 1
	var catalog := JSON.parse_string(FileAccess.get_file_as_string("res://generated/world_access_catalog.json")) as Dictionary
	for map_id: String in LOADER.MISTY_MAP_SCENES:
		if str(catalog.areas[map_id].scenePath) != LOADER.MISTY_MAP_SCENES[map_id]:
			failures += 1
	print("web_asset_module_manifest_check: ", "PASS" if failures == 0 else "FAIL")
	quit(failures)
