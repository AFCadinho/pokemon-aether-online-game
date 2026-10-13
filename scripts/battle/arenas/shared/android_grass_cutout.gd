extends RefCounted
## Reject fully masked grass pixels before calculating their colour.
## Explicit gradients preserve the original noise LOD across discarded quads.
static func shader_code(source: String) -> String:
	var opening := "void fragment() {"
	var noise := "texture(variation_noise, world_xz * variation_scale).r"
	var alpha := "ALPHA = texture(alpha_mask, UV).a;"
	if source.count(opening) != 1 or source.count(noise) != 1 or source.count(alpha) != 1:
		return ""
	var early := opening + "\n\tvec2 cutout_noise_uv = world_xz * variation_scale;\n\tvec2 cutout_noise_dx = dFdx(cutout_noise_uv);\n\tvec2 cutout_noise_dy = dFdy(cutout_noise_uv);\n\tfloat cutout_alpha = texture(alpha_mask, UV).a;\n\tif (cutout_alpha < alpha_threshold) { discard; }"
	return source.replace(opening, early).replace(noise, "textureGrad(variation_noise, cutout_noise_uv, cutout_noise_dx, cutout_noise_dy).r").replace(alpha, "ALPHA = cutout_alpha;")

static func material(original: Material) -> Material:
	if not original is ShaderMaterial or original.shader == null:
		return null
	var code := shader_code(original.shader.code)
	if code.is_empty():
		return null
	var copy: ShaderMaterial = original.duplicate()
	var shader := Shader.new()
	shader.code = code
	copy.shader = shader
	return copy
