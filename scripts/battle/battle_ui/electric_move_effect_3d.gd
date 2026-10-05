extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Thunder Shock: SV masks with authored, deterministic 3D discharge paths.
const ELECTRIC_SPRITES := {
	"electric_charge": [preload("res://assets/battles/moves_3d/sv_electric/cpt_2_thunder0702.png"), Vector3(1, 0.82, 0.20), 8.0, false],
	"electric_hit": [preload("res://assets/battles/moves_3d/sv_electric/cpt_2_thunder0702.png"), Vector3(1, 0.9, 0.4), 8.0, false],
	"electric_flash": [preload("res://assets/battles/moves_3d/sv_electric/cpt_0_circle0005.png"), Vector3(1, 0.92, 0.58), 1.0, false],
}
var bolt_material: ShaderMaterial

func _sprite_values(id: String) -> Array:
	return ELECTRIC_SPRITES[id] if ELECTRIC_SPRITES.has(id) else super._sprite_values(id)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if key != "thundershock": return super._draw_source_move(from, to, right, up)
	var facing := Basis(right, up, right.cross(up))
	var travel := (elapsed - launch) / maxf(impact - launch, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.23, 0.01)
	var size := clampf(float(anchors.call().radius), 0.4, 1.15)
	if travel >= 0 and after < 0.4:
		var fade := 1.0 - clampf(after / 0.4, 0, 1)
		# Small arcs gather at the body as the native special-attack pose discharges.
		for i in 2:
			_source_sprite(from, 0.9, "electric_charge", 0.25 + fmod(maxf(travel,0) * 0.8 + i * 0.25, 0.75), fade, facing, i * PI * 0.5)
		var tip := from.lerp(to, clampf(travel, 0, 1))
		_draw_bolts(from, tip, fade)
	if hit and after >= 0 and after < 1:
		# A short spatial corona around the confirmed impact, never on dodge/block.
		_source_sprite(to, size * 1.3, "electric_flash", 0, (1.0 - after) * 0.85, facing)
		for i in 3:
			var angle := float(i) * TAU / 3.0
			var offset := Vector3(cos(angle), sin(angle), sin(angle * 2)) * size * 0.25
			# Atlas frame 1 is empty; start at the first fully formed arcs (frame 2).
			_source_sprite(to + offset, size * 1.85, "electric_hit", 0.25 + after * 0.75, 1.0 - after * 0.8,
				facing, angle)
	return true

func _draw_bolts(from: Vector3, to: Vector3, fade: float) -> void:
	var delta := to - from
	if delta.length_squared() < 0.0001: return
	if bolt_material == null:
		var shader := Shader.new()
		shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D pulse_mask : filter_linear, repeat_enable;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float pulse = texture(pulse_mask, vec2(UV.x, UV.y * 2.0 - seconds * 4.0)).r;
	ALBEDO = vec3(1.0, 0.68 + pulse * 0.3, 0.08 + pulse * 0.5);
	ALPHA = (0.45 + pulse * 0.55) * opacity;
}
"""
		bolt_material = ShaderMaterial.new()
		bolt_material.shader = shader
		bolt_material.set_shader_parameter("pulse_mask", preload("res://assets/battles/moves_3d/sv_electric/cpt_3_mask0602.png"))
	bolt_material.set_shader_parameter("seconds", elapsed)
	bolt_material.set_shader_parameter("opacity", fade)
	var direction := delta.normalized()
	var side := direction.cross(Vector3.UP if absf(direction.y) < 0.95 else Vector3.RIGHT).normalized()
	var vertical := side.cross(direction).normalized()
	var pulse := floorf(elapsed * 24.0)
	for branch in 2:
		var last := from
		for step in range(1,11):
			var t := float(step) / 10.0
			var bend := sin(t * PI) * minf(delta.length() * 0.08, 0.23)
			var seed := step * 127.1 + branch * 311.7 + pulse * 74.7
			var point := from.lerp(to,t) + side * _jitter(seed) * bend
			point += vertical * _jitter(seed + 19.19) * bend
			_line(last, point, 0.03 * fade, bolt_material)
			_line(last, point, 0.009 * fade, core)
			last = point

func _jitter(seed: float) -> float:
	# Deterministic per native-time tick; pause and camera motion never reroll paths.
	return fposmod(sin(seed) * 43758.5453, 1.0) * 2.0 - 1.0
