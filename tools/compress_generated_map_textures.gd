@tool
extends SceneTree

const GENERATED_ROOT := "res://generated/tiled_visuals"


func _init() -> void:
	var visual_ids := OS.get_cmdline_user_args()
	if visual_ids.is_empty():
		push_error("Usage: godot --headless --path . --script res://tools/compress_generated_map_textures.gd -- <visual_id> [...]")
		quit(2)
		return

	var converted := 0
	var before_bytes := 0
	var after_bytes := 0
	for visual_id: String in visual_ids:
		if not _is_safe_visual_id(visual_id):
			push_error("Unsafe visual id: %s" % visual_id)
			quit(2)
			return
		var result := _compress_directory(GENERATED_ROOT.path_join(visual_id).path_join("assets"))
		if not bool(result.get("success", false)):
			push_error(str(result.get("error", "Texture conversion failed.")))
			quit(1)
			return
		converted += int(result.get("converted", 0))
		before_bytes += int(result.get("before_bytes", 0))
		after_bytes += int(result.get("after_bytes", 0))

	print(
		"Compressed %d generated textures losslessly: %.1f MiB -> %.1f MiB." % [
			converted,
			float(before_bytes) / 1048576.0,
			float(after_bytes) / 1048576.0,
		]
	)
	quit(0)


func _compress_directory(resource_dir: String) -> Dictionary:
	var global_dir := ProjectSettings.globalize_path(resource_dir)
	var dir := DirAccess.open(global_dir)
	if dir == null:
		return {"success": false, "error": "Generated asset directory is missing: %s" % resource_dir}

	var converted := 0
	var before_bytes := 0
	var after_bytes := 0
	for file_name: String in dir.get_files():
		if not file_name.ends_with(".texture.res"):
			continue
		var resource_path := resource_dir.path_join(file_name)
		var global_path := ProjectSettings.globalize_path(resource_path)
		var source := ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if source == null:
			return {"success": false, "error": "Could not load generated texture: %s" % resource_path}
		if source is PortableCompressedTexture2D:
			if source.get_compression_mode() != PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS:
				return {"success": false, "error": "Generated texture uses non-lossless compression: %s" % resource_path}
			continue

		var image := source.get_image()
		if image == null or image.is_empty():
			return {"success": false, "error": "Generated texture has no readable image: %s" % resource_path}
		var original_size := image.get_size()
		var compressed := PortableCompressedTexture2D.new()
		compressed.keep_compressed_buffer = true
		compressed.create_from_image(image, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
		if Vector2i(compressed.get_size()) != original_size:
			return {"success": false, "error": "Texture dimensions changed for %s." % resource_path}

		var temp_path := resource_path.trim_suffix(".res") + ".tmp.res"
		var save_error := ResourceSaver.save(compressed, temp_path)
		if save_error != OK:
			return {"success": false, "error": "Could not write compressed texture %s: %s" % [resource_path, error_string(save_error)]}
		var temp_global := ProjectSettings.globalize_path(temp_path)
		var temp_texture := ResourceLoader.load(temp_path, "", ResourceLoader.CACHE_MODE_IGNORE) as PortableCompressedTexture2D
		if temp_texture == null or Vector2i(temp_texture.get_size()) != original_size:
			DirAccess.remove_absolute(temp_global)
			return {"success": false, "error": "Compressed texture verification failed: %s" % resource_path}

		var original_bytes := FileAccess.get_file_as_bytes(global_path).size()
		var compressed_bytes := FileAccess.get_file_as_bytes(temp_global).size()
		var backup_global := global_path + ".uncompressed-backup"
		var rename_error := DirAccess.rename_absolute(global_path, backup_global)
		if rename_error != OK:
			DirAccess.remove_absolute(temp_global)
			return {"success": false, "error": "Could not stage original texture %s: %s" % [resource_path, error_string(rename_error)]}
		rename_error = DirAccess.rename_absolute(temp_global, global_path)
		if rename_error != OK:
			DirAccess.rename_absolute(backup_global, global_path)
			return {"success": false, "error": "Could not install compressed texture %s: %s" % [resource_path, error_string(rename_error)]}
		DirAccess.remove_absolute(backup_global)
		converted += 1
		before_bytes += original_bytes
		after_bytes += compressed_bytes

	return {
		"success": true,
		"converted": converted,
		"before_bytes": before_bytes,
		"after_bytes": after_bytes,
	}


func _is_safe_visual_id(value: String) -> bool:
	if value.is_empty() or value == "." or value == "..":
		return false
	for index in range(value.length()):
		var code := value.unicode_at(index)
		if not (
			(code >= 48 and code <= 57)
			or (code >= 97 and code <= 122)
			or code == 95
		):
			return false
	return true
