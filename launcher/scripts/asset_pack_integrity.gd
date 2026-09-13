extends RefCounted


static func has_required_contents(
	install_dir: String,
	required_path: String,
	required_files: Array
) -> bool:
	if not required_path.is_empty() and not DirAccess.dir_exists_absolute(
		_globalize_install_path(install_dir.path_join(required_path))
	):
		return false

	for required_file_value: Variant in required_files:
		var required_file := str(required_file_value)
		if not FileAccess.file_exists(
			_globalize_install_path(install_dir.path_join(required_file))
		):
			return false

	return true


static func _globalize_install_path(path: String) -> String:
	if path.begins_with("user://") or path.begins_with("res://"):
		return ProjectSettings.globalize_path(path)
	return path
