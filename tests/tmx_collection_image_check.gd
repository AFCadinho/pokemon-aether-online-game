extends SceneTree

const Importer := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")
var failed := false
var scratch := ""

func _init() -> void:
	scratch = "user://tmx_collection_image_check_%d" % OS.get_process_id()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(scratch)):
		push_error("Refusing to overwrite a pre-existing test directory.")
		quit(1)
		return
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scratch))
	# Both TSXs refer to the same PNG, across a dense atlas chunk boundary.
	# The old collection path replaced its 32px grid with a 13x22px grid.
	var image := Image.create_empty(32, 4160, false, Image.FORMAT_RGBA8)
	for y in 4160:
		for x in 32:
			image.set_pixel(x, y, Color8(x * 7, y % 251, (y / 32) % 251, 255))
	image.save_png(ProjectSettings.globalize_path(scratch.path_join("shared.png")))
	_write("dense.tsx", '<tileset name="Dense" tilewidth="32" tileheight="32" tilecount="130" columns="1"><image source="shared.png" width="32" height="4160"/></tileset>')
	_write("crop.tsx", _crop_tsx(0, 4128))
	var header := '<map orientation="orthogonal" width="2" height="1" tilewidth="32" tileheight="32"><tileset firstgid="1" source="dense.tsx"/>'
	var collection := '<tileset firstgid="131" source="crop.tsx"/>'
	var layer := '<layer name="Ground" width="2" height="1" offsetx="10" offsety="12"><data encoding="csv">129,134</data></layer></map>'
	_write("external.tmx", header + collection + layer)
	# Also exercise inline collections, with a sparse local tile ID.
	_write("inline.tmx", header + _crop_tsx(0, 4128).replace('<tileset ', '<tileset firstgid="131" ') + layer)
	for name in ["external", "inline"]:
		var output := scratch.path_join(name + ".visual.tscn")
		var result: Dictionary = Importer.new().import_tmx(ProjectSettings.globalize_path(scratch.path_join(name + ".tmx")), output)
		_check(result.get("success", false), name + " cropped collection imports: " + str(result.get("error", "")))
		if not result.get("success", false):
			continue
		var visual: Node2D = (ResourceLoader.load(output, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene).instantiate()
		var ground := visual.get_node("Ground") as TileMapLayer
		_check(ground.position == Vector2(10, 12), "collection layer offsets are preserved")
		var dense := _pixels(ground, Vector2i.ZERO)
		_check(dense.get_data() == image.get_region(Rect2i(0, 4096, 32, 32)).get_data(), "collection import does not overwrite shared dense atlas pixels")
		var expected := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
		expected.blit_rect(image, Rect2i(0, 4128, 13, 22), Vector2i(0, 10))
		_check(_pixels(ground, Vector2i(1, 0)).get_data() == expected.get_data(), "13x22 crop retains exact pixels and bottom-left alignment")
		visual.free()
	# Bad source rectangles fail without replacing the saved visual.
	var output := scratch.path_join("external.visual.tscn")
	var before := FileAccess.get_sha256(output)
	_write("crop.tsx", _crop_tsx(30, 4128))
	var rejected: Dictionary = Importer.new().import_tmx(ProjectSettings.globalize_path(scratch.path_join("external.tmx")), output)
	_check(not rejected.get("success", true) and FileAccess.get_sha256(output) == before, "an out-of-bounds crop preserves the existing visual")
	_cleanup(scratch)
	print("tmx_collection_image_check: ", "FAIL" if failed else "PASS")
	quit(1 if failed else 0)

func _crop_tsx(x: int, y: int) -> String:
	return '<tileset name="Control" tilewidth="13" tileheight="22" tilecount="1" columns="0"><tile id="3" x="%d" y="%d" width="13" height="22"><image source="shared.png" width="32" height="4160"/></tile></tileset>' % [x, y]

func _pixels(layer: TileMapLayer, cell: Vector2i) -> Image:
	var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
	var pixels := source.texture.get_image()
	pixels.convert(Image.FORMAT_RGBA8)
	return pixels.get_region(source.get_tile_texture_region(layer.get_cell_atlas_coords(cell)))

func _write(name: String, value: String) -> void:
	var file := FileAccess.open(scratch.path_join(name), FileAccess.WRITE)
	file.store_string(value)

func _check(value: bool, message: String) -> void:
	if not value:
		failed = true
		push_error(message)

func _cleanup(path: String) -> void:
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	for name in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(name))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
