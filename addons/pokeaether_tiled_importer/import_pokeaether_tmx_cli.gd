@tool
extends SceneTree

const PokeAetherTmxImporter := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tmx_importer.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		print("Usage: godot --headless --path . --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- <source.tmx>")
		quit(2)
		return

	var importer := PokeAetherTmxImporter.new()
	var result: Dictionary = importer.import_tmx(str(args[0]))
	if not bool(result.get("success", false)):
		push_error("PokeAether TMX import failed:\n%s" % str(result.get("error", "Unknown error")))
		quit(1)
		return

	for warning in result.get("warnings", []):
		push_warning(str(warning))

	print("PokeAether TMX import complete: %s" % str(result.get("runtime_scene_path", "")))
	print("Map data: %s" % str(result.get("map_data_path", "")))
	print("TileSet: %s" % str(result.get("tileset_path", "")))
	quit(0)
