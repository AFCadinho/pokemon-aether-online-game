shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D endpoint_0 : source_color, filter_linear_mipmap;
uniform sampler2D endpoint_1 : source_color, filter_linear_mipmap;
uniform sampler2D light_map : filter_nearest, repeat_disable;
uniform vec4 base_color : source_color = vec4(1.0);
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap;
uniform float normal_strength = 0.0;
uniform sampler2D roughness_tex : filter_linear_mipmap;
uniform bool has_roughness = false;
uniform vec4 roughness_selector;
uniform float roughness_value = 1.0;
uniform float specular_value = 0.5;

void fragment() {
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength;
	// Source EASE ramp is applied AFTER summing linear HDR irradiance.
	// Keep Godot's standard BRDF for the final material/highlight response.
	float energy = dot(texture(light_map, SCREEN_UV).rgb, vec3(0.2126, 0.7152, 0.0722));
	float amount = 1.0 - smoothstep(0.5, 1.0, energy);
	ALBEDO = mix(texture(endpoint_0, UV).rgb, texture(endpoint_1, UV).rgb, amount) * base_color.rgb;
	ROUGHNESS = roughness_value;
	if (has_roughness) {
		ROUGHNESS *= dot(texture(roughness_tex, UV), roughness_selector);
	}
	SPECULAR = specular_value;
}
