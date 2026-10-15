
shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
uniform sampler2D source_mask : filter_linear, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform float frames = 1.0;
uniform float frame_index = 0.0;
uniform float opacity = 1.0;
uniform bool source_alpha = false;
uniform bool moon_disc = false;
void fragment() {
	// Blend adjacent source frames and keep filtering inside the atlas cell.
	vec2 texel = 0.5 / vec2(textureSize(source_mask, 0));
	vec2 local_uv = clamp(UV, texel * vec2(frames, 1.0), vec2(1.0) - texel * vec2(frames, 1.0));
	float first = floor(frame_index);
	float next = min(first + 1.0, frames - 1.0);
	vec4 a = texture(source_mask, vec2((local_uv.x + first) / frames, local_uv.y));
	vec4 b = texture(source_mask, vec2((local_uv.x + next) / frames, local_uv.y));
	vec4 sample_color = mix(a, b, fract(frame_index));
	ALBEDO = tint * (source_alpha ? sample_color.r : 1.0);
	ALPHA = (source_alpha ? sample_color.a : sample_color.r) * opacity;
	if (moon_disc) { ALPHA *= 1.0 - smoothstep(0.43, 0.46, length(UV - vec2(0.5))); }
}
