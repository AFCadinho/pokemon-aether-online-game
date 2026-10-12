shader_type spatial;
// Review-only translation of source layers. Native-engine response is unverified.
render_mode cull_back;
uniform sampler2D base_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D metallic_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D roughness_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D ao_tex : filter_linear_mipmap, repeat_enable;
uniform bool has_metallic_tex = false;
uniform bool has_roughness_tex = false;
uniform float base_metallic = 0.0;
uniform float base_roughness = 0.5;
uniform float normal_height = 1.0;
uniform vec4 layer_scale = vec4(1.0);
uniform vec4 layer_metallic = vec4(0.0);
uniform vec4 layer_roughness = vec4(0.5);
uniform vec4 layer_power = vec4(0.0);
uniform vec4 colour1 = vec4(1.0);
uniform vec4 colour2 = vec4(1.0);
uniform vec4 colour3 = vec4(1.0);
uniform vec4 colour4 = vec4(1.0);
uniform vec4 emission1 = vec4(0.0);
uniform vec4 emission2 = vec4(0.0);
uniform vec4 emission3 = vec4(0.0);
uniform vec4 emission4 = vec4(0.0);
void fragment() {
	vec3 base = texture(base_tex, UV).rgb;
	vec4 mask = clamp(texture(mask_tex, UV) * 2.0 * layer_scale, vec4(0.0), vec4(1.0));
	vec4 colours[4] = {colour1, colour2, colour3, colour4};
	vec4 emissions[4] = {emission1, emission2, emission3, emission4};
	vec3 colour = base;
	vec3 glow = vec3(0.0);
	float metal = has_metallic_tex ? texture(metallic_tex, UV).r : base_metallic;
	float rough = has_roughness_tex ? texture(roughness_tex, UV).r : base_roughness;
	for (int i=0; i<4; i++) {
		colour = mix(colour, base * colours[i].rgb, mask[i]);
		glow = mix(glow, emissions[i].rgb * layer_power[i], mask[i]);
		metal = mix(metal, layer_metallic[i], mask[i]);
		rough = mix(rough, layer_roughness[i], mask[i]);
	}
	ALBEDO = colour;
	EMISSION = glow;
	METALLIC = metal;
	ROUGHNESS = rough;
	AO = texture(ao_tex, UV).r;
	vec4 normal_map = texture(normal_tex, UV);
	NORMAL_MAP = vec3(normal_map.rg,normal_map.a);
	NORMAL_MAP_DEPTH = normal_height;
}
