shader_type spatial;
// Same groundA detail, tint and UV scale as the approved forest material.
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 ground_uv;
void vertex() {
	ground_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz * 0.1;
}
void fragment() {
	vec3 tint = mix(vec3(0.3843, 0.6039, 0.3294), vec3(0.7098, 0.6078, 0.4392), COLOR.r);
	// Uniform source_color conversions are made explicit for the authored tints.
	tint = mix(tint / 12.92, pow((tint + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), tint));
	ALBEDO = texture(ground_albedo, ground_uv).rgb * tint;
	NORMAL_MAP = texture(ground_normal, ground_uv).rgb;
	NORMAL_MAP_DEPTH = 0.5;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
