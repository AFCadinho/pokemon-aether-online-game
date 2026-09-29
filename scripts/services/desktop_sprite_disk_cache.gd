extends RefCounted
## Persistent versioned sheets. A pair replaces its predecessor only after validation.

const DEFAULT_ROOT := "user://desktop-pokemon-sprites-v1"
const INDEX_NAME := "index.json"
const INDEX_BACKUP_NAME := "index.previous.json"
const INDEX_SCHEMA := 1
const MAX_INDEX_BYTES := 4 * 1024 * 1024
const MAX_FILE_BYTES := 4 * 1024 * 1024

var root_path: String
var _prepared := false
var _entries: Dictionary = {}


func _init(directory := DEFAULT_ROOT) -> void:
	root_path = directory


func file_for_url(url: String) -> String:
	return root_path.path_join(url.sha256_text() + ".cache")


func read(url: String) -> PackedByteArray:
	if not _prepare():
		return PackedByteArray()
	var path := file_for_url(url)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 1 or file.get_length() > MAX_FILE_BYTES:
		return PackedByteArray()
	return file.get_buffer(file.get_length())


func write(url: String, body: PackedByteArray) -> bool:
	if body.is_empty() or body.size() > MAX_FILE_BYTES or not _prepare():
		return false
	var path := ProjectSettings.globalize_path(file_for_url(url))
	var temporary := path + ".partial"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(body)
	var write_error := file.get_error()
	file.close()
	if write_error != OK or DirAccess.rename_absolute(temporary, path) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	return true


func invalidate(url: String) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(file_for_url(url)))


func commit(logical_key: String, metadata_url: String, sheet_url: String) -> bool:
	if logical_key.is_empty() or not _prepare():
		return false
	var current := [file_for_url(metadata_url).get_file(), file_for_url(sheet_url).get_file()]
	for name in current:
		if not FileAccess.file_exists(root_path.path_join(name)):
			return false
	var previous: Array = _entries.get(logical_key, [])
	if previous == current:
		return true
	var updated := _entries.duplicate(true)
	updated[logical_key] = current
	if not _write_index(updated):
		return false
	_entries = updated
	var retained := _referenced_files(_entries)
	for name in previous:
		if _valid_cache_name(str(name)) and not retained.has(name):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path.path_join(str(name))))
	return true


func bytes_used() -> int:
	var directory := DirAccess.open(root_path)
	if directory == null:
		return 0
	var total := 0
	for name in directory.get_files():
		var file := FileAccess.open(root_path.path_join(name), FileAccess.READ)
		if file != null:
			total += file.get_length()
	return total


func clear() -> bool:
	var directory := DirAccess.open(root_path)
	if directory != null:
		for name in directory.get_files():
			if name not in [INDEX_NAME, INDEX_BACKUP_NAME] and not name.ends_with(".cache") and not name.ends_with(".partial"):
				continue
			if DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path.path_join(name))) != OK:
				return false
	_entries.clear()
	_prepared = false
	return true


func _prepare() -> bool:
	if _prepared:
		return true
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root_path)) != OK:
		return false
	var index_path := root_path.path_join(INDEX_NAME)
	var parsed: Variant = _read_index(index_path)
	if not _valid_index(parsed):
		var backup_path := root_path.path_join(INDEX_BACKUP_NAME)
		var backup: Variant = _read_index(backup_path)
		if _valid_index(backup):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(index_path))
			if DirAccess.rename_absolute(ProjectSettings.globalize_path(backup_path), ProjectSettings.globalize_path(index_path)) != OK:
				return false
			parsed = backup
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path.path_join(INDEX_BACKUP_NAME)))
	var has_index: bool = _valid_index(parsed)
	var candidate_entries: Dictionary = parsed.entries if has_index else {}
	var clean_entries: Dictionary = {}
	for key in candidate_entries:
		var names: Variant = candidate_entries[key]
		if not key is String or not names is Array or names.size() != 2:
			continue
		if not _valid_cache_name(str(names[0])) or not _valid_cache_name(str(names[1])):
			continue
		if not FileAccess.file_exists(root_path.path_join(str(names[0]))) or not FileAccess.file_exists(root_path.path_join(str(names[1]))):
			continue
		clean_entries[key] = names
	if not has_index or clean_entries.size() != candidate_entries.size():
		if not _write_index(clean_entries):
			return false
	_entries = clean_entries
	var retained := _referenced_files(_entries)
	var directory := DirAccess.open(root_path)
	if directory != null:
		for name in directory.get_files():
			if name.ends_with(".partial") or (name.ends_with(".cache") and not retained.has(name)):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(root_path.path_join(name)))
	_prepared = true
	return true


func _write_index(entries: Dictionary) -> bool:
	var path := ProjectSettings.globalize_path(root_path.path_join(INDEX_NAME))
	var backup := ProjectSettings.globalize_path(root_path.path_join(INDEX_BACKUP_NAME))
	var temporary := path + ".partial"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"schema": INDEX_SCHEMA, "entries": entries}))
	var write_error := file.get_error()
	file.close()
	if write_error != OK or FileAccess.get_file_as_bytes(temporary).size() > MAX_INDEX_BYTES:
		DirAccess.remove_absolute(temporary)
		return false
	if DirAccess.rename_absolute(temporary, path) == OK:
		return true
	DirAccess.remove_absolute(backup)
	if FileAccess.file_exists(path) and DirAccess.rename_absolute(path, backup) != OK:
		DirAccess.remove_absolute(temporary)
		return false
	if DirAccess.rename_absolute(temporary, path) != OK:
		if FileAccess.file_exists(backup):
			DirAccess.rename_absolute(backup, path)
		DirAccess.remove_absolute(temporary)
		return false
	DirAccess.remove_absolute(backup)
	return true


func _read_index(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_INDEX_BYTES:
		return null
	return JSON.parse_string(file.get_as_text())


func _valid_index(value: Variant) -> bool:
	return value is Dictionary and value.get("schema") == INDEX_SCHEMA and value.get("entries") is Dictionary


func _referenced_files(entries: Dictionary) -> Dictionary:
	var retained := {}
	for names in entries.values():
		for name in names:
			retained[str(name)] = true
	return retained


func _valid_cache_name(name: String) -> bool:
	if name.length() != 70 or not name.ends_with(".cache"):
		return false
	var digest := name.trim_suffix(".cache")
	return digest == digest.to_lower() and digest.is_valid_hex_number()
