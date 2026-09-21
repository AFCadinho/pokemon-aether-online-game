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

func _endpoints(records: Array, inputs: Array) -> Dictionary:
	var result := {}
	for record in records:
		# Schema 1 intentionally supports only the audited EASE white-to-black
		# ramp. Reject unimplemented graphs instead of guessing a similar look.
		if record.get("interpolation") != "EASE" or record.get("ramp") != [[0.5, [1.0, 1.0, 1.0, 1.0]], [1.0, [0.0, 0.0, 0.0, 1.0]]]:
			failure = "Unsupported source ramp"
			return {}
		var source := {}
		for input in inputs:
			if input.material == record.material:
				source = input.inputs
		if not source.has("IOR") or not source.has("SpecularMaskMap") or not source.IOR.links.is_empty() or not source.SpecularMaskMap.links.is_empty():
			failure = "Missing or nonconstant source IOR/specular input"
			return {}
		var ior := float(source.IOR.value)
		var level := float(source.SpecularMaskMap.value)
		var specular := sqrt(pow((ior - 1.0) / (ior + 1.0), 2.0) * 2.0 * level / 0.16)
		if not is_finite(specular) or specular < 0.0 or specular > 1.0:
			failure = "Source specular outside supported range"
			return {}
		var data := {"schema": 1, "specular": specular}
		for endpoint in [0, 1]:
			var image := Image.load_from_file(str(record.get(str(endpoint), "")))
			if image == null or image.is_empty():
				failure = "Missing endpoint image"
				return {}
			image.generate_mipmaps()
			data["endpoint_" + str(endpoint)] = ImageTexture.create_from_image(image)
		result[record.material] = data
	return result

func _embed(node: Node, materials: Dictionary) -> bool:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if not original is StandardMaterial3D or not materials.has(original.resource_name):
				failure = "No reviewed response for a model surface"
				return false
			# Schema 1 reproduces the audited opaque, nonmetallic surfaces only.
			if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or original.metallic != 0.0 or original.emission_enabled:
				failure = "Unsupported metallic/emissive/transparent source surface"
				return false
			var material := original.duplicate() as StandardMaterial3D
			material.set_meta(Response.META, materials[original.resource_name])
			node.set_surface_override_material(surface, material)
	for child in node.get_children():
		if not _embed(child, materials):
			return false
	return true

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
