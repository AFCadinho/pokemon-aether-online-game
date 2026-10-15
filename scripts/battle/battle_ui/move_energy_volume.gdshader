
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
