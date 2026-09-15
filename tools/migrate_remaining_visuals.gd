extends SceneTree

const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const BASELINE := "res://tests/fixtures/tiled/legacy_atlas_layout_baseline.json"
const EXPECTED := "res://tests/fixtures/tiled/migrated_visual_fingerprints.json"
const BATCHES := [
	["rivals_house", "pewter_house", "pokemon_center", "pokemon_school", "viridian_house_template", "cerulean_house_template_blue", "cerulean_bike_shop", "bills_house"],
	["transition_building_horizontal", "transition_building_vertical", "pewter_gym", "cerulean_gym"],
	["route_1", "kanto_route_2", "kanto_route_22", "route_3", "route_4", "route_24", "route_25"],
	["viridian_city", "pewter_city", "cerulean_city", "viridian_forest"],
	["mt_moon_1f", "mt_moon_b1f", "mt_moon_b2f"],
	["lobby", "waiting_area", "open_field", "aether_clash_duel", "aether_clash_battle_royale"],
	["pallet_town", "pallet_town_compact"],
]
var scratch := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or args[0] not in ["--check", "--migrate", "--render-check"] or not args[1].is_valid_int() or int(args[1]) not in range(BATCHES.size()):
		push_error("Usage: --check|--migrate|--render-check BATCH (0..6). Fixed explicit scope only.")
		quit(2)
		return
	if args[0] == "--render-check" and DisplayServer.get_name() == "headless":
		push_error("Render comparison requires a non-headless display.")
		quit(2)
		return
	scratch = "user://remaining_visuals_%d" % OS.get_process_id()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(scratch)):
		quit(1)
		return
	var results := {}
	var valid := true
	for id in BATCHES[int(args[1])]:
		var scene := ResourceLoader.load(_path(id), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		if scene == null:
			valid = false
			break
		var root := scene.instantiate()
		var before := Fingerprint.new().capture(root)
		var old_paths := _textures(root)
		var temp := scratch.path_join(id + "/" + id + ".visual.tscn")
		var saved := _save(root, temp)
		root.free()
		if not saved.get("success", false):
			push_error(id + ": " + str(saved))
			valid = false
			break
		var packed := ResourceLoader.load(temp, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var after_root := packed.instantiate()
		var after := Fingerprint.new().capture(after_root)
		var errors := Validator.new().validate(after_root, temp.trim_suffix(".tscn") + ".tileset.tres")
		var rendered := true
		if args[0] == "--render-check":
			rendered = await _render(scene.instantiate(), packed.instantiate())
		after_root.free()
		var matches: bool = before.fingerprint == after.fingerprint and errors.is_empty() and rendered
		results[id] = {"before": before, "after": after, "matches": matches, "old_paths": old_paths}
		print("VISUAL_COMPARISON ", JSON.stringify({"id": id, "before": before, "after": after, "matches": matches}))
		valid = valid and matches
	# All maps in this bounded batch pass before any canonical resource changes.
	if valid and args[0] == "--migrate":
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECTED)) if FileAccess.file_exists(EXPECTED) else {}
		var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BASELINE))
		for id in results:
			var packed := ResourceLoader.load(_path(id), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
			var root := packed.instantiate()
			var result := _save(root, _path(id))
			root.free()
			if not result.get("success", false):
				valid = false
				break
			var saved := ResourceLoader.load(_path(id), "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
			var check := saved.instantiate()
			var fingerprint := Fingerprint.new().capture(check)
			var errors := Validator.new().validate(check, _path(id).trim_suffix(".tscn") + ".tileset.tres")
			check.free()
			if fingerprint != results[id].after or not errors.is_empty():
				valid = false
				break
			expected[id] = fingerprint
			baseline.legacyScenes.erase(_path(id))
			baseline.legacyTileSets.erase(_path(id).trim_suffix(".tscn") + ".tileset.tres")
		if valid:
			_write_json(EXPECTED, expected)
			_write_json(BASELINE, baseline)
			# No recursive asset deletion: only exact previously referenced generated
			# texture files, and only after a tracked textual-reference audit.
			for id in results:
				for path in results[id].old_paths:
					if path.begins_with(_path(id).get_base_dir() + "/assets/") and path.ends_with(".texture.res") and not _referenced(path):
						if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) != OK:
							push_error("Could not remove superseded generated file: " + path)
							valid = false
	_cleanup(scratch)
	print("REMAINING_VISUALS ", JSON.stringify({"batch": int(args[1]), "maps": results.size(), "success": valid, "migrated": valid and args[0] == "--migrate"}))
	quit(0 if valid else 1)

func _path(id: String) -> String:
	return "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]

func _save(root: Node, path: String) -> Dictionary:
	var result := Compactor.new().compact(root, path.trim_suffix(".tscn") + ".tileset.tres")
	if not result.get("success", false):
		return result
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, path)
	return {"success": error == OK, "error": error_string(error)}

func _textures(root: Node) -> Array[String]:
	var layers: Array[TileMapLayer] = []
	Compactor.new()._collect(root, layers)
	var paths: Array[String] = []
	for layer in layers:
		for index in layer.tile_set.get_source_count():
			var texture: Texture2D = layer.tile_set.get_source(layer.tile_set.get_source_id(index)).texture
			if texture.resource_path not in paths:
				paths.append(texture.resource_path)
	return paths

func _referenced(path: String) -> bool:
	var output: Array = []
	if OS.execute("git", ["ls-files", "--", "*.tscn", "*.tres", "*.gd", "*.json", "*.cfg"], output) != 0:
		return true
	for name in str(output[0]).split("\n", false):
		if FileAccess.get_file_as_string("res://" + name).contains(path):
			return true
	return false

func _write_json(path: String, value: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify(value, "  ", true) + "\n")

func _render(old: Node, compact: Node) -> bool:
	var dimensions: Dictionary = old.get_meta("tiled_visual_map")
	var size := Vector2i(int(dimensions.width) * int(dimensions.tile_width), int(dimensions.height) * int(dimensions.tile_height))
	var viewports: Array[SubViewport] = []
	for visual in [old, compact]:
		var viewport := SubViewport.new()
		viewport.size = size
		viewport.transparent_bg = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		get_root().add_child(viewport)
		viewport.add_child(visual)
		viewports.append(viewport)
	for frame in 8:
		await process_frame
	await RenderingServer.frame_post_draw
	var a := viewports[0].get_texture().get_image()
	var b := viewports[1].get_texture().get_image()
	var valid := a != null and b != null and a.get_size() == size and a.get_data() == b.get_data() and not a.is_invisible()
	print("VISUAL_RENDER ", JSON.stringify({"size": [size.x, size.y], "identicalPixels": valid, "display": DisplayServer.get_name()}))
	for viewport in viewports:
		viewport.free()
	return valid

func _cleanup(path: String) -> void:
	assert(scratch != "" and (path == scratch or path.begins_with(scratch + "/")))
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	for name in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
