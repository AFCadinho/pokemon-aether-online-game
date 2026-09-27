extends RefCounted
const Effect = preload("res://scripts/battle/battle_ui/material_effect.gd")
var failure := ""

func _samples(raw: Dictionary, material: ShaderMaterial) -> bool:
	if not raw.has("uv_samples"):
		return true # Existing affine manifests remain compatible.
	if not raw.uv_samples is Dictionary:
		failure = "Invalid effect UV samples"
		return false
	var rows := [raw.uv_samples.get("UVScaleOffset"), raw.uv_samples.get("UVScaleOffset3")]
	if not rows[0] is Array or not rows[1] is Array or rows[0].size() < 2 or rows[0].size() > 4096 or rows[1].size() != rows[0].size():
		failure = "Invalid effect sample dimensions"
		return false
	var image := Image.create(rows[0].size(), 2, false, Image.FORMAT_RGBAF)
	for row in 2:
		for frame in rows[row].size():
			var values: Variant = rows[row][frame]
			if not values is Array or values.size() != 4:
				failure = "Invalid effect sample channels"
				return false
			for value in values:
				if not (value is int or value is float) or not is_finite(float(value)):
					failure = "Nonfinite effect sample"
					return false
			if values[0] <= 0 or values[1] <= 0 or values[0] != rows[row][0][0] or values[1] != rows[row][0][1]:
				failure = "Invalid sampled UV scale"
				return false
			image.set_pixel(frame, row, Color(values[0], values[1], values[2], values[3]))
		var parameter: String = ["UVScaleOffset", "UVScaleOffset3"][row]
		for channel in 4:
			if rows[row][0][channel] != raw.tracks[parameter][channel][0] or rows[row][-1][channel] != raw.tracks[parameter][channel][1]:
				failure = "Sample endpoints differ from validated loop"
				return false
	material.set_shader_parameter("uv_samples", ImageTexture.create_from_image(image))
	material.set_shader_parameter("sampled_uv", true)
	return true

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

func _lit_surface(source: Material, target: ShaderMaterial) -> ShaderMaterial:
	if not source is StandardMaterial3D or source.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
		failure = "Lit displacement requires an opaque imported PBR surface"
		return null
	var result: ShaderMaterial = target.duplicate()
	for pair in [["albedo_color", "base_color"], ["roughness", "surface_roughness"], ["metallic", "surface_metallic"], ["metallic_specular", "surface_specular"], ["normal_scale", "normal_scale"], ["emission_energy_multiplier", "emission_energy"]]:
		result.set_shader_parameter(pair[1], source.get(pair[0]))
	result.set_shader_parameter("emission_color", source.emission if source.emission_enabled else Color.BLACK)
	for pair in [["normal_texture", "normal"], ["roughness_texture", "roughness"], ["metallic_texture", "metallic"], ["emission_texture", "emission"]]:
		var texture: Texture2D = source.get(pair[0])
		var enabled: bool = texture != null
		if pair[1] == "normal": enabled = enabled and source.normal_enabled
		if pair[1] == "emission": enabled = enabled and source.emission_enabled
		result.set_shader_parameter("has_" + pair[1], enabled)
		if enabled: result.set_shader_parameter(pair[1] + "_tex", texture)
	for prefix in ["roughness", "metallic"]:
		var channel: int = source.get(prefix + "_texture_channel")
		if channel < 0 or channel > 4:
			failure = "Unknown imported PBR channel"
			return null
		var weights := Vector4(0.3333333,0.3333333,0.3333333,0.0) if channel == 4 else Vector4.ZERO
		if channel < 4: weights[channel] = 1.0
		result.set_shader_parameter(prefix + "_channel", weights)
	return result

func _bind(node: Node, materials: Dictionary, used: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		for surface in node.mesh.get_surface_count():
			var original: Material = node.get_active_material(surface)
			if original != null and materials.has(original.resource_name):
				var replacement: ShaderMaterial = materials[original.resource_name]
				if replacement.shader.code == Effect.LIT_SHADER.code:
					replacement = _lit_surface(original, replacement)
					if replacement == null: return
				node.set_surface_override_material(surface, replacement)
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
		if not raw is Dictionary or not raw.get("material") is String or materials.has(raw.material) or raw.get("profile") not in ["scvi_nondirectional_layered_displacement_v1", "scvi_unlit_layered_displacement_v1", "scvi_unlit_layered_displacement_uv2_v1", "scvi_standard_displacement_review_v1"]:
			failure = "Unknown or duplicate effect profile"
			return false
		var material := ShaderMaterial.new()
		material.shader = Shader.new()
		if raw.profile == "scvi_standard_displacement_review_v1":
			if raw.has("authored_reconstruction") or not raw.get("use_uv2") is bool:
				failure = "Invalid lit displacement declaration"
				return false
			material.shader.code = Effect.LIT_SHADER.code
		elif raw.has("authored_reconstruction"):
			if raw.authored_reconstruction != "outward_rim_smoke_v1" or raw.profile != "scvi_nondirectional_layered_displacement_v1" or raw.has("uv_samples") or raw.has("static_source_material"):
				failure = "Unsupported authored effect reconstruction"
				return false
			material.shader.code = Effect.RIM_SMOKE_SHADER.code
		elif raw.has("static_source_material"):
			if raw.static_source_material != true or raw.has("uv_samples"):
				failure = "Invalid static effect declaration"
				return false
			material.shader.code = Effect.STATIC_SHADER.code
		else:
			material.shader.code = Effect.SAMPLED_SHADER.code if raw.has("uv_samples") else Effect.SHADER.code
		material.set_meta(Effect.META, 1)
		for key in ["loop_seconds", "height", "intensity", "alpha_cutoff"]:
			var value: Variant = raw.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0 or (key == "loop_seconds" and value <= 0):
				failure = "Invalid effect scalar"
				return false
			material.set_shader_parameter(key, float(value))
		if raw.profile != "scvi_standard_displacement_review_v1" and raw.get("use_uv2") != (raw.profile in ["scvi_nondirectional_layered_displacement_v1", "scvi_unlit_layered_displacement_uv2_v1"]):
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
			if start.x <= 0 or start.y <= 0 or start.x != end.x or start.y != end.y or (not raw.get("source_loop_endpoint_reset", false) and (absf((end.z - start.z) - roundf(end.z - start.z)) > 0.00001 or absf((end.w - start.w) - roundf(end.w - start.w)) > 0.00001)):
				failure = "Nonperiodic effect UV loop"
				return false
			if raw.get("static_source_material", false) and start != end:
				failure = "Static effect contains animated UV endpoints"
				return false
			material.set_shader_parameter(mapping[1] + "_start", start)
			material.set_shader_parameter(mapping[1] + "_end", end)
		if raw.get("source_loop_endpoint_reset", false) and not raw.has("uv_samples"):
			failure = "Source loop reset requires sampled UV tracks"
			return false
		if not _samples(raw, material):
			return false
		materials[raw.material] = material
	var used := {}
	_bind(node, materials, used)
	if not failure.is_empty():
		return false
	if materials.is_empty() or used.size() != materials.size():
		failure = "Effect material not found on model"
		return false
	return true
