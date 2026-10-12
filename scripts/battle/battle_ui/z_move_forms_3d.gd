extends RefCounted
## Smooth world geometry and analytical materials; no enlarged sprite masks.
const Volume = preload("res://scripts/battle/battle_ui/move_volume_forms_3d.gd")

static func material(tint: Color, kind := 0, two_sided := false) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode cull_back, depth_prepass_alpha;
uniform vec4 tint : source_color;
uniform int kind = 0;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
varying vec3 local_point;
void vertex() { local_point = VERTEX; }
void fragment() {
	float face = max(dot(normalize(NORMAL), normalize(VIEW)), 0.0);
	float rim = pow(1.0 - face, 2.5);
	float flow = 0.5 + 0.5 * sin(UV.x * 18.84956 + UV.y * 12.0 - seconds * 4.0
		+ sin(UV.y * 7.0 + seconds * 1.7));
	vec3 color = mix(tint.rgb * 0.24, tint.rgb, 0.3 + flow * 0.55);
	float glow = 0.6;
	ROUGHNESS = 0.45;
	METALLIC = 0.0;
	SPECULAR = 0.25;
	if (kind == 1) {
		// Deep water with continuous pale currents, not isolated splashes.
		color = mix(tint.rgb * 0.15, tint.rgb, flow * 0.7 + 0.25);
		color = mix(color, vec3(0.75, 0.95, 1.0), pow(flow, 6.0) * 0.6);
		ROUGHNESS = 0.14;
		glow = 0.18;
	} else if (kind == 2) {
		// Static strata are anchored to the rock, with no scrolling fire mask.
		float grain = 0.5 + 0.5 * sin(local_point.y * 17.0 + sin(local_point.x * 9.0) + local_point.z * 8.0);
		color = tint.rgb * (0.25 + grain * 0.3);
		ROUGHNESS = 0.9;
		METALLIC = 0.0;
		glow = 0.02;
	} else if (kind == 3) {
		color = mix(tint.rgb * 0.4, vec3(0.85, 0.95, 1.0), face * 0.7);
		ROUGHNESS = 0.18;
		METALLIC = 0.85;
		glow = 0.12;
	} else if (kind == 4) {
		color = mix(tint.rgb * 0.3, vec3(0.88, 0.98, 1.0), rim * 0.6 + flow * 0.3);
		ROUGHNESS = 0.12;
		glow = 0.25;
	} else if (kind == 5) {
		// Broad hot currents keep the fireball readable without a sprite shell.
		float heat = smoothstep(0.18, 0.85, flow);
		color = mix(vec3(0.7, 0.025, 0.005), vec3(1.0, 0.8, 0.16), heat);
		glow = 1.4;
		ROUGHNESS = 0.8;
		SPECULAR = 0.0;
	}
	ALBEDO = color;
	EMISSION = color * glow + tint.rgb * rim * 0.4;
	ALPHA = opacity;
}
"""
	var result := ShaderMaterial.new()
	if two_sided: shader.code = shader.code.replace("cull_back", "cull_disabled")
	result.shader = shader
	result.set_shader_parameter("tint", tint)
	result.set_shader_parameter("kind", kind)
	return result

static func wake_material(tint: Color) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform vec4 tint : source_color;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float bands = 0.5 + 0.5 * sin(UV.x * 18.84956 + UV.y * 10.0 - seconds * 5.0);
	float face = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 0.6);
	ALBEDO = mix(tint.rgb * 0.45, tint.rgb, bands);
	ALPHA = opacity * (1.0 - smoothstep(0.0, 1.0, UV.y)) * face * (0.22 + bands * 0.25);
}
"""
	result.shader = shader
	result.set_shader_parameter("tint", tint)
	return result

static func tube(points: Array[Vector3], radii: Array[float]) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in points.size() - 1:
		for column in 24:
			for corner: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(1,1),Vector2i(0,0),Vector2i(1,1),Vector2i(0,1)]:
				var index := row + corner.y
				var direction := points[mini(index + 1, points.size() - 1)] - points[maxi(0, index - 1)]
				var basis := Volume.along(direction)
				var angle := (column + corner.x) * TAU / 24.0
				var normal := basis.x * cos(angle) + basis.z * sin(angle)
				tool.set_normal(normal)
				tool.set_uv(Vector2((column + corner.x) / 24.0, float(index) / (points.size() - 1)))
				tool.add_vertex(points[index] + normal * radii[index])
	return tool.commit()
