shader_type spatial;
render_mode cull_disabled;
uniform bool battle_shallows = false;
uniform vec2 battle_origin = vec2(30.0, 25.0);
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float coast = p.x + p.y - 24.0 + 2.0 * sin(p.y * 0.12);
	// Keep the open sea independent of the separate garden pond and terrain edge.
	if (coast < 0.0) { discard; }
	float wave = sin(p.x * 1.7 + p.y * 0.9 + sin(p.y * 0.47) + TIME * 1.1);
	float cross_wave = sin(p.y * 2.3 - p.x * 0.6 + sin(p.x * 0.39) - TIME * 0.8);
	float shallow = 1.0 - smoothstep(2.0, 30.0, coast);
	vec3 color = mix(vec3(0.055, 0.30, 0.46), vec3(0.20, 0.62, 0.65), shallow);
	color += 0.018 * wave * cross_wave;
	float foam = (1.0 - smoothstep(0.07, 0.45, abs(coast - 0.9 - 0.18 * sin(TIME + p.y)))) * 0.4;
	ALBEDO = mix(color, vec3(0.77, 0.88, 0.84), foam);
	NORMAL_MAP = vec3(0.5 + 0.035 * wave, 0.5 + 0.025 * cross_wave, 1.0);
	ALPHA = battle_shallows ? mix(0.65, 1.0, smoothstep(9.0, 17.0, distance(p, battle_origin))) : 1.0;
	ROUGHNESS = 0.32;
	SPECULAR = 0.3;
}
