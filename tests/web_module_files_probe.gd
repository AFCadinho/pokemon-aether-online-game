extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1 or not ProjectSettings.load_resource_pack(args[0], false):
		quit(1)
		return
	var files: Array[String] = []
	_collect("res://", files)
	print("MODULE_FILES " + JSON.stringify(files))
	quit(0)

func _collect(path: String, files: Array[String]) -> void:
	for name in DirAccess.get_files_at(path):
		files.append(path.path_join(name))
	for name in DirAccess.get_directories_at(path):
		if not name.begins_with("."):
			_collect(path.path_join(name), files)
