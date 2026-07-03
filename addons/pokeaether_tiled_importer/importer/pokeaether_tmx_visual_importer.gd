@tool
extends RefCounted

const PathUtils := preload("res://addons/tiled_tmx_importer/importer/tmx_path_utils.gd")
const TmxVisualImporter := preload("res://addons/tiled_tmx_importer/importer/tmx_visual_importer.gd")

const GENERATED_VISUAL_ROOT := "res://generated/tiled_visuals"


func import_tmx(tmx_path: String, visual_id_override: String = "") -> Dictionary:
	var visual_id := _derive_visual_id(tmx_path, visual_id_override)
	if visual_id == "":
		return {
			"success": false,
			"error": "Could not derive a safe visual id for %s." % tmx_path,
		}

	var generated_dir := GENERATED_VISUAL_ROOT.path_join(visual_id)
	if not generated_dir.begins_with(GENERATED_VISUAL_ROOT + "/"):
		return {
			"success": false,
			"error": "Generated visual directory escaped %s: %s" % [GENERATED_VISUAL_ROOT, generated_dir],
		}

	var visual_scene_path := generated_dir.path_join("%s.visual.tscn" % visual_id)
	_clean_generated_assets(generated_dir.path_join("assets"))

	var importer := TmxVisualImporter.new()
	var result: Dictionary = importer.import_tmx(tmx_path, visual_scene_path)
	if not bool(result.get("success", false)):
		return result

	result["visual_id"] = visual_id
	result["generated_dir"] = generated_dir
	result["visual_scene_path"] = visual_scene_path
	return result


func _derive_visual_id(tmx_path: String, visual_id_override: String) -> String:
	var source := visual_id_override.strip_edges()
	if source == "":
		source = PathUtils.normalize_path(tmx_path).get_file().get_basename()
	return _sanitize_generated_id(source)


func _sanitize_generated_id(value: String) -> String:
	var text := value.strip_edges().to_lower()
	var output := ""
	var previous_was_separator := false

	for index in range(text.length()):
		var code := text.unicode_at(index)
		var is_digit := code >= 48 and code <= 57
		var is_lower := code >= 97 and code <= 122
		var is_separator := code == 45 or code == 95 or code == 32
		if is_digit or is_lower:
			output += text.substr(index, 1)
			previous_was_separator = false
		elif is_separator and not previous_was_separator and output != "":
			output += "_"
			previous_was_separator = true

	output = output.trim_suffix("_")
	if output == "." or output == "..":
		return ""
	return output


func _clean_generated_assets(assets_dir: String) -> void:
	if not assets_dir.begins_with(GENERATED_VISUAL_ROOT + "/"):
		return

	var global_assets_dir := ProjectSettings.globalize_path(assets_dir)
	if not DirAccess.dir_exists_absolute(global_assets_dir):
		return

	_remove_directory_contents(global_assets_dir)
	DirAccess.remove_absolute(global_assets_dir)


func _remove_directory_contents(global_dir: String) -> void:
	var dir := DirAccess.open(global_dir)
	if dir == null:
		return

	for file_name in dir.get_files():
		DirAccess.remove_absolute(global_dir.path_join(file_name))
	for child_dir in dir.get_directories():
		var child_path := global_dir.path_join(child_dir)
		_remove_directory_contents(child_path)
		DirAccess.remove_absolute(child_path)
