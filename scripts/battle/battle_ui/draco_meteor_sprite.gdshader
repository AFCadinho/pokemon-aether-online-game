shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never, fog_disabled;

uniform sampler2D source_mask : filter_linear, repeat_disable;
uniform vec3 tint = vec3(1.0);
uniform float frames = 1.0;
uniform float frame_index = 0.0;
uniform float opacity = 1.0;
uniform bool source_alpha = false;
uniform bool quarter_mask = false;
uniform float atlas_rows = 1.0;

vec4 sample_frame(vec2 uv, float index) {
	vec2 grid = vec2(frames / atlas_rows, atlas_rows);
	vec2 inset = 0.5 * grid / vec2(textureSize(source_mask, 0));
	vec2 local_uv = clamp(uv, inset, vec2(1.0) - inset);
	vec2 cell = vec2(mod(index, grid.x), floor(index / grid.x));
	return texture(source_mask, (local_uv + cell) / grid);
}

void fragment() {
	// The charge masks store only their lower-right quadrant. Mirror that
	// quadrant into a complete glow before sampling/blending atlas frames.
	vec2 uv = quarter_mask ? vec2(1.0) - abs(UV * 2.0 - vec2(1.0)) : UV;
	float first = floor(frame_index);
	float next = min(first + 1.0, frames - 1.0);
	vec4 sample_color = mix(sample_frame(uv, first), sample_frame(uv, next), fract(frame_index));
	ALBEDO = tint * (source_alpha ? sample_color.r : 1.0);
	ALPHA = (source_alpha ? sample_color.a : sample_color.r) * opacity;
}
