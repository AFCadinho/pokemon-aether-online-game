extends SceneTree

const Importer := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")
const SOURCES := {
	"main_hall": "Guild Base.tmx",
	"left_room": "Guild Base Room 1 - Empty.tmx",
	"right_room": "Guild Base Room 2 - Empty.tmx",
	"elevator": "Guild Base Elevator Room.tmx",
}


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		print("Usage: --script res://tools/import_guild_base_visuals.gd -- <artist/interior/guild_base>")
		quit(2)
		return
	for room: String in SOURCES:
		var output := "res://generated/tiled_visuals/guild_base_%s/guild_base_%s.visual.tscn" % [room, room]
		var result: Dictionary = Importer.new().import_tmx(args[0].path_join(SOURCES[room]), output)
		if not result.get("success", false):
			push_error("Guild Base %s import failed: %s" % [room, result.get("error", "")])
			quit(1)
			return
		print("Imported Guild Base ", room)
	quit(0)
