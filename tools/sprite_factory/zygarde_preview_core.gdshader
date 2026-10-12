shader_type spatial;
// LOCAL PROTOTYPE. The Fresnel and distortion formulas are reconstructed.
render_mode cull_back, diffuse_burley, specular_schlick_ggx;
uniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D detail_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D probe_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint = vec4(1.0);
uniform vec4 detail_tint = vec4(1.0);
uniform vec4 uv_base = vec4(1.0,1.0,0.0,0.0);
uniform vec4 uv_detail = vec4(1.0,1.0,0.0,0.0);
uniform float normal_height = 1.0;
uniform float detail_normal_height = 1.0;
uniform float metallic = 0.25;
uniform float roughness = 0.5;
uniform float fresnel_min = 0.85;
uniform float fresnel_max = 0.6;
uniform float fresnel_bias = 0.45;
uniform float probe_intensity = 1.0;
uniform float distortion = 0.015;
uniform vec4 emission_colour = vec4(0.0);
uniform float emission_power = 0.0;
vec3 linear_colour(vec3 c) {
	return mix(c/12.92,pow((c+0.055)/1.055,vec3(2.4)),step(vec3(0.04045),c));
}
vec3 display_colour(vec3 c) {
	return mix(c*12.92,1.055*pow(max(c,vec3(0.0)),vec3(1.0/2.4))-0.055,step(vec3(0.0031308),c));
}
void fragment() {
	vec2 primary_uv = UV * uv_base.xy + uv_base.zw;
	vec2 secondary_uv = UV2 * uv_detail.xy + uv_detail.zw;
	vec2 n = (texture(normal_tex, secondary_uv).rg * 2.0 - 1.0) * normal_height;
	vec2 detail_n = (texture(detail_normal_tex, secondary_uv).rg * 2.0 - 1.0) * detail_normal_height;
	vec3 tangent_normal = normalize(vec3(n + detail_n, sqrt(max(0.001, 1.0 - dot(n,n)))));
	NORMAL_MAP = tangent_normal * 0.5 + 0.5;
	vec3 perturbed = normalize(TANGENT * tangent_normal.x + BINORMAL * tangent_normal.y + NORMAL * tangent_normal.z);
	float angle = clamp(1.0 - abs(dot(perturbed, VIEW)) + fresnel_bias, 0.0, 1.0);
	float fresnel = pow(angle, 5.0);
	float layer_weight = mix(fresnel_min, fresnel_max, fresnel);
	vec3 primary = texture(base_tex, primary_uv).rgb;
	vec3 secondary = texture(detail_tex, secondary_uv + n * distortion).rgb;
	// Source table tints are linear. Compatibility performs its lighting in
	// sRGB; keep the layer calculation linear and encode only its final result.
	if (OUTPUT_IS_SRGB) { primary = linear_colour(primary); secondary = linear_colour(secondary); }
	primary *= tint.rgb;
	secondary *= detail_tint.rgb;
	ALBEDO = mix(primary, secondary, clamp(layer_weight,0.0,1.0));
	if (OUTPUT_IS_SRGB) { ALBEDO = display_colour(ALBEDO); }
	EMISSION = emission_colour.rgb * emission_power;
	if (OUTPUT_IS_SRGB) { EMISSION = display_colour(EMISSION); }
	AO = texture(ao_tex, secondary_uv).r;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	// Only a constant white exported probe is admitted by the preview builder.
	// Godot supplies lighting; this scales specular response, not fake emission.
	SPECULAR = clamp(dot(texture(probe_tex, vec2(0.5)).rgb,vec3(0.333333)) * probe_intensity * 0.5,0.0,1.0);
}
