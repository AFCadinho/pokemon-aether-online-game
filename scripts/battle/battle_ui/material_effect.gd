extends RefCounted
const SHADER = preload("res://scripts/battle/battle_ui/material_effect.gdshader")
const SAMPLED_SHADER = preload("res://scripts/battle/battle_ui/material_effect_sampled.gdshader")
const META := "pokeaether_material_effect"
static func valid(material: Material) -> bool:
	if not material is ShaderMaterial or material.get_meta(META, 0) != 1 or material.shader == null or material.shader.code not in [SHADER.code, SAMPLED_SHADER.code]:
		return false
	if material.shader.code == SAMPLED_SHADER.code and not material.get_shader_parameter("uv_samples") is Texture2D:
		return false
	for key in ["color_tex", "mask_tex", "displacement_tex"]:
		if not material.get_shader_parameter(key) is Texture2D:
			return false
	var seconds: Variant = material.get_shader_parameter("loop_seconds")
	return (seconds is int or seconds is float) and is_finite(float(seconds)) and float(seconds) > 0
