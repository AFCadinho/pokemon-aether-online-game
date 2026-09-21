extends RefCounted
const Effect = preload("res://scripts/battle/battle_ui/material_effect.gd")
var failure := ""

func _texture(record: Dictionary) -> Texture2D:
	var path := str(record.get("path", ""))
	if not path.is_absolute_path() or FileAccess.get_sha256(path) != record.get("sha256", "") or str(record.get("sha256", "")).length() != 64:
		failure = "Effect texture hash mismatch"
		return null
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		failure = "Missing effect texture"
		return null
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)

func _bind(node: Node, materials: Dictionary, used: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if original != null and materials.has(original.resource_name):
				node.set_surface_override_material(surface, materials[original.resource_name])
				used[original.resource_name] = true
	for child in node.get_children():
		_bind(child, materials, used)

func apply(node: Node, manifest: Dictionary, glb_hash: String) -> bool:
	failure = ""
	if manifest.get("schema") != 1 or manifest.get("glb_sha256") != glb_hash or not manifest.get("records") is Array:
		failure = "Invalid effect manifest or GLB binding"
		return false
	var materials := {}
	for raw in manifest.records:
		if not raw is Dictionary or not raw.get("material") is String or materials.has(raw.material) or raw.get("profile") not in ["scvi_nondirectional_layered_displacement_v1", "scvi_unlit_layered_displacement_v1"]:
			failure = "Unknown or duplicate effect profile"
			return false
		var material := ShaderMaterial.new()
		material.shader = Shader.new()
		material.shader.code = Effect.SHADER.code # Embed; no external runtime shader dependency.
		material.set_meta(Effect.META, 1)
		for key in ["loop_seconds", "height", "intensity", "alpha_cutoff"]:
			var value: Variant = raw.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or (key == "loop_seconds" and value <= 0):
				failure = "Invalid effect scalar"
				return false
			material.set_shader_parameter(key, float(value))
		if raw.get("use_uv2") != (raw.profile == "scvi_nondirectional_layered_displacement_v1"):
			failure = "Invalid effect UV binding"
			return false
		material.set_shader_parameter("use_uv2", raw.use_uv2)
		for mapping in [["color", "color_tex"], ["LayerMaskMap", "mask_tex"], ["DisplacementMap", "displacement_tex"]]:
			if not raw.get(mapping[0]) is Dictionary:
				failure = "Missing effect texture record"
				return false
			var texture := _texture(raw[mapping[0]])
			if texture == null:
				return false
			material.set_shader_parameter(mapping[1], texture)
		if not raw.get("tracks") is Dictionary:
			failure = "Missing effect UV tracks"
			return false
		for mapping in [["UVScaleOffset", "mask"], ["UVScaleOffset3", "displacement"]]:
			var channels: Variant = raw.tracks.get(mapping[0])
			if not channels is Array or channels.size() != 4:
				failure = "Invalid effect UV channels"
				return false
			var start := Vector4()
			var end := Vector4()
			for i in 4:
				if not channels[i] is Array or channels[i].size() != 2:
					failure = "Invalid effect UV endpoints"
					return false
				for v in channels[i]:
					if not (v is int or v is float) or not is_finite(float(v)):
						failure = "Nonfinite effect UV endpoint"
						return false
				start[i] = channels[i][0]
				end[i] = channels[i][1]
			if start.x <= 0 or start.y <= 0 or start.x != end.x or start.y != end.y or absf((end.z - start.z) - roundf(end.z - start.z)) > 0.00001 or absf((end.w - start.w) - roundf(end.w - start.w)) > 0.00001:
				failure = "Nonperiodic effect UV loop"
				return false
			material.set_shader_parameter(mapping[1] + "_start", start)
			material.set_shader_parameter(mapping[1] + "_end", end)
		materials[raw.material] = material
	var used := {}
	_bind(node, materials, used)
	if materials.is_empty() or used.size() != materials.size():
		failure = "Effect material not found on model"
		return false
	return true
