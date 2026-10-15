
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float seconds = 0.0;
uniform float opacity = 1.0;
void fragment() {
	float flow = texture(flow_mask, vec2(UV.x * 2.0 + seconds * 0.3, UV.y * 5.0 + seconds * 5.0)).r;
	ALBEDO = mix(vec3(1.0, 0.13, 0.005), vec3(1.0, 0.75, 0.12), flow);
	ALPHA = (0.25 + flow * 0.5) * opacity;
}
