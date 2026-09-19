extends RefCounted
## Shared data-only pack format for the launcher and desktop game.
const FORMAT_VERSION := 1
const MAX_JSON_BYTES := 2 * 1024 * 1024
const MAX_FILE_BYTES := 64 * 1024 * 1024
const MAX_PACK_BYTES := 2 * 1024 * 1024 * 1024
const CATEGORIES := ["cries", "battle_sprites", "followers", "sprite_collections"]
var root: String
var errors: PackedStringArray = []

func _init(directory: String = "user://mods") -> void:
	root = ProjectSettings.globalize_path(directory)

static func safe_relative(path: String) -> bool:
	if path.is_empty() or path.is_absolute_path() or path.contains("\\") or path.contains(":"):
		return false
	for part in path.split("/"):
		if part in ["", ".", ".."]:
			return false
	return true

static func valid_id(value: String) -> bool:
	if value.is_empty() or value.length() > 80:
		return false
	for character in value:
		if not character in "abcdefghijklmnopqrstuvwxyz0123456789-_":
			return false
	return true

static func read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_JSON_BYTES:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}

static func validate(manifest: Dictionary) -> String:
	if manifest.get("format_version") != FORMAT_VERSION:
		return "Unsupported pack format."
	for field in ["id", "name", "version", "author"]:
		if not manifest.get(field) is String or str(manifest[field]).strip_edges().is_empty() or str(manifest[field]).length() > 160:
			return "Missing pack field: " + field
	if not valid_id(manifest.id):
		return "Invalid pack ID."
	if not manifest.get("assets") is Dictionary or manifest.assets.is_empty():
		return "Pack has no assets."
	for category: String in manifest.assets:
		if not category in CATEGORIES or not manifest.assets[category] is Dictionary:
			return "Unsupported asset category."
		for key: String in manifest.assets[category]:
			var entry: Variant = manifest.assets[category][key]
			if not entry is Dictionary:
				return "Invalid asset entry."
			if category == "sprite_collections":
				if not entry.get("directory") is String or not safe_relative(entry.directory):
					return "Invalid sprite collection directory."
				if str(entry.get("style", "")) != "gen5":
					return "Unsupported sprite collection style."
				continue
			if not entry.get("file") is String or not safe_relative(entry.file):
				return "Unsafe asset path."
			if str(entry.file).get_extension() != ("ogg" if category == "cries" else "png"):
				return "Unsupported asset file type."
			if category == "battle_sprites":
				for field in ["columns", "rows", "frames"]:
					var number: Variant = entry.get(field, 1)
					if not (number is int or number is float) or not is_finite(float(number)) or float(number) != floor(float(number)) or number < 1 or number > 1024:
						return "Invalid sprite grid."
				if entry.get("frames", 1) > entry.get("columns", 1) * entry.get("rows", 1):
					return "Frame count exceeds sprite grid."
				for field in ["anchor", "offset"]:
					if entry.has(field):
						var pair: Variant = entry[field]
						if not pair is Array or pair.size() != 2:
							return "Invalid sprite position."
						for coordinate: Variant in pair:
							if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or abs(float(coordinate)) > 8192:
								return "Invalid sprite position."
				for field in ["fps", "scale"]:
					var number: Variant = entry.get(field, 10.0 if field == "fps" else 1.0)
					if not (number is int or number is float) or not is_finite(float(number)) or number <= 0 or number > (120 if field == "fps" else 10):
						return "Invalid sprite speed or scale."
	return ""

func asset_path(pack_id: String, relative: String) -> String:
	if not valid_id(pack_id) or not safe_relative(relative):
		return ""
	var current := root
	for part in (pack_id + "/" + relative).split("/"):
		var directory := DirAccess.open(current)
		if directory == null or directory.is_link(part):
			return ""
		current = current.path_join(part)
	return current if FileAccess.file_exists(current) else ""


func asset_directory(pack_id: String, relative: String) -> String:
	if not valid_id(pack_id) or not safe_relative(relative):
		return ""
	var current := root
	for part in (pack_id + "/" + relative).split("/"):
		var directory := DirAccess.open(current)
		if directory == null or directory.is_link(part):
			return ""
		current = current.path_join(part)
	return current if DirAccess.dir_exists_absolute(current) else ""

func installed() -> Array[Dictionary]:
	errors.clear()
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return result
	var names := directory.get_directories()
	names.sort()
	for pack_id in names:
		var path := asset_path(pack_id, "mod.json")
		if path.is_empty():
			continue
		var manifest := read_json(path)
		var error := validate(manifest)
		if error.is_empty() and manifest.id != pack_id:
			error = "Folder and pack ID differ."
		if not error.is_empty():
			errors.append(pack_id + ": " + error)
			continue
		result.append(manifest)
	return result

func enabled_ids() -> Array[String]:
	var result: Array[String] = []
	var values: Variant = read_json(root.path_join("enabled.json")).get("enabled", [])
	if values is Array:
		for value: Variant in values:
			if value is String and valid_id(value) and not value in result:
				result.append(value)
	return result

func save_enabled(ids: Array[String]) -> Error:
	var error := DirAccess.make_dir_recursive_absolute(root)
	if error != OK:
		return error
	var path := root.path_join("enabled.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify({"enabled": ids}, "\t"))
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(path + ".tmp")
		return write_error
	return DirAccess.rename_absolute(path + ".tmp", path)

func candidates(category: String, key: String) -> Array[Dictionary]:
	var packs: Dictionary = {}
	for pack in installed():
		packs[pack.id] = pack
	var result: Array[Dictionary] = []
	for pack_id in enabled_ids():
		var entry: Variant = packs.get(pack_id, {}).get("assets", {}).get(category, {}).get(key)
		if entry is Dictionary:
			var path := asset_path(pack_id, entry.file)
			if not path.is_empty():
				var candidate: Dictionary = entry.duplicate(true)
				candidate["path"] = path
				result.append(candidate)
	return result


func sprite_collection_directories() -> Array[String]:
	var packs: Dictionary = {}
	for pack in installed():
		packs[pack.id] = pack
	var result: Array[String] = []
	for pack_id in enabled_ids():
		var collections: Variant = packs.get(pack_id, {}).get("assets", {}).get("sprite_collections", {})
		if not collections is Dictionary:
			continue
		for entry_value: Variant in collections.values():
			if not entry_value is Dictionary:
				continue
			var entry := entry_value as Dictionary
			var directory := asset_directory(pack_id, str(entry.get("directory", "")))
			if not directory.is_empty() and not directory in result:
				result.append(directory)
	return result

func import_zip(path: String, replace_existing: bool = false) -> String:
	var zip_error := _check_zip_sizes(path)
	if not zip_error.is_empty():
		return zip_error
	var reader := ZIPReader.new()
	if reader.open(path) != OK:
		return "Cannot open zip."
	var files := reader.get_files()
	if files.size() > 20000 or not "mod.json" in files:
		reader.close()
		return "Zip must contain mod.json at its root (maximum 20000 entries)."
	var manifest_bytes := reader.read_file("mod.json")
	if manifest_bytes.size() > MAX_JSON_BYTES:
		reader.close()
		return "Manifest is too large."
	var parsed: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	var error := validate(manifest)
	if not error.is_empty():
		reader.close()
		return error
	var destination := root.path_join(manifest.id)
	var destination_exists := DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination)
	if destination_exists and not replace_existing:
		reader.close()
		return "This pack ID is already installed."
	var payloads: Dictionary = {"mod.json": true}
	var collection_directories: Array[String] = []
	var total := 0
	# Only declared PNG/Ogg assets are extracted; scripts and other zip entries are ignored.
	for category: String in manifest.assets:
		for entry: Dictionary in manifest.assets[category].values():
			if category == "sprite_collections":
				collection_directories.append(str(entry.directory) + "/")
				continue
			var relative: String = entry.file
			if payloads.has(relative):
				continue
			if not relative in files:
				reader.close()
				return "Missing asset: " + relative
			payloads[relative] = true
	for archived_path: String in files:
		if archived_path == "mod.json" or payloads.has(archived_path):
			continue
		for directory: String in collection_directories:
			if archived_path.begins_with(directory) and archived_path.get_extension() in ["png", "json"]:
				payloads[archived_path] = true
				break
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		reader.close()
		return "Cannot create mods folder."
	var staging := root.path_join(".import-" + str(Time.get_ticks_usec()))
	for relative: String in payloads:
		var data := manifest_bytes if relative == "mod.json" else reader.read_file(relative)
		total += data.size()
		if data.is_empty() or data.size() > MAX_FILE_BYTES or total > MAX_PACK_BYTES:
			reader.close()
			_remove_staging(staging, payloads)
			return "Pack exceeds the size limit or contains an empty asset."
		var output := staging.path_join(relative)
		if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
			_remove_staging(staging, payloads)
			reader.close()
			return "Cannot create pack folder."
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			_remove_staging(staging, payloads)
			reader.close()
			return "Cannot write pack."
		file.store_buffer(data)
		var write_error := file.get_error()
		file.close()
		if write_error != OK:
			_remove_staging(staging, payloads)
			reader.close()
			return "Cannot finish writing pack."
	reader.close()
	var backup := ""
	if destination_exists:
		backup = destination + ".backup-" + str(Time.get_ticks_usec())
		if DirAccess.rename_absolute(destination, backup) != OK:
			_remove_staging(staging, payloads)
			return "Cannot prepare pack update."
	if DirAccess.rename_absolute(staging, destination) != OK:
		if not backup.is_empty():
			DirAccess.rename_absolute(backup, destination)
		_remove_staging(staging, payloads)
		return "Cannot install pack."
	if not backup.is_empty():
		_remove_tree(backup)
	return ""

func _remove_staging(staging: String, payloads: Dictionary) -> void:
	for relative: String in payloads:
		var path := staging.path_join(relative)
		DirAccess.remove_absolute(path)
		var parent := path.get_base_dir()
		while parent != staging and parent.begins_with(staging + "/"):
			DirAccess.remove_absolute(parent)
			parent = parent.get_base_dir()
	DirAccess.remove_absolute(staging)


func _remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	for file in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for child in directory.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)

# Inspect central-directory sizes before ZIPReader allocates decompressed buffers.
# ZIP64, multipart and encrypted archives are deliberately outside format v1.
static func _check_zip_sizes(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22 or file.get_length() > MAX_PACK_BYTES:
		return "Invalid zip or archive too large."
	var tail_start := maxi(0, file.get_length() - 65557)
	file.seek(tail_start)
	var tail := file.get_buffer(file.get_length() - tail_start)
	var end := -1
	for index in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(index) == 0x06054b50 and index + 22 + tail.decode_u16(index + 20) == tail.size():
			end = index
			break
	if end < 0 or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0:
		return "Invalid or multipart zip."
	var count := tail.decode_u16(end + 10)
	var offset := tail.decode_u32(end + 16)
	if count == 0 or count > 20000 or count != tail.decode_u16(end + 8) or offset >= tail_start + end:
		return "Invalid zip directory."
	file.seek(offset)
	var total := 0
	var names: Dictionary = {}
	for index in range(count):
		if file.get_position() + 46 > tail_start + end:
			return "Truncated zip directory."
		var header := file.get_buffer(46)
		if header.decode_u32(0) != 0x02014b50 or header.decode_u16(8) & 1 or header.decode_u16(10) not in [0, 8]:
			return "Unsupported zip encoding."
		var size := header.decode_u32(24)
		total += size
		if size > MAX_FILE_BYTES or total > MAX_PACK_BYTES:
			return "Pack exceeds the size limit."
		var name := file.get_buffer(header.decode_u16(28)).get_string_from_utf8()
		if names.has(name) or not safe_relative(name.trim_suffix("/")):
			return "Unsafe or duplicate zip entry."
		names[name] = true
		if name == "mod.json" and size > MAX_JSON_BYTES:
			return "Manifest is too large."
		file.seek(file.get_position() + header.decode_u16(30) + header.decode_u16(32))
	if file.get_position() != offset + tail.decode_u32(end + 12) or file.get_position() > tail_start + end:
		return "Invalid zip directory size."
	return ""
