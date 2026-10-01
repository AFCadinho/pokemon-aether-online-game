extends RefCounted
const SHADER = preload("res://scripts/battle/battle_ui/material_effect.gdshader")
const SAMPLED_SHADER = preload("res://scripts/battle/battle_ui/material_effect_sampled.gdshader")
const STATIC_SHADER = preload("res://scripts/battle/battle_ui/material_effect_static.gdshader")
const RIM_SMOKE_SHADER = preload("res://scripts/battle/battle_ui/material_effect_rim_smoke.gdshader")
const LIT_SHADER = preload("res://scripts/battle/battle_ui/material_effect_lit.gdshader")
const FIRE_SHADER = preload("res://scripts/battle/battle_ui/material_fire.gdshader")
const META := "pokeaether_material_effect"
static func _fire_parameter(material: ShaderMaterial, key: String) -> Variant:
	# ShaderMaterial reports null for an unset uniform in the headless renderer.
	# Defaults are safe here because the entire shader code is matched exactly.
	const DEFAULTS = {"loop_seconds": 2.0, "coverage_gain": 1.0, "tongue_base": 0.3,
		"tongue_span": 0.5, "layer_opacity": 1.0, "review_time": -1.0,
		"uv_transform": Vector4(1, 1, 0, 0), "fire_edge": Vector3(1, 0.23, 0.015),
		"fire_core": Vector3(1, 0.82, 0.08), "enabled": true,
		"retain_coverage": false, "shape_flames": false}
	var value: Variant = material.get_shader_parameter(key)
	return DEFAULTS.get(key) if value == null else value

static func _fire_valid(material: ShaderMaterial) -> bool:
	# Exact reviewed shader code, embedded maps and bounded parameters. This also
	# accepts the already-reviewed standalone scenes without rewriting their hashes.
	for key in ["coverage_tex", "noise_tex"]:
		if not _fire_parameter(material, key) is Texture2D:
			return false
	for key in ["loop_seconds", "coverage_gain", "tongue_base", "tongue_span", "layer_opacity", "review_time"]:
		var value: Variant = _fire_parameter(material, key)
		if not (value is int or value is float) or not is_finite(float(value)):
			return false
		if key == "loop_seconds" and (float(value) <= 0.0 or float(value) > 60.0):
			return false
		if key != "loop_seconds" and key != "review_time" and float(value) < 0.0:
			return false
	if float(_fire_parameter(material, "review_time")) != -1.0:
		return false # Gameplay must use the live shader clock.
	var uv: Variant = _fire_parameter(material, "uv_transform")
	if not uv is Vector4 or not uv.is_finite() or uv.x <= 0.0 or uv.y <= 0.0:
		return false
	for key in ["fire_edge", "fire_core"]:
		var colour: Variant = _fire_parameter(material, key)
		if not colour is Vector3 or not colour.is_finite():
			return false
		if minf(colour.x, minf(colour.y, colour.z)) < 0.0 or maxf(colour.x, maxf(colour.y, colour.z)) > 1.0:
			return false
	for key in ["enabled", "retain_coverage", "shape_flames"]:
		if not _fire_parameter(material, key) is bool:
			return false
	return true

static func valid(material: Material) -> bool:
	if material is ShaderMaterial and material.shader != null and material.shader.code == FIRE_SHADER.code:
		return _fire_valid(material)
	if not material is ShaderMaterial or material.get_meta(META, 0) != 1 or material.shader == null or material.shader.code not in [SHADER.code, SAMPLED_SHADER.code, STATIC_SHADER.code, RIM_SMOKE_SHADER.code, LIT_SHADER.code]:
		return false
	if material.shader.code == SAMPLED_SHADER.code and not material.get_shader_parameter("uv_samples") is Texture2D:
		return false
	for key in ["color_tex", "mask_tex", "displacement_tex"]:
		if not material.get_shader_parameter(key) is Texture2D:
			return false
	var seconds: Variant = material.get_shader_parameter("loop_seconds")
	return (seconds is int or seconds is float) and is_finite(float(seconds)) and float(seconds) > 0
