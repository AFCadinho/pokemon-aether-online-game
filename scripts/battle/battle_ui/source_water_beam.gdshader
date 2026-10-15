
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float noise = texture(flow_mask, vec2(UV.x * 1.5, UV.y * 3.0 + seconds * 3.5)).r;
	ALBEDO = mix(vec3(0.06, 0.30, 0.85), vec3(0.70, 0.92, 1.0), smoothstep(0.3, 0.9, noise));
	ALPHA = (0.65 + noise * 0.25) * opacity;
}
