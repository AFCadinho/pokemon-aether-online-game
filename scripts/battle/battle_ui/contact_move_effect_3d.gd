extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Inspected SV contact textures; authored 3D choreography on the native move clock.
## Pokémon keep their reviewed native body/claw/bite action selection.
const CONTACT_KEYS := ["tackle", "scratch", "bite"]
const CONTACT_SPRITES := {
	"tackle_dash": [preload("res://assets/battles/moves_3d/sv_contact/cpt_2_shock0017.png"), Vector3(0.944, 0.636, 0.464), 8.0, false],
	"tackle_hit": [preload("res://assets/battles/moves_3d/sv_contact/cpt_2_shock0008.png"), Vector3(1, 1, 0.65), 4.0, false],
	"tackle_ring": [preload("res://assets/battles/moves_3d/sv_contact/cpt_0_circle0007.png"), Vector3(1, 0.65, 0.25), 1.0, false],
	"scratch_blur": [preload("res://assets/battles/moves_3d/sv_contact/cpt_0_blur1601.png"), Vector3(0.68, 0.88, 1), 1.0, true],
	"scratch_hit": [preload("res://assets/battles/moves_3d/sv_contact/cpt_2_shock0001.png"), Vector3(0.65, 0.86, 1), 2.0, false],
	"bite_arc": [preload("res://assets/battles/moves_3d/sv_contact/cpt_0_circle0001.png"), Vector3(1, 0.64, 0.22), 1.0, false],
	"bite_hit": [preload("res://assets/battles/moves_3d/sv_contact/cpt_0_shock0001.png"), Vector3(1, 0.58, 0.13), 1.0, false],
	"bite_flash": [preload("res://assets/battles/moves_3d/sv_contact/cpt_0_flash0602.png"), Vector3(1, 0.92, 0.75), 1.0, false],
}
var target_radius := 0.8
var claw_mesh: ArrayMesh
var claw_material: ShaderMaterial
var fang_mesh: ArrayMesh
var fang_material: StandardMaterial3D

func _sprite_values(id: String) -> Array:
	return CONTACT_SPRITES[id] if CONTACT_SPRITES.has(id) else super._sprite_values(id)

func _draw_source_move(from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if key not in CONTACT_KEYS: return super._draw_source_move(from, to, right, up)
	var points: Dictionary = anchors.call()
	target_radius = clampf(float(points.radius), 0.4, 1.2)
	var facing := Basis(right, up, right.cross(up))
	match key:
		"tackle": _draw_tackle(from, to, facing)
		"scratch": _draw_scratch(from, to, facing)
		"bite": _draw_bite(to, facing)
	return true

func _draw_tackle(from: Vector3, to: Vector3, facing: Basis) -> void:
	var travel := (elapsed - launch) / maxf(impact - launch, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.19, 0.01)
	if travel >= 0 and travel < 1:
		# A short rush accent travels with the approaching body, not ahead as a projectile.
		var delta := to - from
		var direction := Vector2(delta.dot(facing.x), delta.dot(facing.y))
		var rotation_value := -direction.angle() + PI * 0.5
		_source_sprite(from, target_radius * 1.3,
			"tackle_dash", travel * 0.7, sin(travel * PI) * 0.85, facing, rotation_value)
	if hit and after >= 0 and after < 1:
		_source_sprite(to, target_radius * (1.8 + after * 0.55), "tackle_hit", after, 1.0 - after, facing)
		_source_sprite(to, target_radius * (0.6 + after * 1.65), "tackle_ring", 0, (1.0 - after) * 0.65, facing)

func _draw_scratch(_from: Vector3, to: Vector3, facing: Basis) -> void:
	var start := impact - duration * 0.11
	var phase := (elapsed - start) / maxf(duration * 0.29, 0.01)
	if phase < 0 or phase >= 1: return
	# The swing remains visible on a dodge; contact sparks require an actual hit.
	if not hit and not miss: return
	if claw_mesh == null: _build_claw()
	var reveal := clampf(phase / 0.45, 0, 1)
	var fade := 1.0 - smoothstep(0.5, 1, phase)
	claw_material.set_shader_parameter("reveal", reveal)
	claw_material.set_shader_parameter("opacity", fade)
	var basis_value := facing * Basis(Vector3.FORWARD, -0.42)
	for claw in 3:
		var center := to + basis_value.x * (claw - 1) * target_radius * 0.28
		_piece(claw_mesh, claw_material, center, Vector3.ONE * target_radius, basis_value)
		_source_sprite(center, target_radius * 1.7, "scratch_blur", 0,
			fade * 0.45, basis_value, 0, Vector2(0.22, 1.0))
	var after := (elapsed - impact) / maxf(duration * 0.16, 0.01)
	if hit and after >= 0 and after < 1:
		_source_sprite(to, target_radius * (1.15 + after * 0.65), "scratch_hit", after,
			(1.0 - after) * 0.8, facing, -0.45)

func _draw_bite(to: Vector3, facing: Basis) -> void:
	var close_start := impact - duration * 0.22
	var close_phase := (elapsed - close_start) / maxf(impact - close_start, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.2, 0.01)
	if close_phase < 0 or after >= 1 or (not hit and not miss): return
	if fang_mesh == null: _build_fang()
	var opening := (1.0 - smoothstep(0, 1, close_phase)) * 0.62
	var fade := smoothstep(0, 0.15, close_phase) * (1.0 - smoothstep(0.2, 1, after))
	fang_material.albedo_color.a = fade * 0.92
	# Two curved rows of volumetric fangs; the visible gap closes exactly at impact.
	for jaw in [-1, 1]:
		for i in 5:
			var x := (i - 2) * 0.28
			var y: float = jaw * (opening + 0.20 + x * x * 0.22)
			var depth := -0.17 + x * x * 0.6
			var point := to + (facing.x * x + facing.y * y + facing.z * depth) * target_radius
			var size := target_radius * (1.15 if i in [0, 4] else 0.85)
			var tooth_basis := facing * Basis(Vector3.FORWARD, PI if jaw < 0 else 0.0)
			_piece(fang_mesh, fang_material, point, Vector3.ONE * size, tooth_basis)
		_source_sprite(to + facing.y * jaw * opening * target_radius * 0.35,
			target_radius * 1.6, "bite_arc", 0, fade * 0.35, facing, PI if jaw > 0 else 0.0)
	if hit and after >= 0 and after < 1:
		for jaw in [-1, 1]:
			_source_sprite(to, target_radius * (1.35 + after * 0.55), "bite_hit", 0,
				(1.0 - after) * 0.72, facing, PI if jaw < 0 else 0.0)
		_source_sprite(to, target_radius * (0.9 + after * 0.5), "bite_flash", 0, 1.0 - after, facing)

func _build_claw() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 16:
		var a := float(segment) / 16.0
		var b := float(segment + 1) / 16.0
		for item in [[a,-1.0], [b,-1.0], [b,1.0], [a,-1.0], [b,1.0], [a,1.0]]:
			var t: float = item[0]
			var width := sin(t * PI) * 0.07
			surface.set_uv(Vector2((float(item[1])+1.0)*0.5, t))
			surface.add_vertex(Vector3(sin(t * PI) * 0.16 + item[1] * width, 0.85 - t * 1.7, 0))
	claw_mesh = surface.commit()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float reveal = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float edge = 1.0 - abs(UV.x * 2.0 - 1.0);
	float flow = texture(flow_mask, UV * vec2(0.8, 2.5)).r;
	float visible = 1.0 - smoothstep(reveal - 0.12, reveal, UV.y);
	ALBEDO = mix(vec3(0.35, 0.66, 1.0), vec3(0.94, 0.98, 1.0), edge);
	ALPHA = smoothstep(0.0, 0.45, edge) * (0.65 + flow * 0.35) * visible * opacity;
}
"""
	claw_material = ShaderMaterial.new()
	claw_material.shader = shader
	claw_material.set_shader_parameter("flow_mask", preload("res://assets/battles/moves_3d/sv_contact/cpt_3_flow0017.png"))

func _build_fang() -> void:
	# Curved tapered teeth, authored here; not claimed as the unconverted G3PR mesh.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 6:
		for side in 8:
			for pair in [[segment, side], [segment+1, side], [segment+1, side+1],
					[segment, side], [segment+1, side+1], [segment, side+1]]:
				var t := float(pair[0]) / 6.0
				var angle := float(pair[1]) / 8.0 * TAU
				var radius := 0.10 * pow(1.0 - t, 0.7)
				surface.add_vertex(Vector3(cos(angle) * radius, 0.18 - t * 0.38,
					sin(angle) * radius * 0.85 + t * t * 0.09))
	surface.generate_normals()
	fang_mesh = surface.commit()
	fang_material = StandardMaterial3D.new()
	fang_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fang_material.albedo_color = Color(0.91, 0.96, 1.0, 0.92)
	fang_material.emission_enabled = true
	fang_material.emission = Color(0.45, 0.52, 0.7)
	fang_material.emission_energy_multiplier = 0.45
	fang_material.roughness = 0.3
	fang_material.cull_mode = BaseMaterial3D.CULL_DISABLED
