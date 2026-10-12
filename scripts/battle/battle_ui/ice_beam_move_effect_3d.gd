extends "res://scripts/battle/battle_ui/source_move_effect_3d.gd"
## Inspected SV masks on a volumetric beam and authored ice shards.
const ICE_SPRITES := {
	"ice_muzzle": [preload("res://assets/battles/moves_3d/sv_icebeam/cpt_2_hit0010.png"), Vector3(0.55, 0.88, 1.0), 8.0, false],
	"ice_hit": [preload("res://assets/battles/moves_3d/sv_icebeam/cpt_2_hit0003.png"), Vector3(0.65, 0.93, 1.0), 4.0, false],
}
var ice_material: ShaderMaterial
var shard_material: StandardMaterial3D
var shard_mesh: ArrayMesh
var emission_end := 0.0

func start(move: String, timing: Dictionary, options: Dictionary, native_clock: Callable, positions: Callable, guard: Callable) -> void:
	emission_end = float(timing.get("emission_end_frame", float(timing.impact_frame) + float(timing.frames) * 0.168)) / 60.0
	super.start(move, timing, options, native_clock, positions, guard)

func _sprite_values(id: String) -> Array:
	return ICE_SPRITES[id] if ICE_SPRITES.has(id) else super._sprite_values(id)

func _draw_source_move(_from: Vector3, to: Vector3, right: Vector3, up: Vector3) -> bool:
	if ice_material == null: _build_ice()
	var facing := Basis(right, up, right.cross(up))
	var travel := (elapsed - launch) / maxf(impact - launch, 0.01)
	var after := (elapsed - impact) / maxf(duration * 0.24, 0.01)
	var fade := 1.0 - clampf((elapsed - impact) / maxf(emission_end - impact, 0.01), 0, 1)
	ice_material.set_shader_parameter("seconds", elapsed)
	ice_material.set_shader_parameter("opacity", fade)
	for origin: Vector3 in emission_sources:
		if travel < 0 or elapsed >= emission_end: continue
		var tip := origin.lerp(to, clampf(travel, 0, 1))
		_tapered_beam(origin, tip, 0.105 * emission_scale * fade, ice_material, origin.distance_to(to))
		_tapered_beam(origin, tip, 0.024 * emission_scale * fade, core, origin.distance_to(to))
		_source_sprite(origin, 0.18 * emission_scale, "ice_muzzle", fmod(elapsed * 4.0, 1.0), fade * 0.8, facing)
		var direction := (to - origin).normalized()
		var side := direction.cross(Vector3.UP).normalized()
		var vertical := side.cross(direction).normalized()
		for i in 7:
			var t := fmod(maxf(travel, 0) * 1.7 + float(i) / 7.0, 1.0) * clampf(travel, 0, 1)
			var angle := float(i) * 2.399 + elapsed * 4.0
			var spread := _beam_radius_fraction(origin.distance_to(to) * t, origin.distance_to(to))
			var point := origin.lerp(to, t) + (side * cos(angle) + vertical * sin(angle)) * 0.12 * emission_scale * spread
			_piece(shard_mesh, shard_material, point, Vector3(0.06, 0.18, 0.06) * emission_scale * fade * spread,
				Basis(Vector3(1, 1, 0).normalized(), angle))
	if hit and after >= 0 and after < 1:
		_source_sprite(to, 1.45 + after * 0.65, "ice_hit", after, 1.0 - after, facing)
		for i in 8:
			var angle := float(i) * TAU / 8.0
			var offset := Vector3(cos(angle), sin(angle), sin(angle * 2.0)) * after * 0.8
			offset.y -= after * after * 0.35
			_piece(shard_mesh, shard_material, to + offset, Vector3(0.09, 0.26, 0.09) * (1.0 - after),
				Basis(Vector3(1, 0, 1).normalized(), angle + after * 4.0))
	return true

func _build_ice() -> void:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D ice_mask : filter_linear, repeat_enable;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float ice = texture(ice_mask, vec2(UV.x * 2.0, UV.y * 8.0 + seconds * 4.0)).r;
	float flow = texture(flow_mask, vec2(UV.x, UV.y * 3.0 + seconds * 6.0)).r;
	ALBEDO = mix(vec3(0.12, 0.55, 0.96), vec3(0.88, 1.0, 1.0), clamp(ice + flow * 0.4, 0.0, 1.0));
	ALPHA = (0.55 + ice * 0.4) * opacity;
}
"""
	ice_material = ShaderMaterial.new()
	ice_material.shader = shader
	ice_material.set_shader_parameter("ice_mask", preload("res://assets/battles/moves_3d/sv_icebeam/cpt_3_ice0201.png"))
	ice_material.set_shader_parameter("flow_mask", preload("res://assets/battles/moves_3d/sv_icebeam/cpt_3_flow0016.png"))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a := Vector3(cos(i * PI * 0.5), 0, sin(i * PI * 0.5))
		var b := Vector3(cos((i + 1) * PI * 0.5), 0, sin((i + 1) * PI * 0.5))
		for vertex: Vector3 in [Vector3.UP, a, b, Vector3.DOWN, b, a]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	shard_mesh = surface.commit()
	shard_material = StandardMaterial3D.new()
	shard_material.albedo_color = Color(0.64, 0.91, 1.0)
	shard_material.emission_enabled = true
	shard_material.emission = Color(0.16, 0.32, 0.4)
	shard_material.roughness = 0.25
	shard_material.cull_mode = BaseMaterial3D.CULL_DISABLED
