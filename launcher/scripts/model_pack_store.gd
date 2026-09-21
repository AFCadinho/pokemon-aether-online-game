extends RefCounted
## Dedicated reviewed scenes, never arbitrary mods. Safe to use from a worker.
const Manifest = preload("model_pack_manifest.gd")
const MAX_FILE := 134217728
const MAX_TOTAL := 536870912
const MAX_JSON := 1048576
var root: String

func _init(directory: String = "user://model-packs") -> void:
	root = ProjectSettings.globalize_path(directory)

static func _hex(value: String) -> bool:
	if value.length() != 64:
		return false
	for c in value:
		if c not in "0123456789abcdef":
			return false
	return true

static func _hash(data: PackedByteArray) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(data)
	return hash.finish().hex_encode()

static func _json(path: String) -> Dictionary:
	var directory := DirAccess.open(path.get_base_dir())
	if directory == null or directory.is_link(path.get_file()):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_JSON:
		return {}
	var data: Variant = JSON.parse_string(file.get_as_text())
	return data if data is Dictionary else {}

func _root_safe() -> bool:
	var parent := DirAccess.open(root.get_base_dir())
	return parent != null and not parent.is_link(root.get_file())

func catalog(id: String) -> String:
	if not _hex(id) or not _root_safe():
		return ""
	var directory := DirAccess.open(root)
	if directory == null or directory.is_link(id):
		return ""
	var path := root.path_join(id).path_join("catalog.json")
	var entries := Manifest.pack_entries(_json(path), path.get_base_dir())
	if entries.is_empty() or FileAccess.get_sha256(path) != id:
		return ""
	for entry: Dictionary in entries:
		var file := FileAccess.open(entry.runtime_path, FileAccess.READ)
		if file == null or file.get_length() != int(entry.bytes):
			return ""
	return path

func selected_id() -> String:
	return str(_json(root.path_join("selection.json")).get("id", "")) if _root_safe() else ""

func selected_catalog() -> String:
	return catalog(selected_id())

func installed() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var directory := DirAccess.open(root)
	if directory == null or not _root_safe():
		return result
	var names := directory.get_directories()
	names.sort()
	for id in names:
		var path := catalog(id)
		if not path.is_empty():
			result.append({"id": id, "count": _json(path).entries.size()})
	return result

func select(id: String) -> Dictionary:
	if not id.is_empty():
		var path := catalog(id)
		if path.is_empty():
			return {"error": "Model pack is missing or incompatible."}
		for entry: Dictionary in Manifest.pack_entries(_json(path), path.get_base_dir()):
			if FileAccess.get_sha256(entry.runtime_path) != entry.runtime_sha256:
				return {"error": "Model checksum mismatch."}
	if DirAccess.make_dir_recursive_absolute(root) != OK or not _root_safe():
		return {"error": "Cannot access model pack folder."}
	var temporary := root.path_join(".selection-" + str(Time.get_ticks_usec()))
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return {"error": "Cannot save model selection."}
	file.store_string(JSON.stringify({"id": id}))
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, root.path_join("selection.json"))
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return {"error": "Cannot save model selection."}
	return {"error": "", "id": id}

# Check central AND local headers before ZIPReader can allocate a buffer.
# Our deterministic builder needs neither ZIP64 nor data descriptors.
static func _archive_entries(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22 or file.get_length() > MAX_TOTAL + MAX_JSON + 65536:
		return {}
	var tail_start := maxi(0, file.get_length() - 65557)
	file.seek(tail_start)
	var tail := file.get_buffer(file.get_length() - tail_start)
	var end := -1
	for i in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(i) == 0x06054b50 and i + 22 + tail.decode_u16(i + 20) == tail.size():
			end = i
			break
	if end < 0 or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0:
		return {}
	var count := tail.decode_u16(end + 10)
	var offset := tail.decode_u32(end + 16)
	if count < 2 or count > Manifest.DATA.data.models.size() + 1 or count != tail.decode_u16(end + 8) or offset >= tail_start + end:
		return {}
	file.seek(offset)
	var entries := {}
	var total := 0
	for i in count:
		if file.get_position() + 46 > tail_start + end:
			return {}
		var header := file.get_buffer(46)
		var flags := header.decode_u16(8)
		var method := header.decode_u16(10)
		var size := header.decode_u32(24)
		var mode := (header.decode_u32(38) >> 16) & 0xF000
		if header.decode_u32(0) != 0x02014b50 or flags & ~0x800 or method not in [0, 8] or mode not in [0, 0x8000] or header.decode_u16(34) != 0:
			return {}
		var name := file.get_buffer(header.decode_u16(28)).get_string_from_utf8()
		if entries.has(name) or size <= 0 or size > MAX_FILE:
			return {}
		if name == "catalog.json":
			if size > MAX_JSON: return {}
		elif not name.begins_with("models/") or not name.ends_with(".scn") or not _hex(name.trim_prefix("models/").trim_suffix(".scn")):
			return {}
		total += size
		if total > MAX_TOTAL + MAX_JSON: return {}
		var next := file.get_position() + header.decode_u16(30) + header.decode_u16(32)
		var local_offset := header.decode_u32(42)
		if local_offset + 30 > offset: return {}
		file.seek(local_offset)
		var local := file.get_buffer(30)
		if local.decode_u32(0) != 0x04034b50 or local.decode_u16(6) != flags or local.decode_u16(8) != method or local.decode_u32(14) != header.decode_u32(16) or local.decode_u32(18) != header.decode_u32(20) or local.decode_u32(22) != size:
			return {}
		if file.get_buffer(local.decode_u16(26)).get_string_from_utf8() != name: return {}
		if file.get_position() + local.decode_u16(28) + header.decode_u32(20) > offset: return {}
		entries[name] = size
		file.seek(next)
	if file.get_position() != offset + tail.decode_u32(end + 12) or file.get_position() > tail_start + end:
		return {}
	return entries if entries.has("catalog.json") else {}

func import_zip(path: String) -> Dictionary:
	var sizes := _archive_entries(path)
	if sizes.is_empty(): return {"error": "Invalid or unsafe model archive."}
	var reader := ZIPReader.new()
	if reader.open(path) != OK: return {"error": "Cannot open model archive."}
	var files := reader.get_files()
	if files.size() != sizes.size():
		reader.close()
		return {"error": "Invalid or unsafe model archive."}
	for name in files:
		if not sizes.has(name):
			reader.close()
			return {"error": "Invalid or unsafe model archive."}
	var result := _extract(reader, sizes)
	reader.close()
	return result

func _extract(reader: ZIPReader, sizes: Dictionary) -> Dictionary:
	var bytes := reader.read_file("catalog.json")
	if bytes.size() != sizes["catalog.json"]: return {"error": "Invalid model catalog."}
	var parsed: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not parsed is Dictionary: return {"error": "Invalid model catalog."}
	if DirAccess.make_dir_recursive_absolute(root) != OK or not _root_safe():
		return {"error": "Cannot access model pack folder."}
	var entries := Manifest.pack_entries(parsed, root)
	if entries.is_empty() or entries.size() + 1 != sizes.size():
		return {"error": "Model pack is missing or incompatible."}
	for entry: Dictionary in entries:
		var relative: String = "models/" + entry.runtime_sha256 + ".scn"
		if sizes.get(relative, -1) != int(entry.bytes): return {"error": "Invalid model catalog."}
	var id := _hash(bytes)
	var destination := root.path_join(id)
	if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination) or DirAccess.open(root).is_link(id):
		return {"error": "This model pack is already installed."}
	var staging := root.path_join(".import-" + str(Time.get_ticks_usec()))
	if DirAccess.make_dir_absolute(staging) != OK: return {"error": "Cannot stage model pack."}
	var error := ""
	for name: String in sizes:
		var payload := bytes if name == "catalog.json" else reader.read_file(name)
		if payload.size() != sizes[name] or (name != "catalog.json" and _hash(payload) != name.get_file().get_basename()):
			error = "Model checksum mismatch."
			break
		var output := staging.path_join(name)
		if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
			error = "Cannot stage model pack."
			break
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			error = "Cannot stage model pack."
			break
		file.store_buffer(payload)
		var write_error := file.get_error()
		file.close()
		if write_error != OK or FileAccess.get_sha256(output) != _hash(payload):
			error = "Cannot finish writing model pack."
			break
	if error.is_empty():
		if DirAccess.dir_exists_absolute(destination) or FileAccess.file_exists(destination) or DirAccess.open(root).is_link(id) or DirAccess.rename_absolute(staging, destination) != OK:
			error = "Cannot install model pack."
	if not error.is_empty():
		# Remove only known files in this invocation's private staging directory.
		for name: String in sizes: DirAccess.remove_absolute(staging.path_join(name))
		DirAccess.remove_absolute(staging.path_join("models"))
		DirAccess.remove_absolute(staging)
	return {"error": error, "id": id if error.is_empty() else ""}
