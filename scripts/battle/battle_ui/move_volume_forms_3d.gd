extends RefCounted
## Continuous silhouettes. Every animated surface uses the move clock, never TIME.

static func energy_material(fire: bool) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float seconds = 0.0;
uniform bool fire = false;
void fragment() {
	float angle = UV.x * 6.283185;
	float flow = sin(angle * 3.0 + UV.y * 12.0 - seconds * 7.0
		+ sin(angle * 2.0 - UV.y * 9.0 + seconds * 3.0) * 1.4);
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 low = fire ? vec3(0.85, 0.055, 0.008) : vec3(1.0, 0.38, 0.045);
	vec3 high = fire ? vec3(1.0, 0.84, 0.18) : vec3(1.0, 0.97, 0.77);
	float streak = sin(angle * 7.0 + sin(UV.y * 11.0 - seconds * 16.0) * 0.7);
	float heat = fire ? smoothstep(-0.7, 0.65, flow) : clamp(pow(face, 0.7) + streak * 0.14, 0.0, 1.0);
	ALBEDO = mix(low, high, heat) * (0.65 + face * 0.35);
	EMISSION = mix(low, high, heat) * (fire ? 0.35 : 1.2);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("fire", fire)
	return material

static func tail_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float flow = 0.5 + 0.5 * sin(UV.x * 18.84956 - UV.y * 13.0 + seconds * 12.0);
	float edge = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.6);
	ALBEDO = mix(vec3(1.0, 0.17, 0.012), vec3(1.0, 0.82, 0.23), (1.0 - UV.y) * 0.65 + flow * 0.25);
	ALPHA = (1.0 - smoothstep(0.45, 1.0, UV.y)) * (0.45 + flow * 0.18) * edge * opacity;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func funnel_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float turn = UV.x * 6.283185 + UV.y * 10.0 - seconds * 6.0;
	float band = 0.5 + 0.5 * sin(turn * 3.0 + sin(turn + UV.y * 7.0) * 0.6);
	float strands = 0.5 + 0.5 * sin(turn * 9.0 + UV.y * 11.0);
	float ends = smoothstep(0.0, 0.12, UV.y) * (1.0 - smoothstep(0.78, 1.0, UV.y));
	ALBEDO = mix(vec3(0.32, 0.44, 0.5), vec3(0.77, 0.91, 0.95), band);
	ALPHA = ends * (0.10 + pow(band, 3.0) * 0.38 + strands * 0.04) * opacity;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

static func swept_mesh(funnel: bool) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in 16:
		for column in 48:
			for corner: Vector2 in [Vector2(0,0), Vector2(1,0), Vector2(1,1), Vector2(0,0), Vector2(1,1), Vector2(0,1)]:
				var uv := Vector2((column + corner.x) / 48.0, (row + corner.y) / 16.0)
				var angle := uv.x * TAU
				var radius := lerpf(0.28, 1.0, pow(uv.y, 0.7)) if funnel else pow(1.0 - uv.y, 0.85)
				radius *= 1.0 + sin(angle * 3.0 + uv.y * 8.0) * (0.055 if funnel else 0.13)
				tool.set_uv(uv)
				tool.add_vertex(Vector3(cos(angle) * radius, uv.y, sin(angle) * radius))
	tool.generate_normals()
	return tool.commit()

static func along(direction: Vector3) -> Basis:
	var y := direction.normalized()
	if y.length_squared() < 0.01: y = Vector3.UP
	var x := y.cross(Vector3.UP if absf(y.y) < 0.95 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))
