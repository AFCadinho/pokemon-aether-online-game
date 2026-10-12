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

static func orb_material(kind: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_back;
uniform float seconds = 0.0;
uniform int kind = 0;
void fragment() {
	float angle = UV.x * 6.283185;
	float face = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float flow = sin(angle * 3.0 + UV.y * 13.0 - seconds * 5.0
		+ sin(angle * 2.0 - UV.y * 8.0 + seconds * 2.0) * 1.8);
	vec3 color;
	float glow;
	if (kind == 0) {
		// Dense shadow with violet folds across the surface, not orbiting hoops.
		float folds = smoothstep(0.35, 0.95, flow);
		color = mix(vec3(0.045, 0.006, 0.08), vec3(0.48, 0.075, 0.8), folds);
		color += vec3(0.21, 0.025, 0.35) * pow(1.0 - face, 3.0);
		glow = 0.3;
	} else if (kind == 1) {
		// Compressed blue energy with gold currents embedded in its skin.
		float current = smoothstep(0.91, 0.99, sin(angle * 3.0 + UV.y * 18.0 - seconds * 9.0));
		color = mix(vec3(0.015, 0.16, 0.65), vec3(0.3, 0.88, 1.0), face * 0.7 + flow * 0.15);
		color = mix(color, vec3(1.0, 0.7, 0.16), current * 0.85);
		glow = 0.65;
	} else {
		// Broad pearly bands keep the moon sphere smooth and legible.
		float pearl = 0.5 + 0.5 * sin(angle + UV.y * 9.0 - seconds * 2.0 + flow * 0.4);
		color = mix(vec3(0.36, 0.43, 0.9), vec3(1.0, 0.68, 0.86), pearl);
		color = mix(color, vec3(0.91, 0.96, 1.0), pow(face, 4.0) * 0.7);
		glow = 0.35;
	}
	ALBEDO = color * (0.65 + face * 0.35);
	EMISSION = color * glow;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("kind", kind)
	return material

static func orb_wake_material(kind: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float seconds = 0.0;
uniform int kind = 0;
void fragment() {
	float flow = 0.5 + 0.5 * sin(UV.x * 18.84956 + UV.y * 9.0 - seconds * 7.0);
	float face = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.5);
	vec3 low = kind == 0 ? vec3(0.09, 0.015, 0.16) : (kind == 1 ? vec3(0.05, 0.3, 0.9) : vec3(0.45, 0.5, 1.0));
	vec3 high = kind == 0 ? vec3(0.5, 0.12, 0.8) : (kind == 1 ? vec3(0.5, 0.94, 1.0) : vec3(1.0, 0.8, 0.95));
	ALBEDO = mix(low, high, flow * 0.55);
	EMISSION = ALBEDO * (kind == 0 ? 0.1 : 0.4);
	ALPHA = (1.0 - smoothstep(0.0, 1.0, UV.y)) * face * (0.3 + flow * 0.3);
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("kind", kind)
	return material

static func orb_impact_material(kind: int) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform int kind = 0;
uniform float opacity = 1.0;
void fragment() {
	float face = abs(dot(normalize(NORMAL), normalize(VIEW)));
	vec3 color = kind == 0 ? vec3(0.57, 0.13, 0.9) : (kind == 1 ? vec3(1.0, 0.72, 0.22) : vec3(0.85, 0.7, 1.0));
	ALBEDO = mix(color, vec3(1.0), pow(face, 6.0) * 0.5);
	ALPHA = pow(face, 1.5) * opacity * 0.6;
}
"""
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("kind", kind)
	return material
