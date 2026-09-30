extends RefCounted
## A bounded cache owned by the app. Receipts detect truncated/corrupt local files.
const DEFAULT_ROOT := "user://mobile-assets-v1"
const DEFAULT_BUDGET := 256 * 1024 * 1024
var root: String
var budget: int
var pins: Dictionary = {}

func _init(directory := DEFAULT_ROOT, byte_budget := DEFAULT_BUDGET) -> void:
	root = directory
	budget = byte_budget
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var directory_handle := DirAccess.open(root)
	if directory_handle != null:
		for name in directory_handle.get_files():
			if name.ends_with(".partial"):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(root.path_join(name)))

func path_for(url: String) -> String:
	return root.path_join(url.sha256_text() + ".cache")

func read_path(url: String, expected_sha := "", limit := 64 * 1024 * 1024) -> String:
	var path := path_for(url)
	var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".json")) if FileAccess.file_exists(path + ".json") else null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var length := file.get_length()
	file.close()
	if not receipt is Dictionary or length < 1 or length > limit or int(receipt.get("size", 0)) != length:
		invalidate(url)
		return ""
	var digest := FileAccess.get_sha256(path)
	if digest.length() != 64 or digest != str(receipt.get("sha256", "")) or (expected_sha != "" and digest != expected_sha):
		invalidate(url)
		return ""
	_write_receipt(path, length, digest)
	return path

func commit(url: String, temporary: String, expected_sha: String, limit: int) -> String:
	var file := FileAccess.open(temporary, FileAccess.READ)
	if file == null:
		return ""
	var length := file.get_length()
	file.close()
	var digest := FileAccess.get_sha256(temporary)
	if digest.length() != 64 or length < 1 or length > limit or length > budget or (expected_sha != "" and digest != expected_sha):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ""
	var path := path_for(url)
	if not _make_room(length, path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ""
	if DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		return ""
	_write_receipt(path, length, digest)
	return path

func invalidate(url: String) -> void:
	var path := path_for(url)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path + ".json"))

func _write_receipt(path: String, size: int, digest: String) -> void:
	var file := FileAccess.open(path + ".json", FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"size": size, "sha256": digest, "used": Time.get_unix_time_from_system()}))
		file.close()

func _make_room(incoming: int, replacing: String) -> bool:
	var entries: Array[Dictionary] = []
	var total := incoming
	var directory := DirAccess.open(root)
	if directory == null:
		return false
	for name in directory.get_files():
		if not name.ends_with(".cache"):
			continue
		var path := root.path_join(name)
		if path == replacing:
			continue
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var size := file.get_length()
		file.close()
		total += size
		var receipt: Variant = JSON.parse_string(FileAccess.get_file_as_string(path + ".json")) if FileAccess.file_exists(path + ".json") else {}
		entries.append({"path": path, "size": size, "used": float(receipt.get("used", 0)) if receipt is Dictionary else 0.0})
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.used < b.used)
	for entry in entries:
		if total <= budget:
			break
		if pins.has(entry.path):
			continue
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(entry.path)) != OK:
			continue
		DirAccess.remove_absolute(ProjectSettings.globalize_path(str(entry.path) + ".json"))
		total -= int(entry.size)
	return total <= budget
