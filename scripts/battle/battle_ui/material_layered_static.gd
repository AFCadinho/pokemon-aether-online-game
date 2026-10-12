extends RefCounted
const SHADER = preload("res://scripts/battle/battle_ui/material_effect_layered_static.gdshader")

static func valid(material: Material) -> bool:
	if not material is ShaderMaterial or material.shader == null or material.shader.code != SHADER.code or material.get_meta("pokeaether_layered_static", 0) != 1:
		return false
	for key: String in ["color_tex", "mask_tex", "displacement_tex"]:
		if not material.get_shader_parameter(key) is Texture2D:
			return false
	for key: String in ["layer_1", "layer_2", "layer_3", "layer_4", "layer_scales", "mask_start", "mask_end", "displacement_start", "displacement_end"]:
		var value: Variant = material.get_shader_parameter(key)
		if not value is Vector4 or not value.is_finite():
			return false
		if key.begins_with("layer"):
			for i in 4:
				if value[i] < 0 or value[i] > 1: return false
	for prefix: String in ["mask", "displacement"]:
		if material.get_shader_parameter(prefix + "_start") != material.get_shader_parameter(prefix + "_end"):
			return false
	return material.get_shader_parameter("height") == 0.0 and material.get_shader_parameter("intensity") == 1.0 and material.get_shader_parameter("alpha_cutoff") == 0.0 and material.get_shader_parameter("loop_seconds") == 1.0 and material.get_shader_parameter("use_uv2") is bool
