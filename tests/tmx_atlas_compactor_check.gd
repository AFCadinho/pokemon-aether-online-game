extends SceneTree

const Compactor := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_compactor.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
const Importer := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")
const Wrapper := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tmx_visual_importer.gd")
var failed := false
var scratch: String
var generated: String

func _init() -> void:
	scratch = "user://tmx_atlas_compactor_check_%d" % OS.get_process_id()
	generated = "res://generated/tiled_visuals/block4_fixture_%d" % OS.get_process_id()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(scratch)) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(generated)):
		push_error("Refusing to overwrite a pre-existing test directory.")
		quit(1)
		return
	_run.call_deferred()

func _run() -> void:
	_check_small_and_split()
	_check_import_and_failure()
	_cleanup(scratch)
	_cleanup(generated)
	print("TMX_ATLAS_COMPACTOR_CHECK ", JSON.stringify({"success": not failed}))
	quit(1 if failed else 0)

func _scene(dense: bool) -> Node2D:
	var root := Node2D.new()
	var tiles := TileSet.new()
	tiles.tile_size = Vector2i(32, 32)
	tiles.add_custom_data_layer()
	tiles.set_custom_data_layer_name(0, "semantic")
	tiles.set_custom_data_layer_type(0, TYPE_INT)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 8)
	var image := Image.create_empty(256, 4096 if dense else 384, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.4, 0.6, 0.8))
	var source := TileSetAtlasSource.new()
	source.texture_region_size = Vector2i(32, 32)
	source.texture = ImageTexture.create_from_image(image)
	tiles.add_source(source, 1)
	for n in 1024 if dense else 96:
		source.create_tile(Vector2i(n % 8, n / 8))
	var data := source.get_tile_data(Vector2i.ZERO, 0)
	data.texture_origin = Vector2i(3, -4)
	data.y_sort_origin = 7
	data.set_custom_data("semantic", 42)
	data.set_collision_polygons_count(0, 1)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8)]))
	source.create_alternative_tile(Vector2i.ZERO, 11)
	source.get_tile_data(Vector2i.ZERO, 11).modulate = Color(0.5, 0.7, 0.9, 1)
	# Reserved but unused source ID tests that split IDs cannot collide.
	var unused := TileSetAtlasSource.new()
	unused.texture = source.texture
	tiles.add_source(unused, 50)
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = tiles
	layer.position = Vector2(16, 32)
	layer.modulate.a = 0.75
	root.add_child(layer)
	layer.owner = root
	if dense:
		for n in 1024:
			layer.set_cell(Vector2i(n % 32, n / 32), 1, Vector2i(n % 8, n / 8))
	else:
		layer.set_cell(Vector2i.ZERO, 1, Vector2i.ZERO, 11 | 4096 | 8192 | 16384)
		layer.set_cell(Vector2i(1, 0), 1, Vector2i(2, 0))
		layer.set_cell(Vector2i(2, 0), 1, Vector2i(7, 11))
	return root

func _check_small_and_split() -> void:
	for dense in [false, true]:
		var root := _scene(dense)
		var layer := root.get_node("Ground") as TileMapLayer
		var original := layer.tile_set
		var before := original.get_source(1) as TileSetAtlasSource
		var pixels := before.texture.get_image()
		pixels.convert(Image.FORMAT_RGBA8)
		var records := {}
		for cell in layer.get_used_cells():
			records[cell] = {"coords": layer.get_cell_atlas_coords(cell), "alt": layer.get_cell_alternative_tile(cell)}
		var path := scratch.path_join("dense.visual.tileset.tres" if dense else "small.visual.tileset.tres")
		var result := Compactor.new().compact(root, path)
		_check(bool(result.get("success", false)), "Compaction succeeds: " + str(result.get("error", "")))
		if not result.get("success", false):
			root.free()
			continue
		_check(original.get_source_count() == 2 and before.get_tiles_count() == (1024 if dense else 96), "Original TileSet is not mutated")
		_check(layer.tile_set.get_source_count() == (2 if dense else 1), "Unused source removed / large source split")
		var errors := Validator.new().validate(root, path)
		_check(errors.is_empty(), "Compact layout validates: " + str(errors))
		var decoded := {}
		for cell in records:
			var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
			var id := layer.get_cell_source_id(cell)
			if not decoded.has(id):
				decoded[id] = source.texture.get_image()
				decoded[id].convert(Image.FORMAT_RGBA8)
			_check(pixels.get_region(before.get_tile_texture_region(records[cell].coords)).get_data() == decoded[id].get_region(source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))).get_data(), "Exact tile pixels preserved")
			_check(layer.get_cell_alternative_tile(cell) == records[cell].alt, "Alternatives and all transform flags preserved")
		var after := layer.tile_set.get_source(layer.get_cell_source_id(Vector2i.ZERO)) as TileSetAtlasSource
		var coords := layer.get_cell_atlas_coords(Vector2i.ZERO)
		var data := after.get_tile_data(coords, 0)
		_check(data.texture_origin == Vector2i(3,-4) and data.y_sort_origin == 7, "Depth/texture origins preserved")
		_check(data.get_custom_data("semantic") == 42 and data.get_collision_polygons_count(0) == 1, "Custom and physics TileData preserved")
		_check(data.get_collision_polygon_points(0, 0) == before.get_tile_data(Vector2i.ZERO, 0).get_collision_polygon_points(0, 0), "Exact physics polygon points preserved")
		_check(layer.tile_set.get_physics_layer_collision_layer(0) == 8, "TileSet layer settings preserved")
		_check(after.get_tile_data(coords, 11).modulate == Color(0.5,0.7,0.9,1), "Alternative TileData preserved")
		_check(layer.position == Vector2(16,32) and layer.modulate.a == 0.75, "Layer settings unchanged")
		if not dense:
			var saved_texture := after.texture
			after.texture = ImageTexture.create_from_image(saved_texture.get_image())
			_check(not Validator.new().validate(root, path).is_empty(), "Validator rejects raw texture storage")
			after.texture = saved_texture
			after.remove_tile(layer.get_cell_atlas_coords(Vector2i(2,0)))
			_check(not Validator.new().validate(root, path).is_empty(), "Validator rejects missing tile definitions")
		root.free()

func _check_import_and_failure() -> void:
	var output := scratch.path_join("first.visual.tscn")
	var importer := Importer.new()
	var fixture := "res://tests/fixtures/tiled/visual_only_regular.tmx"
	var first := importer.import_tmx("res://tests/fixtures/tiled/visual_multi_source.tmx", output)
	_check(first.get("success", false), "Real fixture import succeeds: " + str(first.get("error", "")))
	var second := importer.import_tmx(fixture, scratch.path_join("second.visual.tscn"))
	_check(second.get("success", false), "Second scene in same folder succeeds: " + str(second.get("error", "")))
	if not first.get("success", false) or not second.get("success", false):
		return
	var first_scene := ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var root := first_scene.instantiate()
	_check(Validator.new().validate(root, first.tileset_path).is_empty(), "Saved scene reload retains external compact resources")
	var old_texture_path: String = root.get_child(0).tile_set.get_source(100).texture.resource_path
	root.free()
	_check(importer.import_tmx(fixture, output).get("success", false), "Reimport succeeds without stale atlas errors")
	_check(not FileAccess.file_exists(old_texture_path), "Reimport removes only its superseded compact chunks")
	var wrapped := Wrapper.new().import_tmx(fixture, generated.get_file())
	_check(wrapped.get("success", false), "PokeAether wrapper automatically compacts")
	var previous_hash := FileAccess.get_sha256(wrapped.visual_scene_path)
	var assets := DirAccess.get_files_at(generated.path_join("assets"))
	var asset_hashes := {}
	for name in assets:
		asset_hashes[name] = FileAccess.get_sha256(generated.path_join("assets").path_join(name))
	var rejected := Wrapper.new().import_tmx("res://tests/fixtures/tiled/used_animation.tmx", generated.get_file())
	_check(not rejected.get("success", true) and str(rejected.get("error", "")).contains("animation"), "Used inline TMX animation is explicitly rejected")
	_check(FileAccess.get_sha256(wrapped.visual_scene_path) == previous_hash and DirAccess.get_files_at(generated.path_join("assets")) == assets, "Rejected import preserves prior scene and assets")
	for name in assets:
		_check(FileAccess.get_sha256(generated.path_join("assets").path_join(name)) == asset_hashes[name], "Rejected import preserves texture bytes")
	var tsx := preload("res://addons/tiled_tmx_importer/importer/tmx_xml_parser.gd").new().parse_tsx("res://tests/fixtures/tiled/used_animation.tsx")
	_check(tsx.tileset.animated_tile_ids == [0], "External TSX animations are detected")
	# Exercise the actual CI entry point on a new, non-baselined saved visual.
	var args := PackedStringArray(["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", "res://tests/generated_map_atlas_layout_check.gd"])
	var logs: Array = []
	_check(OS.execute(OS.get_executable_path(), args, logs, true) == 0, "Actual CI layout entry point accepts new compact output")
	var tile_set := ResourceLoader.load(wrapped.tileset_path, "TileSet", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as TileSet
	tile_set.set_meta("tiled_compact_atlas_version", 0)
	_check(ResourceSaver.save(tile_set, wrapped.tileset_path) == OK, "Synthetic regression fixture saves")
	logs.clear()
	_check(OS.execute(OS.get_executable_path(), args, logs, true) != 0, "Actual CI entry point rejects a new unmarked atlas")
	_check(str(logs).contains("Missing compact atlas version"), "CI failure reports the deliberate layout regression")

func _check(ok: bool, label: String) -> void:
	if not ok:
		failed = true
		push_error(label)

func _cleanup(path: String) -> void:
	assert(path == scratch or path.begins_with(scratch + "/") or path == generated or path.begins_with(generated + "/"))
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	for name in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
