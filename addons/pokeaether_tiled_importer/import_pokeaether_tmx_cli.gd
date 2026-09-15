@tool
extends SceneTree

const PokeAetherTmxVisualImporter := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tmx_visual_importer.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1 or args.size() > 3:
		print("Usage: godot --headless --path . --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- <source.tmx> [visual_id] [missing_tilesets.json]")
		quit(2)
		return

	var visual_id := ""
	if args.size() >= 2:
		visual_id = str(args[1])
	var missing_tilesets := {}
	if args.size() == 3:
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(args[2]))
		if not parsed is Dictionary:
			push_error("Missing tilesets file must be a JSON object mapping exact TMX references to explicit TSX paths.")
			quit(2)
			return
		missing_tilesets = parsed

	var importer := PokeAetherTmxVisualImporter.new()
	var result: Dictionary = importer.import_tmx(str(args[0]), visual_id, missing_tilesets)
	if not bool(result.get("success", false)):
		push_error("PokeAether visual TMX import failed:\n%s" % str(result.get("error", "Unknown error")))
		quit(1)
		return

	print("PokeAether visual TMX import complete: %s" % str(result.get("visual_scene_path", "")))
	print("TileSet: %s" % str(result.get("tileset_path", "")))
	quit(0)
