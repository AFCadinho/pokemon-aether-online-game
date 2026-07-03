@tool
extends SceneTree

const TmxVisualImporter := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		print("Usage: godot --headless --path . --script res://addons/tiled_tmx_importer/import_tmx_cli.gd -- <source.tmx> <output.tscn>")
		quit(2)
		return

	var importer := TmxVisualImporter.new()
	var result: Dictionary = importer.import_tmx(str(args[0]), str(args[1]))
	if not bool(result.get("success", false)):
		push_error("TMX visual import failed: %s" % str(result.get("error", "Unknown error")))
		quit(1)
		return

	print("TMX visual import complete: %s" % str(result.get("scene_path", args[1])))
	quit(0)
