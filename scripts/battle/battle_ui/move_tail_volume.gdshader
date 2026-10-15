
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
