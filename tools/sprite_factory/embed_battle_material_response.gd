extends SceneTree
## Offline packaging of reviewed endpoint maps into self-contained model scenes.
## Never reads PNGs or source-material reports on the interactive battle thread.
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
var failure := ""

func _init() -> void:
	_run.call_deferred()

func _read(path: String) -> Variant:
	if path.is_empty() or not FileAccess.file_exists(path):
		return null
	return JSON.parse_string(FileAccess.get_file_as_string(path))

var packer := preload("material_response_pack.gd").new()

func _endpoints(records: Array, inputs: Array) -> Dictionary:
	var result := packer._endpoints(records, inputs)
	failure = packer.failure
	return result

func _embed(node: Node, materials: Dictionary) -> bool:
	var result := packer._embed(node, materials)
	failure = packer.failure
	return result

func _run() -> void:
	var source_path := OS.get_environment("POKEAETHER_3D_STAGE_REPORT")
	var output := OS.get_environment("POKEAETHER_RESPONSE_OUTPUT")
	var catalog: Variant = _read(source_path)
	var maps: Variant = _read(OS.get_environment("POKEAETHER_RESPONSE_MAPS"))
	var inputs: Variant = _read(OS.get_environment("POKEAETHER_RESPONSE_INPUTS"))
	if not catalog is Array or not maps is Dictionary or not inputs is Dictionary or output.is_empty() or output == source_path:
		push_error("Provide source runtime catalog, maps, inputs, and a distinct output report")
		quit(2)
		return
	var directory := output.get_basename() + "-models"
	DirAccess.make_dir_recursive_absolute(directory)
	var result := []
	for entry in catalog:
		var materials := _endpoints(maps.get(entry.species, []), inputs.get(entry.species, []))
		var packed := load(str(entry.runtime_path)) as PackedScene
		if materials.is_empty() or packed == null:
			push_error("Cannot prepare material response: " + failure)
			quit(2)
			return
		var node := packed.instantiate()
		if not _embed(node, materials):
			node.free()
			push_error(failure)
			quit(2)
			return
		node.set_meta(Response.META, 1)
		var prepared := PackedScene.new()
		var target := directory.path_join(str(entry.species) + ".scn")
		if prepared.pack(node) != OK or ResourceSaver.save(prepared, target, ResourceSaver.FLAG_COMPRESS) != OK:
			node.free()
			quit(2)
			return
		node.free()
		var record: Dictionary = entry.duplicate(true)
		record.runtime_path = target
		if record.get("provenance_schema", 0) == 1:
			record.runtime_sha256 = FileAccess.get_sha256(target)
		record.material_response_schema = 1
		result.append(record)
		print("RESPONSE_PACKED ", entry.species, " bytes=", FileAccess.open(target, FileAccess.READ).get_length())
	# Publish only after every model was successfully prepared.
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		quit(2)
		return
	file.store_string(JSON.stringify(result, "\t"))
	file.close()
	print("RESPONSE_REPORT ", output)
	quit()
