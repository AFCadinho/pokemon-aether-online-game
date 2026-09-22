extends RefCounted
## Transactional local store for optional immutable asset bundles.
const Index = preload("asset_bundle_index.gd")
const STATE_SCHEMA := 1
const STATE_KIND := "pokeaether-installed-asset-bundles"
const BUNDLE_SCHEMA := 1
const BUNDLE_KIND := "pokeaether-asset-bundle"
const MAX_JSON := 1024 * 1024
const MAX_FILE := 128 * 1024 * 1024
const MAX_ARCHIVE := 512 * 1024 * 1024
const MAX_FILES := 10

var root: String


func _init(directory: String = "user://asset-bundles-v1") -> void:
	root = ProjectSettings.globalize_path(directory)


static func _hex(value: String) -> bool:
	return Index._hex(value)


static func _hash(data: PackedByteArray) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA256)
	hashing.update(data)
	return hashing.finish().hex_encode()


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_JSON:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


static func _safe_relative(path: String) -> bool:
	if path.is_empty() or path.is_absolute_path() or path.contains("\\") or path.contains(":"):
		return false
	for part in path.split("/"):
		if part in ["", ".", ".."]:
			return false
	return true


func _path_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path)


func _objects_root() -> String:
	return root.path_join("objects")


func _generations_root() -> String:
	return root.path_join("generations")


func _pointer_path(previous := false) -> String:
	return root.path_join("active.previous.json" if previous else "active.json")


func active_generation() -> String:
	for previous in [false, true]:
		var pointer := _read_json(_pointer_path(previous))
		var generation := str(pointer.get("generation", ""))
		if _hex(generation) and _validate_generation(generation):
			return generation
	return ""


func state() -> Dictionary:
	var generation := active_generation()
	return _read_json(_generations_root().path_join(generation).path_join("installed-state.json")) if not generation.is_empty() else _empty_state("")


func catalog_path() -> String:
	var generation := active_generation()
	if generation.is_empty():
		return ""
	return _generations_root().path_join(generation).path_join("runtime-catalog.json")


func state_sha256() -> String:
	var generation := active_generation()
	return FileAccess.get_sha256(_generations_root().path_join(generation).path_join("installed-state.json")) if not generation.is_empty() else ""


func plan(index: Dictionary, requested_ids: Array[String]) -> Dictionary:
	return Index.plan(index, state(), requested_ids)


func install_archive(index: Dictionary, asset_id: String, archive_path: String) -> Dictionary:
	var index_error := Index.validate(index)
	if not index_error.is_empty():
		return {"error": index_error}
	var indexed: Dictionary = Index.by_id(index)
	if not indexed.has(asset_id):
		return {"error": "Asset is absent from the index."}
	var asset: Dictionary = indexed[asset_id]
	var current: Dictionary = state().get("assets", {}).get(asset_id, {})
	if not current.is_empty() and current.get("version") == asset.version and current.get("archive_sha256") != asset.sha256:
		return {"error": "An installed asset version cannot change its immutable checksum."}
	for dependency: String in asset.get("dependencies", []):
		if not state().get("assets", {}).has(dependency):
			return {"error": "Asset dependency is not installed: " + dependency}
	var archive := FileAccess.open(archive_path, FileAccess.READ)
	if archive == null or archive.get_length() != int(asset.size_bytes) or archive.get_length() > MAX_ARCHIVE:
		return {"error": "Bundle archive size mismatch."}
	archive.close()
	if FileAccess.get_sha256(archive_path) != str(asset.sha256):
		return {"error": "Bundle archive checksum mismatch."}
	var sizes := _archive_entries(archive_path)
	if sizes.is_empty():
		return {"error": "Invalid or unsafe bundle archive."}
	var reader := ZIPReader.new()
	if reader.open(archive_path) != OK:
		return {"error": "Cannot open bundle archive."}
	var archive_files := reader.get_files()
	var archive_directory_matches := archive_files.size() == sizes.size()
	for name: String in archive_files:
		if not sizes.has(name):
			archive_directory_matches = false
			break
	if not archive_directory_matches:
		reader.close()
		return {"error": "Bundle archive directory mismatch."}
	var manifest_bytes := reader.read_file("bundle.json")
	if manifest_bytes.size() != sizes.get("bundle.json", -1):
		reader.close()
		return {"error": "Invalid bundle manifest."}
	var parsed: Variant = JSON.parse_string(manifest_bytes.get_string_from_utf8())
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	var manifest_error := _validate_bundle_manifest(manifest, asset, sizes)
	if not manifest_error.is_empty():
		reader.close()
		return {"error": manifest_error}
	if DirAccess.make_dir_recursive_absolute(_objects_root()) != OK or DirAccess.make_dir_recursive_absolute(_generations_root()) != OK:
		reader.close()
		return {"error": "Cannot create asset store."}
	var destination := _objects_root().path_join(str(asset.sha256))
	if DirAccess.dir_exists_absolute(destination):
		reader.close()
		if not _validate_object(str(asset.sha256), manifest):
			return {"error": "Existing immutable bundle object is invalid."}
	else:
		var staging := root.path_join("staging").path_join(".install-" + str(Time.get_ticks_usec()))
		if DirAccess.make_dir_recursive_absolute(staging) != OK:
			reader.close()
			return {"error": "Cannot stage asset bundle."}
		var extract_error := _extract(reader, sizes, manifest_bytes, staging)
		reader.close()
		if not extract_error.is_empty():
			_remove_tree(staging)
			return {"error": extract_error}
		if DirAccess.rename_absolute(staging, destination) != OK:
			_remove_tree(staging)
			return {"error": "Cannot publish immutable bundle object."}
	var next := state().duplicate(true)
	next["catalog_revision"] = str(index.catalog_revision)
	var installed: Dictionary = next.get("assets", {}).duplicate(true)
	installed[asset_id] = _state_entry(asset, manifest)
	next["assets"] = installed
	var activation := _write_generation(next)
	if not activation.is_empty():
		return {"error": activation}
	return {"error": "", "asset_id": asset_id, "generation": active_generation(), "catalog_path": catalog_path()}


func remove(asset_id: String) -> Dictionary:
	var next := state().duplicate(true)
	var installed: Dictionary = next.get("assets", {}).duplicate(true)
	if not installed.has(asset_id):
		return {"error": "", "changed": false}
	for other_id: String in installed:
		if other_id != asset_id and asset_id in installed[other_id].get("dependencies", []):
			return {"error": "Asset is still required by another installed bundle.", "changed": false}
	installed.erase(asset_id)
	next["assets"] = installed
	var activation := _write_generation(next)
	return {"error": activation, "changed": activation.is_empty()}


func garbage_collect() -> Dictionary:
	var generation := active_generation()
	if generation.is_empty():
		return {"error": "No valid active asset state.", "removed_objects": 0, "removed_generations": 0}
	var current := state()
	var referenced := {}
	for asset: Dictionary in current.get("assets", {}).values():
		referenced[str(asset.get("archive_sha256", ""))] = true
	DirAccess.remove_absolute(_pointer_path(true))
	var removed_generations := 0
	var generations := DirAccess.open(_generations_root())
	if generations != null:
		for name in generations.get_directories():
			if name != generation and _remove_tree(_generations_root().path_join(name)):
				removed_generations += 1
	var removed_objects := 0
	var objects := DirAccess.open(_objects_root())
	if objects != null:
		for name in objects.get_directories():
			if not referenced.has(name) and _remove_tree(_objects_root().path_join(name)):
				removed_objects += 1
	return {"error": "", "removed_objects": removed_objects, "removed_generations": removed_generations}


func _empty_state(revision: String) -> Dictionary:
	return {"schema": STATE_SCHEMA, "kind": STATE_KIND, "catalog_revision": revision, "assets": {}}


func _state_entry(asset: Dictionary, manifest: Dictionary) -> Dictionary:
	return {
		"asset_id": asset.asset_id,
		"asset_type": asset.asset_type,
		"species_id": asset.species_id,
		"form_id": asset.form_id,
		"version": asset.version,
		"archive_sha256": asset.sha256,
		"object_key": asset.object_key,
		"dependencies": asset.get("dependencies", []).duplicate(),
		"appearances": manifest.appearances.duplicate(true),
	}


func _validate_bundle_manifest(manifest: Dictionary, asset: Dictionary, sizes: Dictionary) -> String:
	if manifest.get("schema") != BUNDLE_SCHEMA or manifest.get("kind") != BUNDLE_KIND:
		return "Unsupported bundle manifest."
	for field in ["asset_id", "asset_type", "species_id", "form_id", "version"]:
		if manifest.get(field) != asset.get(field):
			return "Bundle manifest does not match the content index."
	if manifest.get("dependencies", []) != asset.get("dependencies", []):
		return "Bundle dependencies do not match the content index."
	var appearances: Variant = manifest.get("appearances")
	if not appearances is Array or appearances.size() != asset.appearances.size():
		return "Bundle appearance list does not match the content index."
	var indexed := {}
	for expected: Dictionary in asset.appearances:
		indexed[str(expected.variant)] = expected
	var paths := {"bundle.json": true}
	for value: Variant in appearances:
		if not value is Dictionary:
			return "Invalid bundle appearance."
		var appearance: Dictionary = value
		var variant := str(appearance.get("variant", ""))
		var expected: Dictionary = indexed.get(variant, {})
		var path := str(appearance.get("runtime_path", ""))
		var bytes: Variant = appearance.get("bytes")
		if expected.is_empty() or appearance.get("runtime_identity") != expected.get("runtime_identity") or appearance.get("runtime_sha256") != expected.get("runtime_sha256"):
			return "Bundle appearance identity does not match the content index."
		if not _safe_relative(path) or not path.begins_with("models/") or not path.ends_with(".scn") or paths.has(path):
			return "Bundle contains an unsafe or duplicate model path."
		if not (bytes is int or bytes is float) or not is_finite(float(bytes)) or bytes != floor(float(bytes)) or bytes < 1 or bytes > MAX_FILE or sizes.get(path, -1) != int(bytes):
			return "Bundle model size is invalid."
		if not _hex(str(appearance.runtime_sha256)):
			return "Bundle model checksum is invalid."
		paths[path] = true
	if paths.size() != sizes.size():
		return "Bundle archive contains undeclared files."
	return ""


func _extract(reader: ZIPReader, sizes: Dictionary, manifest_bytes: PackedByteArray, staging: String) -> String:
	for name: String in sizes:
		var payload := manifest_bytes if name == "bundle.json" else reader.read_file(name)
		if payload.size() != sizes[name]:
			return "Bundle extraction size mismatch."
		var output := staging.path_join(name)
		if DirAccess.make_dir_recursive_absolute(output.get_base_dir()) != OK:
			return "Cannot create bundle staging folder."
		var file := FileAccess.open(output, FileAccess.WRITE)
		if file == null:
			return "Cannot write staged bundle."
		file.store_buffer(payload)
		var write_error := file.get_error()
		file.close()
		if write_error != OK or FileAccess.get_sha256(output) != _hash(payload):
			return "Staged bundle verification failed."
	return ""


func _validate_object(archive_sha256: String, expected_manifest := {}) -> bool:
	if not _hex(archive_sha256):
		return false
	var directory := _objects_root().path_join(archive_sha256)
	var object_parent := DirAccess.open(_objects_root())
	if object_parent == null or object_parent.is_link(archive_sha256):
		return false
	var object_directory := DirAccess.open(directory)
	if object_directory == null or object_directory.is_link("bundle.json"):
		return false
	var manifest := _read_json(directory.path_join("bundle.json"))
	if manifest.is_empty() or (not expected_manifest.is_empty() and manifest != expected_manifest):
		return false
	for appearance: Dictionary in manifest.get("appearances", []):
		var path := str(appearance.get("runtime_path", ""))
		var absolute := directory.path_join(path)
		var models := DirAccess.open(directory)
		var model_directory := DirAccess.open(directory.path_join("models"))
		if models == null or models.is_link("models") or model_directory == null or model_directory.is_link(path.get_file()):
			return false
		var file := FileAccess.open(absolute, FileAccess.READ)
		if not _safe_relative(path) or file == null or file.get_length() != int(appearance.get("bytes", -1)):
			return false
		file.close()
		if FileAccess.get_sha256(absolute) != str(appearance.get("runtime_sha256", "")):
			return false
	if object_directory.get_files() != PackedStringArray(["bundle.json"]):
		return false
	var declared_files: Array[String] = []
	for appearance: Dictionary in manifest.get("appearances", []):
		declared_files.append(str(appearance.get("runtime_path", "")).get_file())
	declared_files.sort()
	var installed_files: Array[String] = []
	for file_name: String in DirAccess.get_files_at(directory.path_join("models")):
		installed_files.append(file_name)
	installed_files.sort()
	if installed_files != declared_files:
		return false
	return true


func _write_generation(next: Dictionary) -> String:
	if next.get("schema") != STATE_SCHEMA or next.get("kind") != STATE_KIND or not next.get("assets") is Dictionary:
		return "Invalid installed state."
	var state_text := JSON.stringify(_sorted_state(next), "\t") + "\n"
	var generation := state_text.sha256_text()
	var directory := _generations_root().path_join(generation)
	if not DirAccess.dir_exists_absolute(directory):
		var staging := _generations_root().path_join(".generation-" + str(Time.get_ticks_usec()))
		if DirAccess.make_dir_recursive_absolute(staging) != OK:
			return "Cannot stage installed state."
		var state_error := _write_text(staging.path_join("installed-state.json"), state_text)
		var catalog_error := _write_text(staging.path_join("runtime-catalog.json"), JSON.stringify(_runtime_catalog(next), "\t") + "\n")
		if state_error != OK or catalog_error != OK:
			_remove_tree(staging)
			return "Cannot write installed state."
		if DirAccess.rename_absolute(staging, directory) != OK:
			_remove_tree(staging)
			return "Cannot publish installed-state generation."
	if not _validate_generation(generation):
		return "Generated installed state failed validation."
	return _activate_generation(generation)


func _sorted_state(value: Dictionary) -> Dictionary:
	var clean := _empty_state(str(value.get("catalog_revision", "")))
	var ids: Array = value.get("assets", {}).keys()
	ids.sort()
	for asset_id: String in ids:
		clean.assets[asset_id] = value.assets[asset_id]
	return clean


func _runtime_catalog(value: Dictionary) -> Array:
	var result := []
	var ids: Array = value.get("assets", {}).keys()
	ids.sort()
	for asset_id: String in ids:
		var asset: Dictionary = value.assets[asset_id]
		var object_root := _objects_root().path_join(str(asset.archive_sha256))
		for appearance: Dictionary in asset.appearances:
			var identity := str(appearance.runtime_identity)
			result.append({
				"species": identity.trim_suffix("@shiny"),
				"variant": appearance.variant,
				"runtime_schema": 1,
				"runtime_path": object_root.path_join(str(appearance.runtime_path)),
				"runtime_sha256": appearance.runtime_sha256,
				"bytes": appearance.bytes,
			})
	return result


func _validate_generation(generation: String) -> bool:
	var directory := _generations_root().path_join(generation)
	var state_path := directory.path_join("installed-state.json")
	var state_data := _read_json(state_path)
	if state_data.get("schema") != STATE_SCHEMA or state_data.get("kind") != STATE_KIND or not state_data.get("assets") is Dictionary:
		return false
	if FileAccess.get_file_as_string(state_path).sha256_text() != generation:
		return false
	for asset_id: String in state_data.assets:
		var asset: Dictionary = state_data.assets[asset_id]
		var object_manifest := _read_json(_objects_root().path_join(str(asset.get("archive_sha256", ""))).path_join("bundle.json"))
		if object_manifest.get("asset_id") != asset_id or object_manifest.get("asset_type") != asset.get("asset_type") or object_manifest.get("species_id") != asset.get("species_id") or object_manifest.get("form_id") != asset.get("form_id") or object_manifest.get("version") != asset.get("version"):
			return false
		if object_manifest.get("dependencies", []) != asset.get("dependencies", []) or object_manifest.get("appearances", []) != asset.get("appearances", []):
			return false
		if not _validate_object(str(asset.get("archive_sha256", "")), object_manifest):
			return false
	var catalog_path := directory.path_join("runtime-catalog.json")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(catalog_path))
	if not parsed is Array:
		return false
	var expected := _runtime_catalog(state_data)
	if parsed.size() != expected.size():
		return false
	for index in expected.size():
		if not parsed[index] is Dictionary:
			return false
		for field in ["species", "variant", "runtime_path", "runtime_sha256"]:
			if str(parsed[index].get(field, "")) != str(expected[index].get(field, "")):
				return false
		if int(parsed[index].get("runtime_schema", 0)) != 1 or int(parsed[index].get("bytes", 0)) != int(expected[index].bytes):
			return false
	return true


func _activate_generation(generation: String) -> String:
	if not _validate_generation(generation):
		return "Cannot activate an invalid generation."
	if DirAccess.make_dir_recursive_absolute(root) != OK:
		return "Cannot access asset store."
	var next := root.path_join(".active-next-" + str(Time.get_ticks_usec()))
	if _write_text(next, JSON.stringify({"generation": generation}) + "\n") != OK:
		return "Cannot stage active-state pointer."
	var active := _pointer_path()
	var previous := _pointer_path(true)
	DirAccess.remove_absolute(previous)
	if FileAccess.file_exists(active) and DirAccess.rename_absolute(active, previous) != OK:
		DirAccess.remove_absolute(next)
		return "Cannot preserve previous active state."
	if DirAccess.rename_absolute(next, active) != OK:
		if FileAccess.file_exists(previous):
			DirAccess.rename_absolute(previous, active)
		DirAccess.remove_absolute(next)
		return "Cannot activate installed state."
	return ""


func _write_text(path: String, value: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(value)
	var error := file.get_error()
	file.close()
	return error


func _remove_tree(path: String) -> bool:
	var directory := DirAccess.open(path)
	if directory == null:
		return not _path_exists(path)
	for file in directory.get_files():
		if directory.is_link(file) or DirAccess.remove_absolute(path.path_join(file)) != OK:
			return false
	for child in directory.get_directories():
		if directory.is_link(child) or not _remove_tree(path.path_join(child)):
			return false
	return DirAccess.remove_absolute(path) == OK


# Inspect headers before ZIPReader allocates decompressed buffers. ZIP64,
# multipart, encrypted archives, symlinks and data descriptors are rejected.
static func _archive_entries(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 22 or file.get_length() > MAX_ARCHIVE:
		return {}
	var tail_start := maxi(0, file.get_length() - 65557)
	file.seek(tail_start)
	var tail := file.get_buffer(file.get_length() - tail_start)
	var end := -1
	for index in range(tail.size() - 22, -1, -1):
		if tail.decode_u32(index) == 0x06054b50 and index + 22 + tail.decode_u16(index + 20) == tail.size():
			end = index
			break
	if end < 0 or tail.decode_u16(end + 4) != 0 or tail.decode_u16(end + 6) != 0:
		return {}
	var count := tail.decode_u16(end + 10)
	var offset := tail.decode_u32(end + 16)
	if count < 2 or count > MAX_FILES or count != tail.decode_u16(end + 8) or offset >= tail_start + end:
		return {}
	file.seek(offset)
	var entries := {}
	var total := 0
	for ignored in count:
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
		if entries.has(name) or not _safe_relative(name) or size < 1 or size > MAX_FILE:
			return {}
		if name != "bundle.json" and (not name.begins_with("models/") or not name.ends_with(".scn")):
			return {}
		total += size
		if total > MAX_ARCHIVE:
			return {}
		var next := file.get_position() + header.decode_u16(30) + header.decode_u16(32)
		var local_offset := header.decode_u32(42)
		if local_offset + 30 > offset:
			return {}
		file.seek(local_offset)
		var local := file.get_buffer(30)
		if local.decode_u32(0) != 0x04034b50 or local.decode_u16(6) != flags or local.decode_u16(8) != method or local.decode_u32(14) != header.decode_u32(16) or local.decode_u32(18) != header.decode_u32(20) or local.decode_u32(22) != size:
			return {}
		if file.get_buffer(local.decode_u16(26)).get_string_from_utf8() != name:
			return {}
		if file.get_position() + local.decode_u16(28) + header.decode_u32(20) > offset:
			return {}
		entries[name] = size
		file.seek(next)
	if file.get_position() != offset + tail.decode_u32(end + 12) or file.get_position() > tail_start + end:
		return {}
	return entries if entries.has("bundle.json") else {}
