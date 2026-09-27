extends SceneTree

const Importer := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")
const Parser := preload("res://addons/tiled_tmx_importer/importer/tmx_xml_parser.gd")
const Validator := preload("res://addons/tiled_tmx_importer/importer/tmx_atlas_layout_validator.gd")
var failed := false
var scratch: String

func _init() -> void:
	scratch = "user://tmx_animation_check_%d" % OS.get_process_id()
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	# Crossing the 4096px materialization boundary proves that animation frames
	# resolve by global tile ID, not by a source chunk's local coordinates.
	var pixels := Image.create_empty(64, 4160, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.RED)
	pixels.fill_rect(Rect2i(32, 0, 32, 32), Color.GREEN)
	pixels.fill_rect(Rect2i(0, 4096, 32, 32), Color.BLUE)
	pixels.save_png(scratch.path_join("frames.png"))
	var tsx := '<tileset name="test" tilewidth="32" tileheight="32" columns="2" tilecount="260"><image source="frames.png" width="64" height="4160"/><tile id="0"><animation><frame tileid="1" duration="100"/><frame tileid="256" duration="240"/><frame tileid="1" duration="160"/></animation></tile></tileset>'
	_write(scratch.path_join("frames.tsx"), tsx)
	var tmx := '<map orientation="orthogonal" renderorder="right-down" width="3" height="1" tilewidth="32" tileheight="32"><tileset firstgid="1" source="frames.tsx"/><layer name="Ground" width="3" height="1"><data encoding="csv">1,2147483649,257</data></layer></map>'
	_write(scratch.path_join("map.tmx"), tmx)
	var parsed := Parser.new().parse_tsx(scratch.path_join("frames.tsx"))
	_check(parsed.tileset.tile_animations[0].size() == 3, "External TSX frame list parsed")
	var output := scratch.path_join("test.tscn")
	# Absolute input exercises the real artist-file materialization path.
	var result := Importer.new().import_tmx(ProjectSettings.globalize_path(scratch.path_join("map.tmx")), output)
	_check(result.get("success", false), "Cross-chunk animation imports: " + str(result.get("error", "")))
	if result.get("success", false):
		var scene := ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var node := scene.instantiate()
		_check(Validator.new().validate(node, result.tileset_path).is_empty(), "Animation passes compact layout validation after reload")
		var layer := node.get_child(0) as TileMapLayer
		var source := layer.tile_set.get_source(layer.get_cell_source_id(Vector2i.ZERO)) as TileSetAtlasSource
		var coords := layer.get_cell_atlas_coords(Vector2i.ZERO)
		_check(source.get_tile_animation_frames_count(coords) == 3, "Frame count persists")
		var frame_pixels := source.texture.get_image()
		frame_pixels.convert(Image.FORMAT_RGBA8)
		for n in 3:
			var expected := pixels.get_region(Rect2i(0, 4096, 32, 32) if n == 1 else Rect2i(32, 0, 32, 32))
			_check(frame_pixels.get_region(source.get_tile_texture_region(coords, n)).get_data() == expected.get_data(), "Every frame preserved pixel-exact, including repeated/nonconsecutive frames")
			_check(is_equal_approx(source.get_tile_animation_frame_duration(coords, n), [0.1, 0.24, 0.16][n]), "Unequal frame duration persists")
		_check(layer.get_cell_alternative_tile(Vector2i(1,0)) == 4096, "Animation preserves Tiled flip")
		var still := layer.tile_set.get_source(layer.get_cell_source_id(Vector2i(2,0))) as TileSetAtlasSource
		_check(still.get_tile_animation_frames_count(layer.get_cell_atlas_coords(Vector2i(2,0))) == 1, "Frame painted independently remains static")
		node.free()
		var scene_hash := FileAccess.get_sha256(output)
		var texture_hashes := {}
		for name in DirAccess.get_files_at(scratch.path_join("assets")):
			texture_hashes[name] = FileAccess.get_sha256(scratch.path_join("assets").path_join(name))
		for invalid in [tsx.replace('tileid="256"', 'tileid="99999"'), tsx.replace('duration="240"', 'duration="0"'), tsx.replace('<frame tileid="1" duration="100"/><frame tileid="256" duration="240"/><frame tileid="1" duration="160"/>', '')]:
			_write(scratch.path_join("frames.tsx"), invalid)
			var rejected := Importer.new().import_tmx(ProjectSettings.globalize_path(scratch.path_join("map.tmx")), output)
			_check(not rejected.get("success", true), "Invalid/empty animation rejected")
			_check(FileAccess.get_sha256(output) == scene_hash, "Failed animation import preserves saved scene")
			for name in texture_hashes:
				_check(FileAccess.get_sha256(scratch.path_join("assets").path_join(name)) == texture_hashes[name], "Failed animation import preserves texture bytes")
	var inline := Importer.new().import_tmx("res://tests/fixtures/tiled/used_animation.tmx", scratch.path_join("inline.tscn"))
	_check(inline.get("success", false), "Inline TMX animation imports")
	_cleanup(scratch)
	print("TMX_ANIMATION_CHECK ", JSON.stringify({"success": not failed}))
	quit(1 if failed else 0)

func _write(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failed = true
		push_error(message)

func _cleanup(path: String) -> void:
	assert(path == scratch or path.begins_with(scratch + "/"))
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	for name in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
