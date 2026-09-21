extends RefCounted
const Response = preload("res://scripts/battle/battle_ui/material_response.gd")
var failure := ""

func _endpoints(records: Array, inputs: Array) -> Dictionary:
	var result := {}
	var seen_inputs := {}
	for input in inputs:
		if not input is Dictionary or not input.get("material") is String or not input.get("inputs") is Dictionary or seen_inputs.has(input.material):
			failure = "Invalid or duplicate response inputs"
			return {}
		seen_inputs[input.material] = true
	for record in records:
		if not record is Dictionary or not record.get("material") is String or result.has(record.material):
			failure = "Invalid or duplicate response material"
			return {}
		# Schema 1 intentionally supports only the audited EASE white-to-black
		# ramp. Reject unimplemented graphs instead of guessing a similar look.
		if record.get("interpolation") != "EASE" or record.get("ramp") != [[0.5, [1.0, 1.0, 1.0, 1.0]], [1.0, [0.0, 0.0, 0.0, 1.0]]]:
			failure = "Unsupported source ramp"
			return {}
		var source := {}
		for input in inputs:
			if not input is Dictionary or not input.get("inputs") is Dictionary:
				failure = "Invalid response inputs"
				return {}
			if input.material == record.material:
				source = input.inputs
		for key in ["IOR", "SpecularMaskMap"]:
			var spec: Variant = source.get(key)
			if not spec is Dictionary or spec.get("links") != [] or not (spec.get("value") is int or spec.get("value") is float):
				failure = "Missing or nonconstant source IOR/specular input"
				return {}
		var ior := float(source.IOR.value)
		var level := float(source.SpecularMaskMap.value)
		if not is_finite(ior) or ior <= 0 or not is_finite(level) or level < 0:
			failure = "Invalid source IOR/specular"
			return {}
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

func apply(node: Node, manifest: Dictionary, glb_hash: String) -> bool:
	failure = ""
	if manifest.get("schema") != 1 or manifest.get("glb_sha256") != glb_hash:
		failure = "Response does not match GLB"
		return false
	if not manifest.get("maps") is Array or not manifest.get("inputs") is Array:
		failure = "Missing response records"
		return false
	for record in manifest.get("maps", []):
		if not record is Dictionary:
			failure = "Invalid response record"
			return false
		for endpoint in ["0", "1"]:
			var path = str(record.get(endpoint, ""))
			if not path.is_absolute_path() or str(record.get(endpoint + "_sha256", "")).length() != 64 or FileAccess.get_sha256(path) != record[endpoint + "_sha256"]:
				failure = "Response endpoint hash mismatch"
				return false
	var materials := _endpoints(manifest.get("maps", []), manifest.get("inputs", []))
	if materials.is_empty() or not _embed(node, materials):
		return false
	node.set_meta(Response.META, 1)
	return true
