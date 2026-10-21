@tool
extends SceneTree

# The original Downloads export predates the artist map's Godot layer names.
# Keep its tiles and source files intact while retaining runtime door/depth paths.
const Importer := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tmx_visual_importer.gd")
const OUTPUT := "res://generated/tiled_visuals/fuchsia_city/fuchsia_city.visual.tscn"
const LAYER_ALIASES := {
	"Capa de patrones 1": "Ground",
	"Capa de patrones 2": "GroundDetail",
	"Capa de patrones 3": "Objects",
	"Capa de patrones 4": "ObjectsTop",
}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Usage: --script res://tools/import_fuchsia_download_visual.gd -- <Fuchsia City.tmx>")
		quit(2)
		return
	var result: Dictionary = Importer.new().import_tmx(args[0], "fuchsia_city")
	if not result.get("success", false):
		push_error(str(result.get("error", "Import failed")))
		quit(1)
		return
	var scene := ResourceLoader.load(OUTPUT, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	var visual := scene.instantiate()
	for original_name: String in LAYER_ALIASES:
		var layer := visual.get_node_or_null(NodePath(original_name)) as TileMapLayer
		if layer == null:
			continue
		layer.set_meta("tiled_original_name", original_name)
		layer.name = LAYER_ALIASES[original_name]
		layer.set_meta("tiled_name", str(layer.name))
		if layer.name == &"ObjectsTop":
			layer.z_index = 2048 + layer.get_index()
	visual.set_meta("pao_import_layer_aliases", LAYER_ALIASES)
	var packed := PackedScene.new()
	var error := packed.pack(visual)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT)
	visual.free()
	if error != OK:
		push_error("Could not save normalized visual: " + error_string(error))
		quit(1)
		return
	print("FUCHSIA_DOWNLOAD_IMPORT PASS: ", OUTPUT)
	quit()
