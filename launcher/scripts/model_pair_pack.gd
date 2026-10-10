extends RefCounted
## Data-only PCK validation shared verbatim with the independently exported launcher.
## Inspect the physical pack before mounting; never extract a second model copy.
const FORMAT := "model-pair-pck-v1"
const KIND := "pokeaether-model-pair"
const MAX_PACK := 536870912
const MAX_MEMBER := 134217728
const MAX_FILES := 128
const MAX_MANIFEST := 1048576
static var mounted := {}
static var namespaces := {}
static var mounts_lock := Mutex.new()
static var closed := {}

static func hex(value: Variant) -> bool:
	if not value is String or value.length() != 64:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func integer(value: Variant, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == floor(float(value)) and value > 0 and value <= maximum

static func metadata_error(asset: Dictionary) -> String:
	if asset.get("format") != FORMAT or not hex(asset.get("sha256")) or not integer(asset.get("size_bytes"), MAX_PACK):
		return "Invalid model-pair pack identity."
	var manifest: Variant = asset.get("pair_manifest")
	if not manifest is Dictionary or manifest.get("schema") != 1 or manifest.get("kind") != KIND:
		return "Invalid model-pair manifest."
	for field in ["asset_id", "species_id", "form_id", "version", "dependencies", "appearances"]:
		if manifest.get(field) != asset.get(field):
			return "Model-pair manifest differs from its trusted index."
	var resource_root := str(manifest.get("resource_root", ""))
	if not resource_root.begins_with("res://pokemon-pairs/") or not hex(resource_root.trim_prefix("res://pokemon-pairs/")):
		return "Invalid model-pair resource_root."
	var files: Variant = manifest.get("files")
	if not files is Array or files.size() < 2 or files.size() >= MAX_FILES:
		return "Invalid model-pair file table."
	var declared := {}
	var pattern := RegEx.create_from_string("^(models/(normal|shiny)\\.scn|textures/[0-9a-f]{64}\\.res)$")
	var total := 0
	for row: Variant in files:
		if not row is Dictionary:
			return "Invalid model-pair file."
		var path := str(row.get("path", ""))
		if pattern.search(path) == null or declared.has(path) or not hex(row.get("sha256")) or not integer(row.get("bytes"), MAX_MEMBER) or row.bytes < 24:
			return "Invalid or duplicate model-pair member."
		if not integer(row.get("decoded_bytes"), MAX_PACK):
			return "Unbounded decoded model resource."
		declared[path] = row
		total += int(row.bytes)
	if total > MAX_PACK or not declared.has("models/normal.scn") or not declared.has("models/shiny.scn"):
		return "Model-pair payload is incomplete or too large."
	var appearances: Variant = manifest.get("appearances")
	if not appearances is Array or appearances.size() != 2:
		return "A model pair requires normal and shiny."
	var variants := {}
	for appearance: Variant in appearances:
		if not appearance is Dictionary:
			return "Invalid model-pair appearance."
		var variant := str(appearance.get("variant", ""))
		var path := "models/" + variant + ".scn"
		if variant not in ["normal", "shiny"] or variants.has(variant) or appearance.get("runtime_path") != path:
			return "Invalid model-pair appearance path."
		if appearance.get("runtime_sha256") != declared[path].sha256 or appearance.get("bytes") != declared[path].bytes:
			return "Model-pair appearance differs from its member."
		if not hex(appearance.get("source_sha256")) or not integer(appearance.get("cache_source_bytes"), MAX_MEMBER):
			return "Model-pair appearance has no qualified source budget."
		variants[variant] = true
	return ""

static func _failure(reason: String) -> Dictionary:
	return {"error": reason}

static func inspect(path: String, asset: Dictionary) -> Dictionary:
	var error := metadata_error(asset)
	if not error.is_empty():
		return _failure(error)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() != int(asset.size_bytes) or FileAccess.get_sha256(path) != asset.sha256:
		return _failure("Model-pair pack size/checksum mismatch.")
	var length := file.get_length()
	if length < 108 or file.get_32() != 0x43504447 or file.get_32() != 3 or file.get_32() != 4 or file.get_32() != 6:
		return _failure("Unsupported standalone model-pair PCK header.")
	file.get_32() # Engine patch version.
	if file.get_32() != 2: # Relative file base only; no encryption, patches or sparse packs.
		return _failure("Unsupported model-pair PCK flags.")
	var base := file.get_64()
	var table := file.get_64()
	for unused in 16:
		if file.get_32() != 0:
			return _failure("Invalid reserved PCK header.")
	if base < 104 or table < base or table > length - 4:
		return _failure("Invalid model-pair PCK offsets.")
	file.seek(table)
	var count := file.get_32()
	var manifest: Dictionary = asset.pair_manifest
	if count != manifest.files.size() + 1 or count > MAX_FILES:
		return _failure("Model-pair PCK contains undeclared files.")
	var expected := {"bundle.json": {"bytes": -1}}
	for row: Dictionary in manifest.files:
		expected[row.path] = row
	var members := {}
	var resource_root: String = manifest.resource_root
	var ranges: Array = []
	for unused in count:
		if file.get_position() > length - 4:
			return _failure("Truncated model-pair table.")
		var path_size := file.get_32()
		if path_size < 1 or path_size > 512 or file.get_position() + path_size + 36 > length:
			return _failure("Invalid model-pair table path length.")
		var path_bytes := file.get_buffer(path_size)
		while not path_bytes.is_empty() and path_bytes[-1] == 0:
			path_bytes.resize(path_bytes.size() - 1)
		var name := path_bytes.get_string_from_utf8()
		if name.to_utf8_buffer() != path_bytes or not name.begins_with(resource_root.trim_prefix("res://") + "/"):
			return _failure("Model-pair member escapes its resource_root.")
		var relative := name.trim_prefix(resource_root.trim_prefix("res://") + "/")
		if not expected.has(relative) or members.has(relative):
			return _failure("Unexpected or duplicate model-pair member.")
		var offset := file.get_64()
		var size := file.get_64()
		var md5 := file.get_buffer(16)
		var flags := file.get_32()
		if flags != 0 or offset < 0 or size < 1 or size > MAX_MEMBER or offset > table - base or size > table - base - offset:
			return _failure("Invalid model-pair member flags/range.")
		if (relative == "bundle.json" and size > MAX_MANIFEST) or (relative != "bundle.json" and size != int(expected[relative].bytes)):
			return _failure("Model-pair member size mismatch.")
		members[relative] = {"offset": base + offset, "bytes": size, "md5": md5}
		ranges.append([base + offset, base + offset + size])
	if file.get_position() != length:
		return _failure("Trailing or truncated model-pair table.")
	ranges.sort_custom(func(a: Array, b: Array): return a[0] < b[0])
	for i in range(1, ranges.size()):
		if ranges[i][0] < ranges[i - 1][1]:
			return _failure("Overlapping model-pair members.")
	for name: String in members:
		var member: Dictionary = members[name]
		file.seek(int(member.offset))
		var context := HashingContext.new()
		context.start(HashingContext.HASH_SHA256)
		var md5 := HashingContext.new()
		md5.start(HashingContext.HASH_MD5)
		var remaining := int(member.bytes)
		var json_bytes := PackedByteArray()
		while remaining > 0:
			var chunk := file.get_buffer(mini(1048576, remaining))
			if chunk.is_empty():
				return _failure("Truncated model-pair payload.")
			context.update(chunk)
			md5.update(chunk)
			if name == "bundle.json":
				json_bytes.append_array(chunk)
			remaining -= chunk.size()
		if md5.finish() != member.md5:
			return _failure("Model-pair PCK member MD5 mismatch.")
		var digest := context.finish().hex_encode()
		if name == "bundle.json":
			if JSON.parse_string(json_bytes.get_string_from_utf8()) != manifest:
				return _failure("Model-pair manifest differs from trusted metadata.")
		else:
			if digest != expected[name].sha256:
				return _failure("Model-pair member SHA-256 mismatch.")
			file.seek(int(member.offset))
			if file.get_buffer(4).get_string_from_ascii() != "RSCC" or file.get_32() != 2:
				return _failure("Unsupported model-pair native container.")
			var block_size := file.get_32()
			var decoded := file.get_32()
			if block_size != 262144 or decoded != int(expected[name].decoded_bytes):
				return _failure("Model-pair decoded size/codec mismatch.")
			var count_blocks := int(decoded / block_size) + 1
			if 20 + count_blocks * 4 >= int(member.bytes):
				return _failure("Truncated native model-pair block table.")
			var payload := 0
			for unused in count_blocks:
				var compressed_bytes := file.get_32()
				if compressed_bytes < 1 or compressed_bytes > int(member.bytes):
					return _failure("Invalid native model-pair block size.")
				payload += compressed_bytes
			if payload + 20 + count_blocks * 4 != int(member.bytes):
				return _failure("Native model-pair block bounds mismatch.")
			file.seek(int(member.offset) + int(member.bytes) - 4)
			if file.get_buffer(4).get_string_from_ascii() != "RSCC":
				return _failure("Invalid native model-pair footer.")
	return {"error": "", "manifest": manifest, "members": members, "path": ProjectSettings.globalize_path(path), "sha256": asset.sha256}

static func install(source: String, asset: Dictionary, destination: String, allow_repair := true) -> Dictionary:
	var checked := inspect(source, asset)
	if not str(checked.error).is_empty():
		return checked
	var parent := DirAccess.open(destination.get_base_dir())
	if parent != null and parent.is_link(destination.get_file()):
		return _failure("Linked model-pair object.")
	var replace := DirAccess.dir_exists_absolute(destination)
	if replace:
		var existing := object_check(destination, asset)
		if str(existing.error).is_empty():
			return existing
		if not allow_repair or protects(destination):
			return _failure("Corrupt shared model is in use; repair deferred until restart.")
		var folder := DirAccess.open(destination)
		var metadata := FileAccess.open(destination.path_join("bundle.json"), FileAccess.READ)
		var names := folder.get_files() if folder != null else PackedStringArray()
		names.sort()
		if folder == null or names != PackedStringArray(["bundle.json", "model-pair.pck"]) or not folder.get_directories().is_empty() or folder.is_link("bundle.json") or folder.is_link("model-pair.pck") or metadata == null or metadata.get_length() > MAX_MANIFEST or JSON.parse_string(metadata.get_as_text()) != asset:
			return _failure("Invalid immutable model object ownership; repair refused.")
	var staging := destination + ".install-" + str(Time.get_ticks_usec())
	if DirAccess.make_dir_recursive_absolute(staging) != OK:
		return _failure("Cannot stage model-pair object.")
	var pack := staging.path_join("model-pair.pck")
	var input := FileAccess.open(source, FileAccess.READ)
	var output := FileAccess.open(pack, FileAccess.WRITE)
	var error := ""
	if input == null or output == null:
		error = "Cannot write staged model-pair pack."
	else:
		while input.get_position() < input.get_length():
			var chunk := input.get_buffer(1048576)
			if chunk.is_empty():
				error = "Model-pair source read failed."
				break
			output.store_buffer(chunk)
			if output.get_error() != OK:
				error = "Model-pair write failed."
				break
		output.close()
	input = null
	output = null
	if error.is_empty():
		var staged := inspect(pack, asset)
		error = str(staged.error)
	if error.is_empty():
		var file := FileAccess.open(staging.path_join("bundle.json"), FileAccess.WRITE)
		if file == null:
			error = "Cannot write model-pair metadata."
		else:
			file.store_string(JSON.stringify(asset))
			if file.get_error() != OK:
				error = "Model-pair metadata write failed."
			file.close()
	var previous := destination + ".replaced-" + str(Time.get_ticks_usec())
	if error.is_empty() and replace and DirAccess.rename_absolute(destination, previous) != OK:
		error = "Cannot stage corrupt model-pair replacement."
	if error.is_empty() and DirAccess.rename_absolute(staging, destination) != OK:
		error = "Cannot publish model-pair object."
		if replace:
			DirAccess.rename_absolute(previous, destination)
	if not error.is_empty():
		DirAccess.remove_absolute(pack)
		DirAccess.remove_absolute(staging.path_join("bundle.json"))
		DirAccess.remove_absolute(staging)
		return _failure(error)
	if replace:
		DirAccess.remove_absolute(previous.path_join("model-pair.pck"))
		DirAccess.remove_absolute(previous.path_join("bundle.json"))
		DirAccess.remove_absolute(previous)
	return {"error": "", "manifest": asset.pair_manifest}

static func object_check(directory: String, asset: Dictionary) -> Dictionary:
	var folder := DirAccess.open(directory)
	if folder == null or not folder.get_directories().is_empty() or folder.is_link("model-pair.pck") or folder.is_link("bundle.json"):
		return _failure("Invalid model-pair object directory.")
	var files := folder.get_files()
	files.sort()
	if files != PackedStringArray(["bundle.json", "model-pair.pck"]):
		return _failure("Unexpected model-pair object files.")
	var file := FileAccess.open(directory.path_join("bundle.json"), FileAccess.READ)
	if file == null or file.get_length() > MAX_MANIFEST or JSON.parse_string(file.get_as_text()) != asset:
		return _failure("Invalid model-pair object manifest.")
	return inspect(directory.path_join("model-pair.pck"), asset)

static func catalog_entries(asset: Dictionary, directory: String) -> Array:
	var result := []
	for appearance: Dictionary in asset.appearances:
		result.append({"species": str(appearance.runtime_identity).trim_suffix("@shiny"), "variant": appearance.variant,
			"runtime_schema": 1, "runtime_path": str(asset.pair_manifest.resource_root).path_join(appearance.runtime_path),
			"runtime_sha256": appearance.runtime_sha256, "bytes": appearance.bytes,
			"pack_path": ProjectSettings.globalize_path(directory.path_join("model-pair.pck")), "pair_asset": asset.duplicate(true)})
	return result

static func budget(asset: Dictionary, variant: String) -> int:
	var bytes := 0
	for file: Dictionary in asset.pair_manifest.files:
		if file.path.begins_with("textures/") or file.path == "models/" + variant + ".scn":
			bytes += int(file.bytes)
	for appearance: Dictionary in asset.appearances:
		if appearance.variant == variant:
			bytes = maxi(bytes, int(appearance.cache_source_bytes))
	return bytes

static func mount_checked(path: String, asset: Dictionary, checked: Dictionary) -> String:
	if not Thread.is_main_thread():
		return "Model-pair mounting requires the main thread."
	if not str(checked.get("error", "invalid")).is_empty() or checked.get("manifest") != asset.get("pair_manifest") or checked.get("sha256") != asset.get("sha256") or checked.get("path") != ProjectSettings.globalize_path(path):
		return "Model-pair pack was not verified."
	var resource_root: String = asset.pair_manifest.resource_root
	var digest: String = asset.sha256
	if namespaces.has(resource_root) and namespaces[resource_root] != digest:
		return "Model-pair resource_root already belongs to another pack."
	if closed.has(digest):
		return "" # The complete physical hash was checked again by the caller.
	if not mounted.has(digest):
		for name: String in checked.members:
			if FileAccess.file_exists(resource_root.path_join(name)):
				return "Model-pair resource_root collides with existing resources."
		if not ProjectSettings.load_resource_pack(path, false):
			return "Cannot mount verified model-pair pack."
		# Mounts cannot be undone. Protect the file even if closure validation fails.
		mounts_lock.lock()
		mounted[digest] = ProjectSettings.globalize_path(path)
		mounts_lock.unlock()
		namespaces[resource_root] = digest
	var referenced := {}
	for row: Dictionary in asset.pair_manifest.files:
		for dependency: String in ResourceLoader.get_dependencies(resource_root.path_join(row.path)):
			var target := dependency.get_slice("::", 2) if dependency.contains("::") else dependency
			if not target.begins_with(resource_root + "/"):
				return "Model-pair dependency escapes its resource_root."
			var relative := target.trim_prefix(resource_root + "/")
			if not row.path.begins_with("models/") or not relative.begins_with("textures/") or not checked.members.has(relative):
				return "Invalid model-pair dependency graph."
			referenced[relative] = true
	for name: String in checked.members:
		if name.begins_with("textures/") and not referenced.has(name):
			return "Unreferenced model-pair texture."
	closed[digest] = true
	return ""

static func protects(directory: String) -> bool:
	if directory.is_empty():
		return false
	var root := ProjectSettings.globalize_path(directory).simplify_path().trim_suffix("/") + "/"
	mounts_lock.lock()
	var paths := mounted.values()
	mounts_lock.unlock()
	for path: String in paths:
		if path.simplify_path().begins_with(root):
			return true
	return false
