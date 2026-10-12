shader_type spatial;
// LOCAL PROTOTYPE: screen-space thin refraction; not original-engine parity.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;
uniform sampler2D color_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D emission_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform float emission_power = 0.0;
uniform float refraction_strength = 0.01;
void fragment() {
	vec4 colour = texture(color_tex, UV);
	vec3 normal_map = texture(normal_tex, UV).rgb;
	NORMAL_MAP = vec3(normal_map.rg,1.0);
	vec2 bend = (normal_map.rg * 2.0 - 1.0) * refraction_strength;
	float opacity = clamp(colour.a,0.0,1.0);
	ALBEDO = colour.rgb * opacity;
	EMISSION = textureLod(screen_tex, clamp(SCREEN_UV + bend,vec2(0.001),vec2(0.999)),0.0).rgb * (1.0-opacity);
	EMISSION += texture(emission_tex, UV).rgb * emission_power;
	ROUGHNESS = 0.5;
	ALPHA = 1.0;
}
