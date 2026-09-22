shader_type spatial;
render_mode cull_disabled;

uniform vec2 pond_center = vec2(-13.5, -26.0);
uniform vec2 pond_radii = vec2(10.0, 5.5);
varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_position.xz;
	float bank_distance = length((p - pond_center) / pond_radii);
	if (bank_distance > 1.08) {
		discard;
	}
	float shallow = smoothstep(0.25, 1.08, bank_distance);
	float wave = sin(p.x * 1.7 + p.y * 0.9 + sin(p.y * 0.47) + TIME * 1.1);
	float cross_wave = sin(p.y * 2.3 - p.x * 0.6 + sin(p.x * 0.39) - TIME * 0.8);
	vec3 color = mix(vec3(0.055, 0.30, 0.46), vec3(0.20, 0.62, 0.65), shallow);
	color += 0.018 * wave * cross_wave;
	float edge = 1.05 + 0.006 * sin(TIME + p.x * 0.5);
	float foam = (1.0 - smoothstep(0.004, 0.025, abs(bank_distance - edge))) * 0.22;
	ALBEDO = mix(color, vec3(0.77, 0.88, 0.84), foam);
	NORMAL_MAP = vec3(0.5 + 0.035 * wave, 0.5 + 0.025 * cross_wave, 1.0);
	ROUGHNESS = 0.32;
	SPECULAR = 0.3;
}
