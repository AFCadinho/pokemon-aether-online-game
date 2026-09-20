shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float normal_strength = 0.0;

void fragment() {
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	ALBEDO = vec3(0.8);
	SPECULAR = 0.0;
}

void light() {
	DIFFUSE_LIGHT += max(dot(NORMAL, LIGHT), 0.0) * ATTENUATION * LIGHT_COLOR / PI;
}
