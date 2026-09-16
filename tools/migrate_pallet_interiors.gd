extends SceneTree

const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Fingerprint := preload("res://tests/support/visual_atlas_fingerprint.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const VISUAL_IDS := ["players_house", "pokemon_laboratory"]
var scratch := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or args[0] not in ["--check", "--migrate", "--render-check"]:
		push_error("Requires --check, --migrate or --render-check; only two Pallet interiors are in scope.")
		quit(2)
		return
	if args[0] == "--render-check" and DisplayServer.get_name() == "headless":
		push_error("Rendered comparison requires a non-headless display driver.")
		quit(2)
		return
	scratch = "user://pallet_interiors_migration_%d" % OS.get_process_id()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(scratch)):
		push_error("Refusing a pre-existing test directory.")
		quit(1)
		return
	var results := {}
	var valid := true
	for id in VISUAL_IDS:
		var canonical := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
		var packed := ResourceLoader.load(canonical, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var old := packed.instantiate()
		var before := Fingerprint.new().capture(old)
		var target := scratch.path_join(id + ".visual.tscn")
		var imported := _save_compact(old, target)
		old.free()
		if not imported.get("success", false):
			push_error(str(imported.get("error", "Import failed")))
			valid = false
			break
		var scene := ResourceLoader.load(target, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var root := scene.instantiate()
		var after := Fingerprint.new().capture(root)
		var errors := Validator.new().validate(root, imported.tileset_path)
		var rendered := true
		if args[0] == "--render-check":
			rendered = await _render_matches(packed.instantiate(), root.duplicate())
		root.free()
		var matches: bool = before.fingerprint == after.fingerprint and errors.is_empty() and rendered
		results[id] = {"before": before, "after": after, "matches": matches, "renderCompared": args[0] == "--render-check", "renderIdentical": rendered if args[0] == "--render-check" else null}
		valid = valid and matches
	# No canonical output changes until BOTH existing visual comparisons pass.
	if valid and args[0] == "--migrate":
		for id in VISUAL_IDS:
			var canonical := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [id, id]
			var packed := ResourceLoader.load(canonical, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
			var root := packed.instantiate()
			var imported := _save_compact(root, canonical)
			var after := Fingerprint.new().capture(root)
			valid = valid and after.fingerprint == results[id].before.fingerprint
			root.free()
			valid = valid and bool(imported.get("success", false))
			if not valid:
				push_error(str(imported.get("error", "Canonical import failed")))
				break
	_cleanup(scratch)
	print("PALLET_INTERIORS_MIGRATION ", JSON.stringify({"results": results, "success": valid, "migrated": valid and args[0] == "--migrate"}))
	quit(0 if valid else 1)

func _save_compact(root: Node, scene_path: String) -> Dictionary:
	var tileset_path := scene_path.trim_suffix(".tscn") + ".tileset.tres"
	var result := Compactor.new().compact(root, tileset_path)
	if not result.get("success", false):
		return result
	var scene := PackedScene.new()
	var error := scene.pack(root)
	if error == OK:
		error = ResourceSaver.save(scene, scene_path)
	return {"success": error == OK, "error": error_string(error), "tileset_path": tileset_path}

func _render_matches(old: Node, compact: Node) -> bool:
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
	var identical := a != null and b != null and a.get_size() == size and a.get_data() == b.get_data()
	var nonblank := false
	if a != null:
		for y in range(0, size.y, 16):
			for x in range(0, size.x, 16):
				if a.get_pixel(x, y).a > 0:
					nonblank = true
	print("INTERIOR_RENDER ", JSON.stringify({"size": [size.x, size.y], "identicalPixels": identical, "nonblank": nonblank, "display": DisplayServer.get_name()}))
	for viewport in viewports:
		viewport.free()
	return identical and nonblank

func _cleanup(path: String) -> void:
	assert(scratch != "" and (path == scratch or path.begins_with(scratch + "/")))
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	for name in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
