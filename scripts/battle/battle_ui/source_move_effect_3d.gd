extends "res://scripts/battle/battle_ui/move_effect_3d.gd"
## SV textures and sampled colors with authored Godot motion, sharing the normal move clock.
## Ember is approved/live; Water Gun is enabled only by the offline comparison preview.
const SPRITES := {
	"ember_muzzle": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_fire0005.png"), Vector3(1.0, 1.0, 0.8174603), 8.0, false],
	"ember_core": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_fire0010.png"), Vector3(1.0, 0.43650791, 0.071428567), 4.0, false],
	"ember_tail": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_dust0702.png"), Vector3(1.0, 0.43650791, 0.071428567), 8.0, false],
	"ember_hit": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_fire0005.png"), Vector3(1.0, 1.0, 0.142), 8.0, false],
	"ember_sparks": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_fire0004.png"), Vector3(1.0, 0.556, 0.142), 8.0, false],
	"water_muzzle": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_fire0007.png"), Vector3(0.2, 0.506, 1.0), 8.0, false],
	"water_drop": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_water0009.png"), Vector3(0.4, 0.676, 1.0), 8.0, false],
	"water_splash": [preload("res://assets/battles/moves_3d/sv_source/cpt_2_water0013.png"), Vector3(0.35, 0.794, 1.0), 8.0, true],
}
const NOISE = preload("res://assets/battles/moves_3d/sv_source/cpt_3_smoke0207.png")
var sprite_shader: Shader
var sprite_templates := {}
var sprite_materials: Array[ShaderMaterial] = []
var sprite_keys: Array[String] = []
var quad := QuadMesh.new()
var beam_material: ShaderMaterial

func _init() -> void:
	# Arena camera updates at priority 10; billboards must sample its final pose.
	process_priority = 11
	quad.size = Vector2.ONE
	sprite_shader = Shader.new()
	sprite_shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D source_mask : filter_linear, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform float frames = 1.0;
uniform float frame_index = 0.0;
uniform float opacity = 1.0;
uniform bool source_alpha = false;
void fragment() {
	vec2 uv = vec2((UV.x + floor(frame_index)) / frames, UV.y);
	vec4 sample_color = texture(source_mask, uv);
	ALBEDO = tint * (source_alpha ? sample_color.r : 1.0);
	ALPHA = (source_alpha ? sample_color.a : sample_color.r) * opacity;
}
"""

func _source_sprite(point: Vector3, size: float, id: String, phase: float, alpha: float, facing: Basis, rotation_value := 0.0) -> void:
	if size < 0.001 or alpha < 0.001: return
	if not sprite_templates.has(id):
		var values: Array = SPRITES[id]
		var template := ShaderMaterial.new()
		template.shader = sprite_shader
		template.set_shader_parameter("source_mask", values[0])
		template.set_shader_parameter("tint", values[1])
		template.set_shader_parameter("frames", values[2])
		template.set_shader_parameter("source_alpha", values[3])
		sprite_templates[id] = template
	while sprite_materials.size() <= cursor:
		sprite_materials.append(null)
		sprite_keys.append("")
	if sprite_keys[cursor] != id:
		sprite_materials[cursor] = sprite_templates[id].duplicate()
		sprite_keys[cursor] = id
	var mat := sprite_materials[cursor]
	var frames: float = SPRITES[id][2]
	mat.set_shader_parameter("frame_index", minf(floor(clampf(phase, 0, 0.999) * frames), frames - 1.0))
	mat.set_shader_parameter("opacity", alpha)
	_piece(quad, mat, point, Vector3.ONE * size, facing * Basis(Vector3.FORWARD, rotation_value))

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	var facing := Basis(right, up, right.cross(up))
	if key == "ember":
		_draw_ember(from, to, right, facing)
		return true
	if key == "watergun":
		_draw_watergun(from, to, facing)
		return true
	return false

func _draw_ember(from: Vector3, to: Vector3, right: Vector3, facing: Basis) -> void:
	var travel := (elapsed - launch) / maxf(impact - launch, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.3, 0.01)
	if travel >= 0 and travel < 0.7:
		_source_sprite(from, 0.75, "ember_muzzle", travel / 0.7, 1.0 - travel / 0.7, facing)
	if travel >= 0 and after < 0.15:
		for i in 3:
			var phase := clampf(travel - i * 0.06, 0, 1)
			var point := from.lerp(to, phase) + Vector3.UP * sin(phase * PI) * 0.25
			point += right * (i - 1) * sin(phase * PI) * 0.11
			_source_sprite(point, 0.52, "ember_core", 0, 0.9, facing, elapsed * 3 + i)
			for tail in 5:
				var p := clampf(phase - tail * 0.032, 0, 1)
				var behind := from.lerp(to, p) + Vector3.UP * sin(p * PI) * 0.25
				_source_sprite(behind, 0.4, "ember_tail", float(tail) / 5.0, 0.7, facing, float(i + tail))
	if hit and after >= 0 and after < 1:
		_source_sprite(to, 1.15, "ember_hit", after, 1.0 - after * 0.5, facing)
		for i in 7:
			var angle := float(i) * TAU / 7.0
			var offset := Vector3(cos(angle), sin(angle), sin(angle * 2)) * after * 0.65
			_source_sprite(to + offset, 0.6, "ember_sparks", after, 0.8 * (1.0 - after), facing, angle)

func _draw_watergun(_from: Vector3, to: Vector3, facing: Basis) -> void:
	var travel := (elapsed - launch) / maxf(impact - launch, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.3, 0.01)
	for origin: Vector3 in emission_sources:
		if travel >= 0 and after < 0.6:
			var fade := 1.0 - clampf(after / 0.6, 0, 1)
			var tip := origin.lerp(to, clampf(travel, 0, 1))
			_water_beam(origin, tip, fade)
			_source_sprite(origin, 0.48, "water_muzzle", fmod(elapsed * 3, 1.0), fade * 0.6, facing)
			for i in 5:
				var phase := clampf(travel - i * 0.045, 0, 1)
				_source_sprite(origin.lerp(to, phase), 0.32, "water_drop", float(i) / 8.0, 0.75 * fade, facing, float(i))
	if hit and after >= 0 and after < 1:
		_source_sprite(to, 1.35, "water_splash", after, 0.9 * (1.0 - after * 0.3), facing)
		for i in 9:
			var angle := float(i) * TAU / 9.0
			var offset := Vector3(cos(angle), sin(angle), sin(angle * 2)) * after * 0.8
			offset.y -= after * after * 0.5
			_source_sprite(to + offset, 0.35, "water_drop", after, 0.7 * (1.0 - after), facing, angle)

func _water_beam(from: Vector3, to: Vector3, opacity: float) -> void:
	if beam_material == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float noise = texture(flow_mask, vec2(UV.x * 1.5, UV.y * 3.0 + seconds * 3.5)).r;
	ALBEDO = mix(vec3(0.06, 0.30, 0.85), vec3(0.70, 0.92, 1.0), smoothstep(0.3, 0.9, noise));
	ALPHA = (0.65 + noise * 0.25) * opacity;
}
"""
		beam_material = ShaderMaterial.new()
		beam_material.shader = shader
		beam_material.set_shader_parameter("flow_mask", NOISE)
	beam_material.set_shader_parameter("seconds", elapsed)
	beam_material.set_shader_parameter("opacity", opacity)
	_line(from, to, 0.09 * opacity, beam_material)
