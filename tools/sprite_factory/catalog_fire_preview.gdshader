// Authored diagnostic fire reconstruction, NOT an admitted runtime shader.
// Original mesh and source noise remain inputs. Centiskorch retains source
// opacity; oversized horse cards use an authored UV cutout. No displacement.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled;
uniform sampler2D coverage_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 uv_transform = vec4(1.0, 1.0, 0.0, 0.0);
uniform float coverage_gain = 1.0;
uniform float review_time = -1.0;
uniform float loop_seconds = 2.0;
uniform float tongue_base = 0.3;
uniform float tongue_span = 0.5;
uniform float layer_opacity = 1.0;
uniform bool retain_coverage = false;
uniform bool shape_flames = false;
uniform bool enabled = true;
void fragment() {
	vec2 uv = UV * uv_transform.xy + uv_transform.zw;
	float clock = review_time >= 0.0 ? review_time : TIME;
	float phase = mod(clock, loop_seconds) / loop_seconds;
	float coverage = clamp(texture(coverage_tex, uv).a * coverage_gain, 0.0, 1.0);
	// Integer texture travel returns to the same input at the loop boundary.
	float first = texture(noise_tex, uv * vec2(2.0, 3.0) + vec2(0.0, phase)).r;
	float second = texture(noise_tex, uv * vec2(3.0, 2.0) + vec2(phase, phase * 2.0)).r;
	float density = clamp(first * 0.65 + second * 0.35, 0.0, 1.0);
	float flame = 0.55 + 0.45 * smoothstep(0.1, 0.6, density);
	float opacity = sqrt(coverage) * flame;
	if (shape_flames) {
		// Authored cutout shortens the oversized source cards without moving
		// vertices or bones; repeated source UV tiles keep separate tongues.
		float height = 1.0 - clamp(uv.y, 0.0, 1.0);
		float sideways = fract(uv.x);
		float sides = smoothstep(0.0, 0.12, sideways) * smoothstep(0.0, 0.12, 1.0-sideways);
		float tongue = 1.0-smoothstep(tongue_base+tongue_span*density, tongue_base+0.1+tongue_span*density, height);
		opacity = sides * tongue * (0.8 + 0.2 * density) * layer_opacity;
		if (retain_coverage) { opacity *= sqrt(coverage); }
		coverage = 1.0-height;
	}
	if (!enabled || opacity < 0.025) { discard; }
	vec3 edge = vec3(1.0, 0.23, 0.015);
	vec3 core = vec3(1.0, 0.82, 0.08);
	ALBEDO = mix(edge, core, clamp(coverage * 0.7 + density * 0.3, 0.0, 1.0));
	ALPHA = opacity;
}
