shader_type spatial;
render_mode unshaded, blend_mix, depth_prepass_alpha, cull_back;
uniform sampler2D color_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D displacement_tex : filter_linear_mipmap, repeat_enable;
uniform vec4 mask_start = vec4(1.0,1.0,0.0,0.0);
uniform vec4 mask_end = vec4(1.0,1.0,0.0,0.0);
uniform vec4 displacement_start = vec4(1.0,1.0,0.0,0.0);
uniform vec4 displacement_end = vec4(1.0,1.0,0.0,0.0);
uniform float loop_seconds = 1.0;
uniform float height = 0.0;
uniform float intensity = 1.0;
uniform float alpha_cutoff = 0.0;
uniform bool use_uv2 = false;
// Deterministic offline captures; live models use the normal renderer clock.
uniform float review_time = -1.0;
varying vec2 effect_uv;
void vertex() {
	float phase = mod(review_time >= 0.0 ? review_time : TIME, loop_seconds) / loop_seconds;
	vec4 mask_transform = mix(mask_start, mask_end, phase);
	vec4 displacement_transform = mix(displacement_start, displacement_end, phase);
	effect_uv = UV * mask_transform.xy + mask_transform.zw;
	vec2 displacement_uv = (use_uv2 ? UV2 : UV) * displacement_transform.xy + displacement_transform.zw;
	VERTEX += NORMAL * (textureLod(displacement_tex, displacement_uv, 0.0).r - 0.5) * height;
}
void fragment() {
	float opacity = 1.0 - texture(mask_tex, effect_uv).a;
	if (opacity <= alpha_cutoff) { discard; }
	ALBEDO = texture(color_tex, effect_uv).rgb * intensity;
	ALPHA = opacity;
}
