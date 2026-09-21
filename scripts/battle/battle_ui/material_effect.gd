extends RefCounted
const SHADER = preload("res://scripts/battle/battle_ui/material_effect.gdshader")
const META := "pokeaether_material_effect"
static func valid(material: Material) -> bool:
	if not material is ShaderMaterial or material.get_meta(META, 0) != 1 or material.shader == null or material.shader.code != SHADER.code:
		return false
	for key in ["color_tex", "mask_tex", "displacement_tex"]:
		if not material.get_shader_parameter(key) is Texture2D:
			return false
	var seconds: Variant = material.get_shader_parameter("loop_seconds")
	return (seconds is int or seconds is float) and is_finite(float(seconds)) and float(seconds) > 0
