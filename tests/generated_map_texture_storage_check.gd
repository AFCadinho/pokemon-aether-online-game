extends SceneTree

const GENERATED_VISUAL_ROOT := "res://generated/tiled_visuals"
const SUSPICIOUS_TEXTURE_BYTES := 2 * 1024 * 1024


func _init() -> void:
	var failures: Array[String] = []
	var texture_count := _check_directory(GENERATED_VISUAL_ROOT, failures)
	if texture_count == 0:
		failures.append("No generated map textures were found under %s." % GENERATED_VISUAL_ROOT)

	if failures.is_empty():
		print("generated_map_texture_storage_check: PASS (%d textures)" % texture_count)
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _check_directory(directory: String, failures: Array[String]) -> int:
	var texture_count := 0
	for file_name: String in DirAccess.get_files_at(directory):
		if not file_name.ends_with(".texture.res"):
			continue

		texture_count += 1
		var path := directory.path_join(file_name)
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			failures.append("Could not inspect generated map texture %s." % path)
			continue
		var stored_bytes := file.get_length()
		file.close()

		var texture := ResourceLoader.load(path, "Texture2D", ResourceLoader.CACHE_MODE_IGNORE) as Texture2D
		if texture == null:
			failures.append("Could not load generated map texture %s." % path)
			continue
		if not texture is PortableCompressedTexture2D:
			var detail := ""
			if stored_bytes >= SUSPICIOUS_TEXTURE_BYTES:
				detail = " (suspicious size: %.1f MiB)" % (float(stored_bytes) / 1048576.0)
			failures.append("Generated map texture is not portable-compressed: %s%s" % [path, detail])
			continue
		if texture.get_compression_mode() != PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS:
			failures.append("Generated map texture is not lossless: %s" % path)

	for child_directory: String in DirAccess.get_directories_at(directory):
		texture_count += _check_directory(directory.path_join(child_directory), failures)
	return texture_count
