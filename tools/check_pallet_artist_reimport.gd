extends SceneTree

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Usage: ARTIST_PALLET_DIRECTORY EXPLICIT_INDOOR_TSX. Read-only artist inputs; temporary output only.")
		quit(2)
		return
	var scratch := "user://artist_reimport_%d" % OS.get_process_id()
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(scratch)):
		quit(1)
		return
	var valid := true
	for pair in [["players_house", "Player's House.tmx"], ["pokemon_laboratory", "Pokémon Laboratory.tmx"]]:
		var path := "res://generated/tiled_visuals/%s/%s.visual.tscn" % [pair[0], pair[0]]
		var canonical: Node = load(path).instantiate()
		var before := preload("res://tests/support/visual_atlas_fingerprint.gd").new().capture(canonical)
		canonical.free()
		var target := scratch.path_join(pair[0] + "/" + pair[0] + ".visual.tscn")
		var result := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd").new().import_tmx(args[0].path_join(pair[1]), target, {"Indoors Tileset.tsx": args[1]})
		if not result.get("success", false):
			push_error(str(result))
			valid = false
			break
		var scene := ResourceLoader.load(target, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
		var root := scene.instantiate()
		var after := preload("res://tests/support/visual_atlas_fingerprint.gd").new().capture(root)
		# Require the complete approved layer/cell/artwork/TileData fingerprint.
		var matches: bool = before.fingerprint == after.fingerprint
		print("ARTIST_REIMPORT ", JSON.stringify({"id": pair[0], "identicalFingerprint": matches, "before": before, "after": after}))
		root.free()
		valid = valid and matches
	_cleanup(scratch, scratch)
	quit(0 if valid else 1)

func _cleanup(path: String, scratch: String) -> void:
	assert(path == scratch or path.begins_with(scratch + "/"))
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
		return
	for name in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(name)))
	for name in DirAccess.get_directories_at(path):
		_cleanup(path.path_join(name), scratch)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
