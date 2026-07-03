@tool
extends SceneTree

const PokeAetherTmxVisualImporter := preload("res://addons/pokeaether_tiled_importer/importer/pokeaether_tmx_visual_importer.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 1:
		print("Usage: godot --headless --path . --script res://addons/pokeaether_tiled_importer/import_pokeaether_tmx_cli.gd -- <source.tmx> [visual_id]")
		quit(2)
		return

	var visual_id := ""
	if args.size() >= 2:
		visual_id = str(args[1])

	var importer := PokeAetherTmxVisualImporter.new()
	var result: Dictionary = importer.import_tmx(str(args[0]), visual_id)
	if not bool(result.get("success", false)):
		push_error("PokeAether visual TMX import failed:\n%s" % str(result.get("error", "Unknown error")))
		quit(1)
		return

	print("PokeAether visual TMX import complete: %s" % str(result.get("visual_scene_path", "")))
	print("TileSet: %s" % str(result.get("tileset_path", "")))
	quit(0)
