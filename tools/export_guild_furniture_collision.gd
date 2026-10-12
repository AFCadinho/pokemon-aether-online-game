extends SceneTree

func _init() -> void:
	var authoring := preload("res://tools/guild_furniture_collision_authoring.gd")
	var backend := authoring.default_backend_path()
	var check := false
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--check":
			check = true
		elif argument.begins_with("--backend="):
			backend = argument.trim_prefix("--backend=")
	var result := authoring.export_catalogs(backend, check)
	if not bool(result.success):
		push_error(str(result.error))
		quit(1)
		return
	print("Guild furniture collision: %d scenes checked, %d changes%s." % [result.count, result.changed, " exported" if not check else ""])
	quit()
