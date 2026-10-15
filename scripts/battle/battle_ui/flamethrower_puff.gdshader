
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D source_mask : filter_linear, repeat_disable;
uniform sampler2D flow_mask : filter_linear, repeat_enable;
uniform float frames = 8.0;
uniform float frame_index = 0.0;
uniform float opacity = 1.0;
uniform float seconds = 0.0;
void fragment() {
	vec2 uv = vec2((UV.x + floor(frame_index)) / frames, UV.y);
	float mask = texture(source_mask, uv).r;
	float flow = texture(flow_mask, UV * 1.7 + vec2(0.0, seconds * 2.0)).r;
	ALBEDO = mix(vec3(1.0, 0.12, 0.015), vec3(1.0, 0.87, 0.32), smoothstep(0.2, 0.8, flow));
	ALPHA = mask * smoothstep(0.1, 0.65, flow) * opacity;
}
