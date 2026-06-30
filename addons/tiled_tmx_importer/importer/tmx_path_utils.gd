@tool
extends RefCounted


static func normalize_path(path: String) -> String:
	var cleaned := path.strip_edges()
	if cleaned.begins_with("res://") or cleaned.begins_with("user://"):
		return cleaned
	return cleaned.simplify_path()


static func globalize(path: String) -> String:
	var normalized := normalize_path(path)
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return ProjectSettings.globalize_path(normalized)
	return normalized


static func localize(path: String) -> String:
	var normalized := normalize_path(path)
	if normalized.begins_with("res://") or normalized.begins_with("user://"):
		return normalized

	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var absolute_path := normalized.simplify_path()
	if absolute_path.begins_with(project_root + "/"):
		return "res://%s" % absolute_path.substr(project_root.length() + 1)
	return absolute_path


static func resolve_relative(base_file_path: String, relative_path: String) -> String:
	var cleaned := relative_path.strip_edges()
	if cleaned.begins_with("res://") or cleaned.begins_with("user://") or cleaned.is_absolute_path():
		return normalize_path(cleaned)

	var base_dir := globalize(base_file_path).get_base_dir()
	return (base_dir.path_join(cleaned)).simplify_path()


static func ensure_resource_directory(path: String) -> Error:
	var normalized := normalize_path(path)
	var directory_path := normalized.get_base_dir()
	if directory_path == "":
		return OK

	if directory_path.begins_with("res://") or directory_path.begins_with("user://"):
		return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory_path))

	return DirAccess.make_dir_recursive_absolute(directory_path)


static func scene_to_tileset_path(output_scene_path: String) -> String:
	var normalized := normalize_path(output_scene_path)
	var base_dir := normalized.get_base_dir()
	var base_name := normalized.get_file().get_basename()
	return base_dir.path_join("%s.tileset.tres" % base_name)


static func sanitize_node_name(value: String, fallback: String) -> String:
	var name := value.strip_edges()
	if name == "":
		name = fallback
	name = name.replace("/", "_")
	name = name.replace("\\", "_")
	name = name.replace(":", "_")
	name = name.replace("@", "_")
	if name == "":
		return fallback
	return name
